// Render the OKF bundle as a self-contained interactive 3D graph
// (<bundle>/viz.html, gitignored — regenerate any time), in the style of
// codebase-memory-mcp's graph-ui: Three.js instanced glow spheres + bloom,
// additive edge lines, orbit camera. The force layout runs HERE at generation
// time (layout3d.ts) so the viewer renders frozen positions — nothing ever
// simulates or jiggles at runtime. The viewer app (viz-app/) is bundled by
// Bun.build with three + postprocessing and inlined, so the output is still
// one offline file:// page. Repo-specific strings/settings come from an
// optional ./okf.toml at the repo root (config-cli.ts); absent -> generic.

import { existsSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { extname, join } from "node:path";
import { loadContext } from "./config-cli";
import { extractLinks, isExternal, nowISO, parseDoc, resolveLink, walkMd } from "./lib";
import { layout3d } from "./layout3d";
import { displayName } from "./viz-app/config";
import { parsePackagePlatforms, repoNameFromUrl } from "./viz-app/data";
import { esc } from "./viz-app/markdown";
import { THEMES } from "./viz-app/themes";

const argv = process.argv.slice(2);

// --check: typecheck the viewer app (svelte-check) instead of building.
if (argv.includes("--check")) {
  const r = Bun.spawnSync(["bunx", "svelte-check", "--tsconfig", "./tsconfig.json"], {
    cwd: import.meta.dir,
    stdout: "inherit",
    stderr: "inherit",
  });
  process.exit(r.exitCode ?? 1);
}

// Build-phase timings, printed with the summary on every run.
const phases: [string, number][] = [];
let phaseT0 = performance.now();
const lap = (name: string) => {
  phases.push([name, performance.now() - phaseT0]);
  phaseT0 = performance.now();
};

// Config comes from the shared loader (config-cli.ts): optional repo-root
// TOML, normalized strictly — a malformed or misspelled config fails the
// build rather than silently rendering wrong. Absent file -> generic
// defaults (no facet filters, alphabetical types, flat legend).
const { root: repo, bundle, cfg: okfCfg, vcs } = loadContext();
const cfg = okfCfg.viz;
const reserved = new Set(okfCfg.profile.reservedFiles);
/** Last-modified date (YYYY-MM-DD) for embedded file/dir panels. */
const isoDate = (rel: string) => (vcs.lastModified(rel) ?? nowISO()).slice(0, 10);

interface Node {
  id: string; type: string; title: string; desc: string;
  fm: Record<string, unknown>; body: string;
  x?: number; y?: number; z?: number;
}

const nodes: Node[] = [];
const edges: { s: string; t: string }[] = [];
const ids = new Set<string>();

for (const rel of walkMd(bundle)) {
  if (reserved.has(rel.split("/").pop()!)) continue;
  const doc = parseDoc(bundle, rel);
  const id = rel.replace(/\.md$/, "");
  ids.add(id);
  nodes.push({
    id,
    type: (doc.fm?.type as string) ?? "Unknown",
    title: (doc.fm?.title as string) ?? id,
    desc: (doc.fm?.description as string) ?? "",
    fm: doc.fm ?? {},
    body: doc.body,
  });
}
for (const n of nodes) {
  for (const target of extractLinks(n.body)) {
    if (isExternal(target)) continue;
    const resolved = resolveLink(bundle, n.id + ".md", target);
    if (!resolved || !resolved.endsWith(".md")) continue;
    const t = resolved.replace(/\.md$/, "");
    if (ids.has(t) && t !== n.id) edges.push({ s: n.id, t });
  }
}
const seen = new Set<string>();
const dedupedEdges = edges.filter((e) => {
  const k = `${e.s} ${e.t}`;
  if (seen.has(k)) return false;
  seen.add(k);
  return true;
});
lap("graph");

// --- Embed referenced source files, highlighted at generation time ----------
// The viewer is a self-contained file:// page (no fetch), so every repo file a
// concept references is bundled in, pre-highlighted by a small lexer. Not
// tree-sitter — token-level only — but zero runtime deps and offline.

/** Escape text, wrapping any https?:// URLs in it as external links. */
function linkifyUrls(s: string): string {
  let out = "";
  let last = 0;
  for (const m of s.matchAll(/https?:\/\/[^\s"'`<>]+/g)) {
    let url = m[0];
    const trail = url.match(/[.,;:!?)\]}]+$/);
    if (trail) url = url.slice(0, -trail[0].length);
    out += esc(s.slice(last, m.index!));
    out += `<a href="${esc(url)}" target="_blank" rel="noopener">${esc(url)}</a>`;
    last = m.index! + url.length;
  }
  return out + esc(s.slice(last));
}

