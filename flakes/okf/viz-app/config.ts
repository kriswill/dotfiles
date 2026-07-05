// Shared viz configuration: schema, generic defaults, and normalization.
// Browser-safe (no bun/node imports). The build side (config-cli.ts) parses
// the repo-root okf.toml with Bun.TOML.parse, normalizes STRICTLY (misconfig
// fails the build), and embeds the normalized result in the #data blob; the
// app re-normalizes LENIENTLY in buildModel (defaults-fill, never throws),
// which is also what gives test fixtures and no-config bundles a working
// generic viewer. Normalization accepts both kebab-case (TOML) and camelCase
// (re-normalizing its own output) spellings, so it is idempotent.

import { DATE_FORMATS, type DateFormat } from "./dates";

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
    /** Detail-panel date rendering: "iso" (as written), "us" ("Jul 3, 2026"),
     *  or "international" ("3 Jul 2026"). */
    dateFormat: DateFormat;
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
  vcs: {
    /** Web URL of the repo (null: derive from the VCS remote, any forge). */
    url: string | null;
    /** Outbound revision-link template; `{url}` and `{hash}` substitute the
     *  resolved repo URL and the full revision id. GitLab canonical form is
     *  "{url}/-/commit/{hash}", Bitbucket "{url}/commits/{hash}". */
    commitUrlTemplate: string;
  };
  /** 0..n independent filter lenses; file order (TOML) / array order (JSON)
   *  is the sidebar control order. */
  facets: FacetConfig[];
}

/** Opt-in build-side classifier producing a name -> value map that concepts
 *  of the listed `types` consult (keyed by `key`; a miss falls through
 *  unresolved). Providers: "nix-optional-attrs" parses the optionalAttrs
 *  guard blocks of a Nix file; "command" runs an argv at the workspace root
 *  that prints the map as JSON. The legacy `nix-packages` table spelling
 *  normalizes to the nix-optional-attrs provider. */
export type FacetClassify =
  | {
      provider: "nix-optional-attrs";
      /** Repo-relative Nix file to parse. */
      file: string;
      /** optionalAttrs predicate substring -> value. */
      guards: Record<string, string>;
      types: string[];
      key: "basename" | "id";
    }
  | {
      provider: "command";
      /** Argv run at the workspace root; stdout must be a JSON object of
       *  string values. Failure fails the viz build. */
      command: string[];
      types: string[];
      key: "basename" | "id";
    };

export interface FacetConfig {
  /** Segmented-control label and hash-param name; `^[a-z][a-z0-9-]*$`, not
   *  one of the reserved names, unique across facets. */
  name: string;
  /** Ordered filter segments after "all". Empty: inferred from observed
   *  resolutions across all concepts, alpha-sorted. */
  values: string[];
  /** Concept type -> value; unlisted types are unaffected by this facet
   *  (always visible, i.e. "unresolved"). */
  types: Record<string, string>;
  /** Full concept id -> value; highest-precedence override. */
  ids: Record<string, string>;
  /** Frontmatter key read as this facet's value (string values only; null:
   *  no frontmatter source). */
  frontmatter: string | null;
  /** Build-side classifier source (null: none for this facet). */
  classify: FacetClassify | null;
}

/** Facet names reserved because they collide with hash-param names or the
 *  "all" sentinel value. */
const RESERVED_FACET_NAMES = new Set(["hide", "q", "isolate", "os", "all"]);
const FACET_NAME_RE = /^[a-z][a-z0-9-]*$/;

export class VizConfigError extends Error {}

/** Generic bundle dir — also the default for markdown.ts's createMd. */
export const DEFAULT_BUNDLE_DIR = "knowledge";

const GENERIC_ABOUT =
  'A navigable map of this repository’s OKF knowledge bundle — concepts authored in the ' +
  '<a href="https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md" ' +
  'target="_blank" rel="noopener">Open Knowledge Format</a> and cross-linked into a graph. ' +
  "Click a node to read its document.";

