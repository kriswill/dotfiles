// Shared viz configuration: schema, generic defaults, and normalization.
// Browser-safe (no bun/node imports). The build side (viz.ts) parses the
// repo-root viz.toml with Bun.TOML.parse, normalizes STRICTLY (misconfig
// fails the build), and embeds the normalized result in the #data blob; the
// app re-normalizes LENIENTLY in buildModel (defaults-fill, never throws),
// which is also what gives test fixtures and no-config bundles a working
// generic viewer. Normalization accepts both kebab-case (TOML) and camelCase
// (re-normalizing its own output) spellings, so it is idempotent.

export interface VizConfig {
  bundle: {
    /** OKF bundle root, repo-relative. */
    dir: string;
    /** Output file, relative to the bundle dir. */
    out: string;
  };
  display: {
    /** <title> = "<name> — <title>". */
    title: string;
    /** Sidebar h1 suffix label. */
    badge: string;
    /** Header name when no git origin (and no `name` override). */
    fallbackName: string;
    /** Hard override of the git-derived owner/repo (null: derive). */
    name: string | null;
    /** Help-bubble body — trusted repo-owner HTML, rendered via {@html}. */
    aboutHtml: string;
  };
  embed: {
    /** Per-file embed cap in bytes. */
    maxBytes: number;
  };
  taxonomy: {
    /** Palette slot order: entry N -> CSS var --sN (12 theme slots; overflow
     *  gets stable generated colors). Append-only. Empty: alphabetical types,
     *  all generated colors. */
    types: string[];
    /** Top-level bundle dir -> legend cluster ("." = root docs). Empty: flat
     *  legend without group headers. */
    dirGroups: Record<string, string>;
    /** Legend cluster display order. */
    groupOrder: string[];
    /** Bucket label for dirs missing from dirGroups. */
    other: string;
  };
  platform: {
    /** Ordered filter segments after "all". Empty: filter hidden, every
     *  concept "neutral". */
    values: string[];
    /** Concept type -> value | "both" | "neutral" | "hosts" | "packages";
     *  unlisted types are "neutral". */
    types: Record<string, string>;
    /** Host concept basename -> value (for the "hosts" rule). */
    hosts: Record<string, string>;
    /** Value for Host concepts not in `hosts` (null: neutral). */
    hostDefault: string | null;
    /** Repo-relative Nix file whose optionalAttrs OS guards classify
     *  packages (null: skip, all packages "both"). */
    packagesNix: string | null;
    /** optionalAttrs predicate substring -> value (for packagesNix). */
    nixGuards: Record<string, string>;
  };
  repo: {
    /** Override of the git-origin detection (null: derive from `origin`). */
    url: string | null;
  };
}

/** Sentinels usable as [platform.types] values besides the platform values
 *  themselves — and therefore reserved as platform value names. */
export const PLATFORM_RULES = ["both", "neutral", "hosts", "packages"] as const;
const RESERVED_VALUES = new Set(["all", ...PLATFORM_RULES]);

export class VizConfigError extends Error {}

const GENERIC_ABOUT =
  'A navigable map of this repository’s OKF knowledge bundle — concepts authored in the ' +
  '<a href="https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md" ' +
  'target="_blank" rel="noopener">Open Knowledge Format</a> and cross-linked into a graph. ' +
  "Click a node to read its document.";

const defaults = (): VizConfig => ({
  bundle: { dir: "knowledge", out: "viz.html" },
  display: {
    title: "OKF knowledge graph",
    badge: "OKF viz",
    fallbackName: "OKF bundle",
    name: null,
    aboutHtml: GENERIC_ABOUT,
  },
  embed: { maxBytes: 200_000 },
  taxonomy: { types: [], dirGroups: {}, groupOrder: [], other: "Other" },
  platform: { values: [], types: {}, hosts: {}, hostDefault: null, packagesNix: null, nixGuards: {} },
  repo: { url: null },
});

/** Header name: config override, else git-derived owner/repo, else fallback. */
export function displayName(cfg: VizConfig, repoName: string | null): string {
  return cfg.display.name ?? repoName ?? cfg.display.fallbackName;
}

const isObj = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v);