const LANG_BY_EXT: Record<string, string> = {
  ".nix": "nix", ".ts": "ts", ".js": "ts", ".mjs": "ts", ".sh": "shell", ".zsh": "shell",
  ".bash": "shell", ".md": "markdown", ".toml": "toml", ".yaml": "yaml", ".yml": "yaml",
  ".json": "json", ".lua": "lua", ".conf": "conf",
};

const KEYWORDS: Record<string, string> = {
  nix: "let in if then else with inherit rec assert import or true false null",
  ts: "const let var function return if else for while of in new import export from await async type interface class extends throw try catch switch case default break continue true false null undefined",
  shell: "if then else elif fi for while until do done case esac function local exec exit return set trap source alias export readonly echo shift",
  lua: "local function end if then else elseif for while do return require true false nil",
  toml: "true false", yaml: "true false null", json: "true false null",
};

function highlight(src: string, lang: string): string {
  const kw = new Set((KEYWORDS[lang] ?? "").split(" ").filter(Boolean));
  const NEVER = "(?!x)x";
  const comment =
    lang === "ts" ? "\\/\\/[^\\n]*|\\/\\*[\\s\\S]*?\\*\\/"
    : lang === "lua" ? "--\\[\\[[\\s\\S]*?\\]\\]|--[^\\n]*"
    : lang === "nix" ? "#[^\\n]*|\\/\\*[\\s\\S]*?\\*\\/"
    : ["shell", "toml", "yaml", "conf"].includes(lang) ? "#[^\\n]*"
    : NEVER;
  const str =
    lang === "nix" ? `''(?:[^']|'[^'])*''|"(?:\\\\.|[^"\\\\])*"`
    : lang === "markdown" || lang === "text" ? NEVER
    : "`(?:\\\\.|[^`\\\\])*`|\"(?:\\\\.|[^\"\\\\\\n])*\"|'(?:\\\\.|[^'\\\\\\n])*'";
  const master = new RegExp(
    `(${comment})|(${str})|(\\b\\d[\\d._]*\\b)|(https?:\\/\\/[^\\s"'\`<>]+)|([A-Za-z_][\\w'-]*)`,
    "g",
  );
  let out = "";
  let last = 0;
  for (const m of src.matchAll(master)) {
    out += esc(src.slice(last, m.index!));
    const tok = m[0];
    if (m[1]) out += `<span class="tok-c">${linkifyUrls(tok)}</span>`;
    else if (m[2]) out += `<span class="tok-s">${linkifyUrls(tok)}</span>`;
    else if (m[3]) out += `<span class="tok-n">${esc(tok)}</span>`;
    else if (m[4]) out += linkifyUrls(tok);
    else out += kw.has(tok) ? `<span class="tok-k">${esc(tok)}</span>` : esc(tok);
    last = m.index! + tok.length;
  }
  return out + esc(src.slice(last));
}

interface Embedded { html: string; lang: string; lines: number; size: number; date: string; refs: string[]; md?: string }
const files: Record<string, Embedded> = {};