const defaults = (): VizConfig => ({
  bundle: { dir: DEFAULT_BUNDLE_DIR, out: "viz.html" },
  display: {
    title: "OKF knowledge graph",
    badge: "OKF viz",
    fallbackName: "OKF bundle",
    name: null,
    aboutHtml: GENERIC_ABOUT,
    dateFormat: "iso",
  },
  embed: { maxBytes: 200_000 },
  taxonomy: { types: [], dirGroups: {}, groupOrder: [], other: "Other" },
  vcs: { url: null, commitUrlTemplate: "{url}/commit/{hash}" },
  facets: [],
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
      if (strict) throw new VizConfigError("okf.toml: top level must be a table");
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

      // Path fields drop trailing slashes (viz.ts and markdown.ts build
      // `dir + "/"` prefixes); nullable overrides treat "" as unset — TOML
      // has no null, so "" is the natural way to say "derive it".
      const stripSlash = (v: string) => v.replace(/\/+$/, "");
      section("bundle", (s) => {
        field(s, "bundle", "dir", asStr((v) => (cfg.bundle.dir = stripSlash(v))));
        field(s, "bundle", "out", asStr((v) => (cfg.bundle.out = stripSlash(v))));
      });
      section("display", (s) => {
        field(s, "display", "title", asStr((v) => (cfg.display.title = v)));
        field(s, "display", "badge", asStr((v) => (cfg.display.badge = v)));
        field(s, "display", "fallbackName", asStr((v) => (cfg.display.fallbackName = v)));
        field(s, "display", "name", asStr((v) => (cfg.display.name = v || null)));
        field(s, "display", "aboutHtml", asStr((v) => (cfg.display.aboutHtml = v)));
        field(s, "display", "dateFormat", (v, path) =>
          typeof v === "string" && (DATE_FORMATS as readonly string[]).includes(v)
            ? (cfg.display.dateFormat = v as DateFormat)
            : bad(path, `expected one of: ${DATE_FORMATS.join(", ")}`),
        );
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
      // Legacy [repo] url — the pre-[vcs] spelling; normalizes into vcs.url
      // so old embeds and copied configs keep working. Processed first so a
      // config carrying both spellings resolves to the canonical [vcs].
      section("repo", (s) => {
        field(s, "repo", "url", asStr((v) => (cfg.vcs.url = v || null)));
      });
      section("vcs", (s) => {
        field(s, "vcs", "url", asStr((v) => (cfg.vcs.url = v || null)));
        field(s, "vcs", "commitUrlTemplate", asStr((v) => (cfg.vcs.commitUrlTemplate = v)));
      });

      // Facets: name-keyed [facet.<name>] TOML tables, or this file's own
      // `facets` array output (re-normalizing an embedded cfg) — never both,
      // so the two shapes can't ambiguously merge into one facet list.
      const facetTable = top["facet"];
      const facetsArr = top["facets"];
      delete top["facet"];
      delete top["facets"];
      const present = (v: unknown) => v !== undefined && v !== null;
      if (present(facetTable) && present(facetsArr))
        bad("facet", "cannot specify both facet (table) and facets (array)");
      let facetEntries: { name: string; raw: Record<string, unknown> }[] = [];
      if (present(facetsArr)) {
        if (Array.isArray(facetsArr))
          facetEntries = facetsArr.filter(isObj).map((v) => {
            const { name, ...rest } = v as Record<string, unknown>;
            return { name: typeof name === "string" ? name : "", raw: rest };
          });
        else bad("facets", "expected an array");
      } else if (present(facetTable)) {
        if (!isObj(facetTable)) bad("facet", "expected a table");
        else facetEntries = Object.entries(facetTable).map(([name, v]) => ({ name, raw: isObj(v) ? { ...v } : {} }));
      }
      cfg.facets = facetEntries.map(({ name, raw: fraw }) => {
        const s = { ...fraw };
        const path = `facet.${name || "?"}`;
        const f: FacetConfig = { name, values: [], types: {}, ids: {}, frontmatter: null, classify: null };
        field(s, path, "values", asStrArr((v) => (f.values = v)));
        field(s, path, "types", asStrMap((v) => (f.types = v)));
        field(s, path, "ids", asStrMap((v) => (f.ids = v)));
        field(s, path, "frontmatter", asStr((v) => (f.frontmatter = v || null)));
        // `legacyProvider` set = the old [facet.<n>.nix-packages] spelling,
        // which implies the nix-optional-attrs provider and has no provider key.
        const parseClassify = (v: unknown, p: string, legacyProvider: "nix-optional-attrs" | null) => {
          if (!isObj(v)) return bad(p, "expected a table");
          const cl = { ...v };
          let provider: string = legacyProvider ?? "";
          let file: string | null = null;
          let guards: Record<string, string> = {};
          let command: string[] = [];
          let types: string[] = [];
          let key: "basename" | "id" = "basename";
          if (!legacyProvider)
            field(cl, p, "provider", (x, pp) => {
              if (x === "nix-optional-attrs" || x === "command") provider = x;
              else bad(pp, 'expected "nix-optional-attrs" or "command"');
            });
          field(cl, p, "file", asStr((x) => (file = stripSlash(x) || null)));
          field(cl, p, "guards", asStrMap((x) => (guards = x)));
          field(cl, p, "command", asStrArr((x) => (command = x)));
          field(cl, p, "types", asStrArr((x) => (types = x)));
          field(cl, p, "key", (x, pp) => {
            if (x === "basename" || x === "id") key = x;
            else bad(pp, 'expected "basename" or "id"');
          });
          for (const k of Object.keys(cl)) bad(`${p}.${k}`, "unknown key");
          if (provider === "command") {
            if (file || Object.keys(guards).length) bad(p, "file/guards only apply to the nix-optional-attrs provider");
            f.classify = { provider, command, types, key };
          } else if (provider === "nix-optional-attrs") {
            if (command.length) bad(p, "command only applies to the command provider");
            if (file) f.classify = { provider, file, guards, types, key };
            else bad(`${p}.file`, "required");
          } else bad(`${p}.provider`, "required");
        };
        field(s, path, "classify", (v, p) => parseClassify(v, p, null));
        field(s, path, "nixPackages", (v, p) => {
          if (f.classify) return bad(p, "cannot specify both classify and nix-packages");
          parseClassify(v, p, "nix-optional-attrs");
        });
        for (const k of Object.keys(s)) bad(`${path}.${k}`, "unknown key");
        return f;
      });

      for (const k of Object.keys(top)) bad(k, "unknown key");
    }
  }

  // Cross-field validation (strict only — lenient input is our own output).
  if (strict) {
    const facetNames = cfg.facets.map((f) => f.name);
    if (new Set(facetNames).size !== facetNames.length) errors.push("facet: duplicate facet names");
    for (const f of cfg.facets) {
      const path = `facet.${f.name}`;
      if (!FACET_NAME_RE.test(f.name)) errors.push(`${path}: name must match ^[a-z][a-z0-9-]*$`);
      else if (RESERVED_FACET_NAMES.has(f.name)) errors.push(`${path}: "${f.name}" is a reserved name`);
      const vals = f.values;
      if (new Set(vals).size !== vals.length) errors.push(`${path}.values: duplicate values`);
      for (const v of vals) {
        if (!v) errors.push(`${path}.values: empty string`);
        else if (v === "all") errors.push(`${path}.values: "all" is reserved`);
      }
      if (vals.length) {
        const known = new Set(vals);
        for (const [t, v] of Object.entries(f.types))
          if (!known.has(v)) errors.push(`${path}.types."${t}": "${v}" is not in ${path}.values`);
        for (const [id, v] of Object.entries(f.ids))
          if (!known.has(v)) errors.push(`${path}.ids."${id}": "${v}" is not in ${path}.values`);
        if (f.classify?.provider === "nix-optional-attrs")
          for (const [g, v] of Object.entries(f.classify.guards))
            if (!known.has(v)) errors.push(`${path}.classify.guards.${g}: "${v}" is not in ${path}.values`);
      }
      if (f.classify) {
        if (!f.classify.types.length) errors.push(`${path}.classify.types: required`);
        if (f.classify.provider === "nix-optional-attrs" && !Object.keys(f.classify.guards).length)
          errors.push(`${path}.classify.guards: required`);
        if (f.classify.provider === "command" && !f.classify.command.length)
          errors.push(`${path}.classify.command: required`);
      }
      if (vals.length && !Object.keys(f.types).length && !Object.keys(f.ids).length && !f.classify && !f.frontmatter)
        warn(`${path}: has values but no resolution rule (types/ids/classify/frontmatter) — every concept unresolved, filter is a no-op`);
    }
    const pathFields: [string, string][] = [
      [cfg.bundle.dir, "bundle.dir"],
      [cfg.bundle.out, "bundle.out"],
      ...cfg.facets.flatMap((f): [string, string][] =>
        f.classify?.provider === "nix-optional-attrs" ? [[f.classify.file, `facet.${f.name}.classify.file`]] : [],
      ),
    ];
    for (const [p, why] of pathFields) {
      if (!p) errors.push(`${why}: must not be empty`);
      else if (p.split("/").includes("..") || p.startsWith("/")) errors.push(`${why}: must be a relative path without ".."`);
    }
    for (const [list, label] of [
      [cfg.taxonomy.types, "taxonomy.types"],
      [cfg.taxonomy.groupOrder, "taxonomy.group-order"],
    ] as const)
      if (new Set(list).size !== list.length) errors.push(`${label}: duplicate entries`);
    for (const [d, g] of Object.entries(cfg.taxonomy.dirGroups))
      if (!cfg.taxonomy.groupOrder.includes(g))
        errors.push(`taxonomy.dir-groups."${d}": "${g}" is not in taxonomy.group-order`);
    if (!cfg.vcs.commitUrlTemplate.includes("{hash}"))
      errors.push('vcs.commit-url-template: must contain "{hash}"');
    if (cfg.taxonomy.types.length > 12)
      warn(`taxonomy.types: ${cfg.taxonomy.types.length} entries but only 12 palette slots — overflow types get generated colors`);
    if (errors.length) throw new VizConfigError("invalid okf.toml:\n  " + errors.join("\n  "));
  }

  return cfg;
}