export function normalizeVizConfig(raw: unknown, opts?: { strict?: boolean; warn?: (msg: string) => void }): VizConfig {
  const strict = opts?.strict ?? false;
  const warn = opts?.warn ?? (() => {});
  const errors: string[] = [];
  const cfg = defaults();
  const bad = (path: string, why: string) => {
    if (strict) errors.push(`${path}: ${why}`);
    // lenient: keep the default silently
  };

  // One field spec per canonical key: TOML kebab spelling + a checked setter.
  // `take` consumes both spellings so the unknown-key sweep sees leftovers.
  const field = (
    section: Record<string, unknown>,
    sectionName: string,
    camel: string,
    set: (v: unknown, path: string) => void,
  ) => {
    const kebab = camel.replace(/[A-Z]/g, (c) => "-" + c.toLowerCase());
    for (const key of camel === kebab ? [camel] : [camel, kebab]) {
      if (key in section) {
        // null = "unset" (JSON round-trips of our own output), keep the default.
        if (section[key] !== null) set(section[key], `${sectionName}.${key}`);
        delete section[key];
      }
    }
  };
  const asStr = (assign: (s: string) => void) => (v: unknown, path: string) =>
    typeof v === "string" ? assign(v) : bad(path, "expected a string");
  const asNum = (assign: (n: number) => void) => (v: unknown, path: string) =>
    typeof v === "number" && Number.isFinite(v) && v > 0 ? assign(v) : bad(path, "expected a positive number");
  const asStrArr = (assign: (a: string[]) => void) => (v: unknown, path: string) =>
    Array.isArray(v) && v.every((x) => typeof x === "string")
      ? assign(v as string[])
      : bad(path, "expected an array of strings");
  const asStrMap = (assign: (m: Record<string, string>) => void) => (v: unknown, path: string) =>
    isObj(v) && Object.values(v).every((x) => typeof x === "string")
      ? assign({ ...(v as Record<string, string>) })
      : bad(path, "expected a table of strings");

  if (raw !== undefined && raw !== null) {
    if (!isObj(raw)) {
      if (strict) throw new VizConfigError("viz.toml: top level must be a table");
    } else {
      const top = { ...raw };
      const section = (name: string, fill: (s: Record<string, unknown>) => void) => {
        const v = top[name];
        delete top[name];
        if (v === undefined) return;
        if (!isObj(v)) return bad(name, "expected a table");
        const s = { ...v };
        fill(s);
        for (const k of Object.keys(s)) bad(`${name}.${k}`, "unknown key");
      };

      section("bundle", (s) => {
        field(s, "bundle", "dir", asStr((v) => (cfg.bundle.dir = v)));
        field(s, "bundle", "out", asStr((v) => (cfg.bundle.out = v)));
      });
      section("display", (s) => {
        field(s, "display", "title", asStr((v) => (cfg.display.title = v)));
        field(s, "display", "badge", asStr((v) => (cfg.display.badge = v)));
        field(s, "display", "fallbackName", asStr((v) => (cfg.display.fallbackName = v)));
        field(s, "display", "name", asStr((v) => (cfg.display.name = v)));
        field(s, "display", "aboutHtml", asStr((v) => (cfg.display.aboutHtml = v)));
      });
      section("embed", (s) => {
        field(s, "embed", "maxBytes", asNum((v) => (cfg.embed.maxBytes = v)));
      });
      section("taxonomy", (s) => {
        field(s, "taxonomy", "types", asStrArr((v) => (cfg.taxonomy.types = v)));
        field(s, "taxonomy", "dirGroups", asStrMap((v) => (cfg.taxonomy.dirGroups = v)));
        field(s, "taxonomy", "groupOrder", asStrArr((v) => (cfg.taxonomy.groupOrder = v)));
        field(s, "taxonomy", "other", asStr((v) => (cfg.taxonomy.other = v)));
      });
      section("platform", (s) => {
        field(s, "platform", "values", asStrArr((v) => (cfg.platform.values = v)));
        field(s, "platform", "types", asStrMap((v) => (cfg.platform.types = v)));
        field(s, "platform", "hosts", asStrMap((v) => (cfg.platform.hosts = v)));
        field(s, "platform", "hostDefault", asStr((v) => (cfg.platform.hostDefault = v)));
        field(s, "platform", "packagesNix", asStr((v) => (cfg.platform.packagesNix = v)));
        field(s, "platform", "nixGuards", asStrMap((v) => (cfg.platform.nixGuards = v)));
      });
      section("repo", (s) => {
        field(s, "repo", "url", asStr((v) => (cfg.repo.url = v)));
      });
      for (const k of Object.keys(top)) bad(k, "unknown key");
    }
  }

  // Cross-field validation (strict only — lenient input is our own output).
  if (strict) {
    const vals = cfg.platform.values;
    if (new Set(vals).size !== vals.length) errors.push("platform.values: duplicate values");
    for (const v of vals) {
      if (!v) errors.push("platform.values: empty string");
      else if (RESERVED_VALUES.has(v)) errors.push(`platform.values: "${v}" is reserved`);
    }
    const known = new Set([...vals, ...PLATFORM_RULES]);
    for (const [t, v] of Object.entries(cfg.platform.types))
      if (!known.has(v)) errors.push(`platform.types."${t}": "${v}" is not in platform.values or ${PLATFORM_RULES.join("/")}`);
    for (const [h, v] of Object.entries(cfg.platform.hosts))
      if (!vals.includes(v)) errors.push(`platform.hosts.${h}: "${v}" is not in platform.values`);
    if (cfg.platform.hostDefault !== null && !vals.includes(cfg.platform.hostDefault))
      errors.push(`platform.host-default: "${cfg.platform.hostDefault}" is not in platform.values`);
    for (const [g, v] of Object.entries(cfg.platform.nixGuards))
      if (!vals.includes(v)) errors.push(`platform.nix-guards.${g}: "${v}" is not in platform.values`);
    if (vals.length === 0 && (Object.keys(cfg.platform.types).length || cfg.platform.packagesNix))
      errors.push("platform.values: required when [platform] rules are configured");
    for (const [p, why] of [
      [cfg.bundle.dir, "bundle.dir"],
      [cfg.bundle.out, "bundle.out"],
      [cfg.platform.packagesNix ?? "x", "platform.packages-nix"],
    ] as const) {
      if (!p) errors.push(`${why}: must not be empty`);
      else if (p.split("/").includes("..") || p.startsWith("/")) errors.push(`${why}: must be a relative path without ".."`);
    }
    for (const [d, g] of Object.entries(cfg.taxonomy.dirGroups))
      if (!cfg.taxonomy.groupOrder.includes(g))
        errors.push(`taxonomy.dir-groups."${d}": "${g}" is not in taxonomy.group-order`);
    if (cfg.taxonomy.types.length > 12)
      warn(`taxonomy.types: ${cfg.taxonomy.types.length} entries but only 12 palette slots — overflow types get generated colors`);
    if (errors.length) throw new VizConfigError("invalid viz.toml:\n  " + errors.join("\n  "));
  }

  return cfg;
}
