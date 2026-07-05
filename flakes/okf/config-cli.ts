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

/** One declarative [[scaffold.collect]] entry: glob-matched workspace files
 *  stubbed into concept docs via templates. */
export interface CollectEntry {
  /** Matched against the provider's tracked files (root-relative). */
  glob: string;
  /** Frontmatter `type` of the emitted docs. */
  type: string;
  /** Bundle-relative output path template (e.g. "services/{name}.md"). */
  output: string;
  /** Leading-comment line prefix ("#", "--", "//") for description
   *  extraction from the matched file (null: no extraction). */
  comment: string | null;
  /** Description fallback template when no leading comment is found. */
  description: string | null;
  /** Title template (default: "{Title}"). */
  title: string | null;
  tags: string[];
  /** Body template (default: description sentence + a Source section). */
  body: string | null;
  /** Extra frontmatter fields, values templated. */
  frontmatter: Record<string, string>;
}

/** Placeholders available in collect templates (validated at load). */
export const COLLECT_PLACEHOLDERS = new Set([
  "path", // root-relative source path
  "name", // basename minus extension
  "Title", // titleFromSlug(name)
  "dir", // root-relative dirname ("." at root)
  "timestamp", // vcs last-modified, else now
  "repo", // ../.. chain from the output doc's dir to the workspace root
  "description", // first sentence of the extracted/fallback description
  "description-sentence", // full description as a markdown-safe sentence
]);

export interface OkfScaffold {
  /** Workspace-relative TS/JS module dynamically imported; its default
   *  export receives the ScaffoldContext. */
  script: string | null;
  /** Non-JS escape hatch: argv spawned at the workspace root with OKF_*
   *  env; owns its own file writes. Mutually exclusive with `script`. */
  command: string[] | null;
  collect: CollectEntry[];
}

const scaffoldDefaults = (): OkfScaffold => ({ script: null, command: null, collect: [] });