function addFile(rel: string, ref: string) {
  const existing = files[rel];
  if (existing) {
    if (!existing.refs.includes(ref)) existing.refs.push(ref);
    return;
  }
  if (rel.split("/").includes("..")) return;
  const abs = join(repo, rel);
  if (!existsSync(abs) || !statSync(abs).isFile()) return;
  const size = statSync(abs).size;
  if (size > cfg.embed.maxBytes) return;
  const text = readFileSync(abs, "utf8");
  if (text.includes("\u0000")) return;
  const lang = LANG_BY_EXT[extname(rel)] ?? "text";
  files[rel] = {
    // Markdown ships raw and is rendered by the viewer; everything else is
    // pre-highlighted into a source view here.
    html: lang === "markdown" ? "" : highlight(text, lang),
    ...(lang === "markdown" ? { md: text } : {}),
    lang,
    lines: text.split("\n").length,
    size,
    date: isoDate(rel),
    refs: [ref],
  };
}

// Referenced *directories* (sub-flakes, stow packages, plugin spec trees) get
// a browsable listing: the dir's git-tracked children are recorded and every
// descendant file is embedded via addFile (same size/binary caps).
interface EmbeddedDir { files: string[]; dirs: string[]; date: string; refs: string[] }
const dirs: Record<string, EmbeddedDir> = {};

const childFiles = new Map<string, string[]>();
const childDirs = new Map<string, Set<string>>();
for (const f of vcs.trackedFiles()) {
  const parts = f.split("/");
  for (let i = 0; i < parts.length - 1; i++) {
    const dir = parts.slice(0, i + 1).join("/");
    if (i + 2 === parts.length) {
      if (!childFiles.has(dir)) childFiles.set(dir, []);
      childFiles.get(dir)!.push(f);
    } else {
      if (!childDirs.has(dir)) childDirs.set(dir, new Set());
      childDirs.get(dir)!.add(parts.slice(0, i + 2).join("/"));
    }
  }
}

function addDir(rel: string, ref: string) {
  const existing = dirs[rel];
  if (existing) {
    if (!existing.refs.includes(ref)) existing.refs.push(ref);
    return;
  }
  const fs = (childFiles.get(rel) ?? []).slice().sort();
  const ds = [...(childDirs.get(rel) ?? [])].sort();
  if (!fs.length && !ds.length) return; // not a tracked directory
  dirs[rel] = { files: fs, dirs: ds, date: isoDate(rel), refs: [ref] };
  for (const f of fs) addFile(f, ref);
  for (const d of ds) addDir(d, ref);
}

/** Resource / link target that may be a file or a tracked directory. */
function addRepoPath(rel: string, ref: string) {
  rel = rel.replace(/\/$/, "");
  if (childFiles.has(rel) || childDirs.has(rel)) addDir(rel, ref);
  else addFile(rel, ref);
}

