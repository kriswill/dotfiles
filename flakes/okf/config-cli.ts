// Build-side config loader — the single entry point every okf command uses.
// Discovers the workspace (nearest okf.toml up from cwd, else the git
// toplevel), parses the TOML with Bun.TOML, and normalizes STRICTLY: a
// malformed or misspelled config fails the command rather than silently
// running with wrong settings. Viewer sections are delegated to
// viz-app/config.ts's normalizeVizConfig; CLI-only sections/keys ([profile],
// [vcs] provider+ignore; [scaffold]/[index] as they land) are consumed here
// and never reach the viewer's #data embed. Browser code never imports this
// file.

import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { createProvider, gitRoot, type VcsProvider } from "./vcs";
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

export interface OkfCliVcs {
  /** Provider selection; "auto" = git when the workspace root is a git
   *  toplevel, else the filesystem provider. */
  provider: "auto" | "git" | "none";
  /** Extra ignore globs for the filesystem ("none") provider; the git
   *  provider tracks files itself and ignores this. */
  ignore: string[];
}

const cliVcsDefaults = (): OkfCliVcs => ({ provider: "auto", ignore: [] });

export interface OkfConfig {
  viz: VizConfig;
  profile: OkfProfile;
  vcs: OkfCliVcs;
}

const isObj = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v);

/**
 * Consume + normalize the CLI-only sections/keys out of the raw parsed TOML,
 * returning them plus the remainder for normalizeVizConfig — which
 * strict-rejects unknown keys, so CLI sections must never reach it (nor the
 * viewer's #data embed). [profile] is consumed whole; [vcs] is MIXED — the
 * provider/ignore keys are taken here, url/commit-url-template stay for the
 * viewer normalizer. Always strict: throws OkfConfigError listing every
 * offending key path. Accepts kebab (TOML) and camel spellings like the viz
 * normalizer.
 */
export function splitCliSections(raw: unknown): { profile: OkfProfile; vcs: OkfCliVcs; rest: unknown } {
  const profile = profileDefaults();
  const vcs = cliVcsDefaults();
  // Non-table top levels fall through untouched — normalizeVizConfig owns
  // that error so the message stays consistent.
  if (!isObj(raw)) return { profile, vcs, rest: raw };
  const top = { ...raw };
  const errors: string[] = [];

  const fieldIn =
    (s: Record<string, unknown>, sectionName: string) =>
    (camel: string, set: (v: unknown, path: string) => void) => {
      const kebab = camel.replace(/[A-Z]/g, (c) => "-" + c.toLowerCase());
      for (const key of camel === kebab ? [camel] : [camel, kebab]) {
        if (key in s) {
          if (s[key] !== null) set(s[key], `${sectionName}.${key}`);
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

  const prof = top["profile"];
  delete top["profile"];
  if (prof !== undefined && prof !== null) {
    if (!isObj(prof)) errors.push("profile: expected a table");
    else {
      const s = { ...prof };
      const field = fieldIn(s, "profile");
      field("requiredFields", asStrArr((a) => (profile.requiredFields = a)));
      field("recommendedFields", asStrArr((a) => (profile.recommendedFields = a)));
      field("reservedFiles", asStrArr((a) => (profile.reservedFiles = a)));
      field("rootedLinks", asEnum(["error", "allow"] as const, (e) => (profile.rootedLinks = e)));
      field("repoLinks", asEnum(["check", "ignore", "forbid"] as const, (e) => (profile.repoLinks = e)));
      for (const k of Object.keys(s)) errors.push(`profile.${k}: unknown key`);
    }
  }

  const vt = top["vcs"];
  if (isObj(vt)) {
    const s = { ...vt };
    const field = fieldIn(s, "vcs");
    field("provider", asEnum(["auto", "git", "none"] as const, (e) => (vcs.provider = e)));
    field("ignore", asStrArr((a) => (vcs.ignore = a)));
    // No unknown-key sweep here: the leftover viewer keys (url,
    // commit-url-template) are the viz normalizer's to validate.
    top["vcs"] = s;
  }

  if (!profile.requiredFields.includes("type")) profile.requiredFields = ["type", ...profile.requiredFields];
  if (errors.length) throw new OkfConfigError("invalid okf.toml:\n  " + errors.join("\n  "));
  return { profile, vcs, rest: top };
}

/** Walk up from `start` to the fs root looking for a config file; returns
 *  its directory + name, or null. Exported for tests. */
export function findConfigUp(
  start: string,
  names: string[] = [CONFIG_FILE, LEGACY_CONFIG_FILE],
): { dir: string; file: string } | null {
  let dir = resolve(start);
  for (;;) {
    for (const n of names) if (existsSync(join(dir, n))) return { dir, file: n };
    const parent = dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
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

/** Load (once per process) the workspace context: root, config, bundle path,
 *  VCS provider. Exits 1 on a malformed config — no command may run against
 *  a config it can't trust. Absent config file -> generic defaults.
 *
 *  Root discovery: the nearest okf.toml at or above cwd wins (this is also
 *  what makes no-VCS workspaces and monorepo sub-bundles work); without one,
 *  the git toplevel with full defaults — okf's original zero-config
 *  behavior. */
export function loadContext(): OkfContext {
  if (ctxCache) return ctxCache;
  const found = findConfigUp(process.cwd());
  const root = found?.dir ?? gitRoot();
  if (!root) {
    console.error(
      `okf: no ${CONFIG_FILE} found in or above the current directory, and not inside a git repository — cd into your project, or create an ${CONFIG_FILE} at its root`,
    );
    process.exit(1);
  }
  if (found?.file === LEGACY_CONFIG_FILE)
    console.warn(`okf: warning: ${LEGACY_CONFIG_FILE} is deprecated — rename it to ${CONFIG_FILE}`);
  let raw: unknown = {};
  if (found) {
    try {
      raw = Bun.TOML.parse(readFileSync(join(found.dir, found.file), "utf8"));
    } catch (e) {
      console.error(`okf: cannot parse ${found.file} — ${e instanceof Error ? e.message : e}`);
      process.exit(1);
    }
  }
  let viz: VizConfig;
  let profile: OkfProfile;
  let cliVcs: OkfCliVcs;
  try {
    const split = splitCliSections(raw);
    profile = split.profile;
    cliVcs = split.vcs;
    viz = normalizeVizConfig(split.rest, { strict: true, warn: (m) => console.warn(`okf: warning: ${m}`) });
  } catch (e) {
    if (e instanceof VizConfigError || e instanceof OkfConfigError) {
      console.error(`okf: ${e.message}`);
      process.exit(1);
    }
    throw e;
  }
  let vcs: VcsProvider;
  try {
    // The generated viz output must never count as workspace content for the
    // filesystem provider.
    vcs = createProvider(cliVcs.provider, root, [...cliVcs.ignore, join(viz.bundle.dir, viz.bundle.out)]);
  } catch (e) {
    console.error(`okf: ${e instanceof Error ? e.message : e}`);
    process.exit(1);
  }
  ctxCache = { root, bundle: join(root, viz.bundle.dir), cfg: { viz, profile, vcs: cliVcs }, vcs };
  return ctxCache;
}