export interface OkfConfig {
  viz: VizConfig;
  profile: OkfProfile;
  vcs: OkfCliVcs;
  scaffold: OkfScaffold;
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
export function splitCliSections(raw: unknown): {
  profile: OkfProfile;
  vcs: OkfCliVcs;
  scaffold: OkfScaffold;
  rest: unknown;
} {
  const profile = profileDefaults();
  const vcs = cliVcsDefaults();
  const scaffold = scaffoldDefaults();
  // Non-table top levels fall through untouched — normalizeVizConfig owns
  // that error so the message stays consistent.
  if (!isObj(raw)) return { profile, vcs, scaffold, rest: raw };
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

  const relPath = (path: string) => (v: string, p: string) => {
    const clean = v.replace(/\/+$/, "");
    if (!clean || clean.split("/").includes("..") || clean.startsWith("/"))
      errors.push(`${p}: must be a relative path without ".."`);
    return clean;
  };
  const asStr = (assign: (s: string) => void) => (v: unknown, path: string) => {
    if (typeof v === "string") assign(v);
    else errors.push(`${path}: expected a string`);
  };
  const checkPlaceholders = (tpl: string, p: string) => {
    for (const m of tpl.matchAll(/\{([A-Za-z][A-Za-z-]*)\}/g))
      if (!COLLECT_PLACEHOLDERS.has(m[1]!))
        errors.push(`${p}: unknown placeholder {${m[1]}} — known: ${[...COLLECT_PLACEHOLDERS].join(", ")}`);
  };
  const sc = top["scaffold"];
  delete top["scaffold"];
  if (sc !== undefined && sc !== null) {
    if (!isObj(sc)) errors.push("scaffold: expected a table");
    else {
      const s = { ...sc };
      const field = fieldIn(s, "scaffold");
      field(
        "script",
        asStr((v) => {
          const clean = relPath("scaffold.script")(v, "scaffold.script");
          scaffold.script = clean || null;
        }),
      );
      field("command", asStrArr((a) => (scaffold.command = a.length ? a : null)));
      const entries = s["collect"];
      delete s["collect"];
      if (entries !== undefined && entries !== null) {
        if (!Array.isArray(entries)) errors.push("scaffold.collect: expected an array of tables");
        else
          scaffold.collect = entries.map((ev, i) => {
            const p = `scaffold.collect[${i}]`;
            const e: CollectEntry = {
              glob: "",
              type: "",
              output: "",
              comment: null,
              description: null,
              title: null,
              tags: [],
              body: null,
              frontmatter: {},
            };
            if (!isObj(ev)) {
              errors.push(`${p}: expected a table`);
              return e;
            }
            const ec = { ...ev };
            const efield = fieldIn(ec, p);
            efield("glob", asStr((v) => (e.glob = v)));
            efield("type", asStr((v) => (e.type = v)));
            efield("output", asStr((v) => (e.output = relPath(`${p}.output`)(v, `${p}.output`))));
            efield("comment", asStr((v) => (e.comment = v || null)));
            efield("description", asStr((v) => (e.description = v || null)));
            efield("title", asStr((v) => (e.title = v || null)));
            efield("tags", asStrArr((a) => (e.tags = a)));
            efield("body", asStr((v) => (e.body = v || null)));
            efield("frontmatter", (v, pp) => {
              if (isObj(v) && Object.values(v).every((x) => typeof x === "string"))
                e.frontmatter = { ...(v as Record<string, string>) };
              else errors.push(`${pp}: expected a table of strings`);
            });
            for (const k of Object.keys(ec)) errors.push(`${p}.${k}: unknown key`);
            if (!e.glob) errors.push(`${p}.glob: required`);
            if (!e.type) errors.push(`${p}.type: required`);
            if (!e.output) errors.push(`${p}.output: required`);
            for (const [tpl, tp] of [
              [e.output, `${p}.output`],
              [e.description, `${p}.description`],
              [e.title, `${p}.title`],
              [e.body, `${p}.body`],
              ...Object.entries(e.frontmatter).map(([k, v]): [string, string] => [v, `${p}.frontmatter.${k}`]),
            ] as [string | null, string][])
              if (tpl) checkPlaceholders(tpl, tp);
            return e;
          });
      }
      for (const k of Object.keys(s)) errors.push(`scaffold.${k}: unknown key`);
      if (scaffold.script && scaffold.command)
        errors.push("scaffold: script and command are mutually exclusive");
    }
  }

  if (!profile.requiredFields.includes("type")) profile.requiredFields = ["type", ...profile.requiredFields];
  if (errors.length) throw new OkfConfigError("invalid okf.toml:\n  " + errors.join("\n  "));
  return { profile, vcs, scaffold, rest: top };
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

/** Best-effort bundle info for help text: never exits, never warns —
 *  discovery/parse/normalization failures all fall back to the generic
 *  defaults (a broken config must never break `okf help`). */
export function quietBundleInfo(): { dir: string; out: string; profileDoc: string | null } {
  const fallback = { dir: "knowledge", out: "viz.html", profileDoc: null };
  try {
    const found = findConfigUp(process.cwd());
    const root = found?.dir ?? gitRoot();
    if (!root) return fallback;
    const raw: unknown = found ? Bun.TOML.parse(readFileSync(join(found.dir, found.file), "utf8")) : {};
    const viz = normalizeVizConfig(splitCliSections(raw).rest); // lenient: never throws
    const profileDoc = existsSync(join(root, viz.bundle.dir, "okf-profile.md"))
      ? `${viz.bundle.dir}/okf-profile.md`
      : null;
    return { dir: viz.bundle.dir, out: viz.bundle.out, profileDoc };
  } catch {
    return fallback;
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
  let scaffold: OkfScaffold;
  try {
    const split = splitCliSections(raw);
    profile = split.profile;
    cliVcs = split.vcs;
    scaffold = split.scaffold;
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
  ctxCache = { root, bundle: join(root, viz.bundle.dir), cfg: { viz, profile, vcs: cliVcs, scaffold }, vcs };
  return ctxCache;
}