for (const n of nodes) {
  const res = n.fm?.resource;
  if (typeof res === "string") addRepoPath(res, n.id);
  for (const target of extractLinks(n.body)) {
    if (isExternal(target)) continue;
    if (resolveLink(bundle, n.id + ".md", target)) continue; // stays inside the bundle
    const inRepo = resolveLink(repo, join(cfg.bundle.dir, n.id + ".md"), target);
    if (inRepo && !inRepo.startsWith(cfg.bundle.dir + "/")) addRepoPath(inRepo, n.id);
  }
  // Bare repo-path mentions in prose (e.g. "./src/lib/parser.py")
  // get embedded too, so the runtime autolinker has something to open.
  for (const m of n.body.matchAll(/(?:^|[\s(`])((?:\.\/)?(?:[A-Za-z0-9_.-]+\/)+[A-Za-z0-9_.-]+\.[A-Za-z0-9]{1,6})/g)) {
    addFile(m[1].replace(/^\.\//, ""), n.id);
  }
}
// --- Revision-citation outbound links ----------------------------------------
// Provider-defined citation spans (git: `abc1234` code spans, the profile's
// convention) become outbound forge links via vcs.commit-url-template. Every
// candidate is verified against the local workspace, so doc examples and
// other repos' revs stay plain code; verified citations link by full id
// (stable even if the abbreviation later becomes ambiguous).
const hashCandidates = new Set<string>();
if (vcs.revisionPattern) {
  for (const n of nodes) for (const m of n.body.matchAll(vcs.revisionPattern)) hashCandidates.add(m[1]);
  for (const f of Object.values(files)) if (f.md) for (const m of f.md.matchAll(vcs.revisionPattern)) hashCandidates.add(m[1]);
}
const repoUrl = cfg.vcs.url ?? vcs.remoteUrl();
const commits = repoUrl ? vcs.resolveRevisions([...hashCandidates]) : {};
// The template pre-substituted with the resolved URL; the viewer only fills
// {hash}. Null: no URL -> citations render as plain code.
const commitUrl = repoUrl ? cfg.vcs.commitUrlTemplate.split("{url}").join(repoUrl) : null;
// Facet classifiers: for each facet with a classify source, build its
// name -> value map. "nix-optional-attrs" parses the configured file's
// `optionalAttrs` guard blocks (missing file -> {} -> every concept of that
// facet's classify.types falls through unresolved); "command" runs the
// configured argv at the workspace root and must print a JSON object of
// string values — any failure or out-of-range value fails the build
// (strict-config philosophy: silent misclassification is worse).
const facetMaps: Record<string, Record<string, string>> = {};
for (const f of cfg.facets) {
  const cl = f.classify;
  if (!cl) continue;
  if (cl.provider === "nix-optional-attrs") {
    const file = join(repo, cl.file);
    facetMaps[f.name] = existsSync(file) ? parsePackagePlatforms(readFileSync(file, "utf8"), cl.guards) : {};
    continue;
  }
  const r = Bun.spawnSync({ cmd: cl.command, cwd: repo, stdout: "pipe", stderr: "inherit" });
  if (r.exitCode !== 0) {
    console.error(`viz: facet.${f.name}.classify command failed (exit ${r.exitCode}): ${cl.command.join(" ")}`);
    process.exit(1);
  }
  let map: unknown;
  try {
    map = JSON.parse(r.stdout.toString());
  } catch {
    console.error(`viz: facet.${f.name}.classify command did not print valid JSON: ${cl.command.join(" ")}`);
    process.exit(1);
  }
  if (typeof map !== "object" || map === null || Array.isArray(map) || Object.values(map).some((v) => typeof v !== "string")) {
    console.error(`viz: facet.${f.name}.classify command must print a JSON object of string values`);
    process.exit(1);
  }
  const m = map as Record<string, string>;
  if (f.values.length)
    for (const [k, v] of Object.entries(m))
      if (!f.values.includes(v)) {
        console.error(`viz: facet.${f.name}.classify: "${k}" = "${v}" is not in facet.${f.name}.values`);
        process.exit(1);
      }
  facetMaps[f.name] = m;
}
// A concept explicitly frontmatter-tagged with a value outside its facet's
// declared `values` is unresolved (data.ts's facetValueOf), not a silent
// typo — warn at build time (buildModel runs app-side and never warns).
for (const f of cfg.facets) {
  if (!f.frontmatter || !f.values.length) continue;
  for (const n of nodes) {
    const v = n.fm[f.frontmatter];
    if (typeof v === "string" && !f.values.includes(v))
      console.warn(
        `viz: warning: ${n.id}: facet.${f.name}.frontmatter "${f.frontmatter}" = "${v}" is not in facet.${f.name}.values — unresolved`,
      );
  }
}
lap("sources");

// --- Frozen 3D layout ---------------------------------------------------------
const positions = layout3d(nodes.map((n) => n.id), dedupedEdges);
for (const n of nodes) Object.assign(n, positions.get(n.id));
lap("layout");

// --- Bundle the viewer app (Svelte 5 via bun-plugin-svelte) ---------------------
if (!existsSync(join(import.meta.dir, "node_modules", "svelte"))) {
  console.log("viz: installing viewer dependencies (bun install)…");
  const r = Bun.spawnSync(["bun", "install"], { cwd: import.meta.dir, stdout: "inherit", stderr: "inherit" });
  if (r.exitCode !== 0) process.exit(r.exitCode ?? 1);
}
// Imported lazily so a fresh clone reaches the install step above first.
const { SveltePlugin } = await import("bun-plugin-svelte");
const build = await Bun.build({
  entrypoints: [join(import.meta.dir, "viz-app", "main.ts")],
  target: "browser",
  format: "esm",
  minify: true,
  plugins: [SveltePlugin({ development: false, compilerOptions: { runes: true } })],
});
if (!build.success) {
  for (const log of build.logs) console.error(String(log));
  process.exit(1);
}
const jsOut = build.outputs.find((o) => o.kind === "entry-point");
if (!jsOut) {
  console.error("viz: no entry-point in build output");
  process.exit(1);
}
const appJs = (await jsOut.text()).replace(/<\/script/gi, "<\\/script");
// Component CSS comes out as separate artifacts (the plugin compiles with
// css: "external") — inline them so the page stays a single offline file.
let appCss = "";
for (const o of build.outputs) if (o.path.endsWith(".css")) appCss += await o.text();
appCss = appCss.replace(/<\/style/gi, "<\\/style");
lap("bundle");

const data = JSON.stringify({ nodes, edges: dedupedEdges, files, dirs, repoUrl, commitUrl, commits, facetMaps, cfg }).replace(
  /<\//g,
  "<\\/",
);

/** :root custom-property block for a named theme stop, from the app's THEMES. */
const themeCss = (name: string) =>
  Object.entries(THEMES.find((t) => t.name === name)!.vars)
    .map(([k, v]) => `${k}: ${v};`)
    .join(" ");

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(displayName(cfg, repoNameFromUrl(repoUrl)))} — ${esc(cfg.display.title)}</title>
<style>
  /* Un-picked defaults: the "light" and "dark" stops from viz-app/themes.ts,
     inlined at build time so the pre-hydration paint can never drift. */
  :root { ${themeCss("light")} }
  @media (prefers-color-scheme: dark) {
    :root { ${themeCss("dark")} }
  }
  * { box-sizing: border-box; margin: 0; }
  a { color: var(--link); text-underline-offset: 2px;
      text-decoration-color: color-mix(in srgb, var(--link) 45%, transparent); }
  a:hover { text-decoration-color: var(--link); }
  html, body { height: 100%; }
  body {
    font: 14px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif;
    color: var(--ink-1); background: var(--page);
    position: relative; overflow: hidden;
  }
  /* Shared sidebar-control primitives (used by the legend head, the facet
     and neighborhood segmented controls) — global so the controls don't each
     re-declare an identical scoped copy. */
  .hint {
    margin-right: auto;
    color: var(--ink-muted); font-size: 11px;
    text-transform: uppercase; letter-spacing: 0.05em;
  }
  .seg {
    padding: 2px 6px; font: inherit; font-size: 12px;
    color: var(--ink-muted); background: none;
    border: 1px solid transparent; border-radius: 5px; cursor: pointer;
  }
  .seg:hover { color: var(--ink-1); }
  .seg.active {
    color: var(--ink-1); border-color: var(--grid);
    background: var(--page); font-weight: 600;
  }
</style>
<style>${appCss}</style>
</head>
<body>
<script id="data" type="application/json">${data}</script>
<script type="module">${appJs}</script>
</body>
</html>
`;

const out = join(bundle, cfg.bundle.out);
writeFileSync(out, html);
lap("write");
const fmtMs = (ms: number) => (ms < 10 ? ms.toFixed(1) : String(Math.round(ms))) + "ms";
console.log(`viz build: ${phases.map(([n, ms]) => `${n} ${fmtMs(ms)}`).join(" · ")}`);
console.log(
  `viz: ${nodes.length} nodes, ${dedupedEdges.length} edges, ${Object.keys(files).length} files, ${Object.keys(dirs).length} dirs, ${Object.keys(commits).length}/${hashCandidates.size} commit links -> ${out} (${(html.length / 1024).toFixed(0)} KB)`,
);

// --perf: measure viewer startup in headless Chrome against the file we just wrote.
if (argv.includes("--perf")) {
  const { measureStartup, printStartup } = await import("./viz-perf");
  printStartup(await measureStartup(out));
}
