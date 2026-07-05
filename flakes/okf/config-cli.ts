// Build-side config loader — the single entry point every okf command uses.
// Reads the workspace's okf.toml (optional; absent -> generic defaults),
// parses it with Bun.TOML, and normalizes STRICTLY: a malformed or misspelled
// config fails the command rather than silently running with wrong settings.
// Viewer sections are delegated to viz-app/config.ts's normalizeVizConfig;
// CLI-only sections (profile, vcs, scaffold, index) are consumed here as they
// land. Browser code never imports this file.

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { discoverVcs, type VcsProvider } from "./vcs";
import { normalizeVizConfig, VizConfigError, type VizConfig } from "./viz-app/config";

export const CONFIG_FILE = "okf.toml";
/** Pre-rename spelling, still honored with a warning; dropped after the
 *  generalization arc completes. */
const LEGACY_CONFIG_FILE = "okf-viz.toml";

export class OkfConfigError extends Error {}

export interface OkfProfile {
  /** Frontmatter fields that must be present and non-empty (errors).
   *  `type` is always enforced — the OKF spec requires it — and is prepended
   *  if a config omits it. */
  requiredFields: string[];
  /** Fields whose absence is a warning (`--strict` promotes to errors). */
  recommendedFields: string[];
  /** Basenames that carry no concept frontmatter and are skipped as concepts
   *  (index listings, viz nodes). */
  reservedFiles: string[];
  /** Policy for /-rooted link targets: reject, or skip checking. */
  rootedLinks: "error" | "allow";
  /** Policy for links escaping the bundle into the repo: verify they
   *  resolve, don't check, or reject outright (self-contained bundles). */
  repoLinks: "check" | "ignore" | "forbid";
}

const profileDefaults = (): OkfProfile => ({
  requiredFields: ["type"],
  recommendedFields: ["title", "description", "timestamp"],
  reservedFiles: ["index.md", "log.md"],
  rootedLinks: "error",
  repoLinks: "check",
});

export interface OkfConfig {
  viz: VizConfig;
  profile: OkfProfile;
}

const isObj = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v);

/**
 * Consume + normalize the CLI-only sections ([profile]; [vcs]/[scaffold]/
 * [index] as they land) out of the raw parsed TOML, returning them plus the
 * remainder for normalizeVizConfig — which strict-rejects unknown keys, so
 * CLI sections must never reach it (nor the viewer's #data embed). Always
 * strict: throws OkfConfigError listing every offending key path. Accepts
 * kebab (TOML) and camel spellings like the viz normalizer.
 */
export function splitCliSections(raw: unknown): { profile: OkfProfile; rest: unknown } {
  const profile = profileDefaults();
  // Non-table top levels fall through untouched — normalizeVizConfig owns
  // that error so the message stays consistent.
  if (!isObj(raw)) return { profile, rest: raw };
  const top = { ...raw };
  const errors: string[] = [];

  const section = top["profile"];
  delete top["profile"];
  if (section !== undefined && section !== null) {
    if (!isObj(section)) errors.push("profile: expected a table");
    else {
      const s = { ...section };
      const field = (camel: string, set: (v: unknown, path: string) => void) => {
        const kebab = camel.replace(/[A-Z]/g, (c) => "-" + c.toLowerCase());
        for (const key of camel === kebab ? [camel] : [camel, kebab]) {
          if (key in s) {
            if (s[key] !== null) set(s[key], `profile.${key}`);
            delete s[key];
          }
        }
      };
      const asStrArr = (assign: (a: string[]) => void) => (v: unknown, path: string) => {
        if (Array.isArray(v) && v.every((x) => typeof x === "string" && x !== "")) assign(v as string[]);
        else errors.push(`${path}: expected an array of non-empty strings`);
      };
      const asEnum =
        <T extends string>(allowed: readonly T[], assign: (e: T) => void) =>
        (v: unknown, path: string) => {
          if (typeof v === "string" && (allowed as readonly string[]).includes(v)) assign(v as T);
          else errors.push(`${path}: expected one of: ${allowed.join(", ")}`);
        };
      field("requiredFields", asStrArr((a) => (profile.requiredFields = a)));
      field("recommendedFields", asStrArr((a) => (profile.recommendedFields = a)));
      field("reservedFiles", asStrArr((a) => (profile.reservedFiles = a)));
      field("rootedLinks", asEnum(["error", "allow"] as const, (e) => (profile.rootedLinks = e)));
      field("repoLinks", asEnum(["check", "ignore", "forbid"] as const, (e) => (profile.repoLinks = e)));
      for (const k of Object.keys(s)) errors.push(`profile.${k}: unknown key`);
    }
  }
  if (!profile.requiredFields.includes("type")) profile.requiredFields = ["type", ...profile.requiredFields];
  if (errors.length) throw new OkfConfigError("invalid okf.toml:\n  " + errors.join("\n  "));
  return { profile, rest: top };
}

export interface OkfContext {
  /** Absolute workspace root (the repo okf operates on). */
  root: string;
  /** Absolute bundle root: <root>/<viz.bundle.dir>. */
  bundle: string;
  cfg: OkfConfig;
  /** Version-control provider for this workspace (tracked files, dates,
   *  revision citations, remote URL). */
  vcs: VcsProvider;
}

let ctxCache: OkfContext | null = null;

/** Load (once per process) the workspace context: root, config, bundle path.
 *  Exits 1 on a malformed config — no command may run against a config it
 *  can't trust. Absent config file -> generic defaults. */
export function loadContext(): OkfContext {
  if (ctxCache) return ctxCache;
  const vcs = discoverVcs();
  const root = vcs.root;
  let cfgFile = CONFIG_FILE;
  if (!existsSync(join(root, cfgFile)) && existsSync(join(root, LEGACY_CONFIG_FILE))) {
    console.warn(`okf: warning: ${LEGACY_CONFIG_FILE} is deprecated — rename it to ${CONFIG_FILE}`);
    cfgFile = LEGACY_CONFIG_FILE;
  }
  const cfgPath = join(root, cfgFile);
  let raw: unknown = {};
  if (existsSync(cfgPath)) {
    try {
      raw = Bun.TOML.parse(readFileSync(cfgPath, "utf8"));
    } catch (e) {
      console.error(`okf: cannot parse ${cfgFile} — ${e instanceof Error ? e.message : e}`);
      process.exit(1);
    }
  }
  let viz: VizConfig;
  let profile: OkfProfile;
  try {
    const split = splitCliSections(raw);
    profile = split.profile;
    viz = normalizeVizConfig(split.rest, { strict: true, warn: (m) => console.warn(`okf: warning: ${m}`) });
  } catch (e) {
    if (e instanceof VizConfigError || e instanceof OkfConfigError) {
      console.error(`okf: ${e.message}`);
      process.exit(1);
    }
    throw e;
  }
  ctxCache = { root, bundle: join(root, viz.bundle.dir), cfg: { viz, profile }, vcs };
  return ctxCache;
}
