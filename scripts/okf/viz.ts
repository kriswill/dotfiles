// Render the knowledge/ bundle as a self-contained interactive 3D graph
// (knowledge/viz.html, gitignored — regenerate any time), in the style of
// codebase-memory-mcp's graph-ui: Three.js instanced glow spheres + bloom,
// additive edge lines, orbit camera. The force layout runs HERE at generation
// time (layout3d.ts) so the viewer renders frozen positions — nothing ever
// simulates or jiggles at runtime. The viewer app (viz-app/) is bundled by
// Bun.build with three + postprocessing and inlined, so the output is still
// one offline file:// page.

import { existsSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { extname, join } from "node:path";
import { bundleRoot, extractLinks, gitISO, isExternal, parseDoc, repoRoot, resolveLink, walkMd, RESERVED } from "./lib";
import { layout3d } from "./layout3d";

const bundle = bundleRoot();

interface Node {
  id: string; type: string; title: string; desc: string;
  fm: Record<string, unknown>; body: string;
  x?: number; y?: number; z?: number;
}

const nodes: Node[] = [];
const edges: { s: string; t: string }[] = [];
const ids = new Set<string>();

for (const rel of walkMd(bundle)) {
  if (RESERVED.has(rel.split("/").pop()!)) continue;
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

// --- Embed referenced source files, highlighted at generation time ----------
// The viewer is a self-contained file:// page (no fetch), so every repo file a
// concept references is bundled in, pre-highlighted by a small lexer. Not
// tree-sitter — token-level only — but zero runtime deps and offline.

const escHtml = (s: string) =>
  s.replace(/[&<>"]/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[ch]!);

/** Escape text, wrapping any https?:// URLs in it as external links. */
function linkifyUrls(s: string): string {
  let out = "";
  let last = 0;
  for (const m of s.matchAll(/https?:\/\/[^\s"'`<>]+/g)) {
    let url = m[0];
    const trail = url.match(/[.,;:!?)\]}]+$/);
    if (trail) url = url.slice(0, -trail[0].length);
    out += escHtml(s.slice(last, m.index!));
    out += `<a href="${escHtml(url)}" target="_blank" rel="noopener">${escHtml(url)}</a>`;
    last = m.index! + url.length;
  }
  return out + escHtml(s.slice(last));
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
    out += escHtml(src.slice(last, m.index!));
    const tok = m[0];
    if (m[1]) out += `<span class="tok-c">${linkifyUrls(tok)}</span>`;
    else if (m[2]) out += `<span class="tok-s">${linkifyUrls(tok)}</span>`;
    else if (m[3]) out += `<span class="tok-n">${escHtml(tok)}</span>`;
    else if (m[4]) out += linkifyUrls(tok);
    else out += kw.has(tok) ? `<span class="tok-k">${escHtml(tok)}</span>` : escHtml(tok);
    last = m.index! + tok.length;
  }
  return out + escHtml(src.slice(last));
}

const repo = repoRoot();
interface Embedded { html: string; lang: string; lines: number; size: number; date: string; refs: string[] }
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
  if (size > 200_000) return;
  const text = readFileSync(abs, "utf8");
  if (text.includes("\u0000")) return;
  const lang = LANG_BY_EXT[extname(rel)] ?? "text";
  files[rel] = {
    html: highlight(text, lang),
    lang,
    lines: text.split("\n").length,
    size,
    date: gitISO(rel).slice(0, 10),
    refs: [ref],
  };
}

for (const n of nodes) {
  const res = n.fm?.resource;
  if (typeof res === "string") addFile(res.replace(/\/$/, ""), n.id);
  for (const target of extractLinks(n.body)) {
    if (isExternal(target)) continue;
    if (resolveLink(bundle, n.id + ".md", target)) continue; // stays inside the bundle
    const inRepo = resolveLink(repo, join("knowledge", n.id + ".md"), target);
    if (inRepo && !inRepo.startsWith("knowledge/")) addFile(inRepo, n.id);
  }
  // Bare repo-path mentions in prose (e.g. "./flakes/x/darwin-module.nix")
  // get embedded too, so the runtime autolinker has something to open.
  for (const m of n.body.matchAll(/(?:^|[\s(`])((?:\.\/)?(?:[A-Za-z0-9_.-]+\/)+[A-Za-z0-9_.-]+\.[A-Za-z0-9]{1,6})/g)) {
    addFile(m[1].replace(/^\.\//, ""), n.id);
  }
}

// --- Frozen 3D layout ---------------------------------------------------------
const positions = layout3d(nodes.map((n) => n.id), dedupedEdges);
for (const n of nodes) Object.assign(n, positions.get(n.id));

// --- Bundle the viewer app ------------------------------------------------------
if (!existsSync(join(import.meta.dir, "node_modules", "three"))) {
  console.log("viz: installing viewer dependencies (bun install)…");
  const r = Bun.spawnSync(["bun", "install"], { cwd: import.meta.dir, stdout: "inherit", stderr: "inherit" });
  if (r.exitCode !== 0) process.exit(r.exitCode ?? 1);
}
const build = await Bun.build({
  entrypoints: [join(import.meta.dir, "viz-app", "main.ts")],
  target: "browser",
  format: "esm",
  minify: true,
});
if (!build.success) {
  for (const log of build.logs) console.error(String(log));
  process.exit(1);
}
const appJs = (await build.outputs[0].text()).replace(/<\/script/gi, "<\\/script");

const data = JSON.stringify({ nodes, edges: dedupedEdges, files }).replace(/<\//g, "<\\/");

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>knowledge/ — OKF bundle graph</title>
<style>
  :root {
    --surface-1: #fcfcfb; --page: #f9f9f7;
    --ink-1: #0b0b0b; --ink-2: #52514e; --ink-muted: #898781;
    --grid: #e1e0d9; --baseline: #c3c2b7;
    --link: #256abf;
    --tok-c: #898781; --tok-s: #0b7a4e; --tok-k: #4a3aa7; --tok-n: #9a5b00;
    --s1:#2a78d6; --s2:#1baf7a; --s3:#eda100; --s4:#008300;
    --s5:#4a3aa7; --s6:#e34948; --s7:#e87ba4; --s8:#eb6834;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --surface-1: #1a1a19; --page: #0d0d0d;
      --ink-1: #ffffff; --ink-2: #c3c2b7; --ink-muted: #898781;
      --grid: #2c2c2a; --baseline: #383835;
      --link: #6da7ec;
      --tok-c: #898781; --tok-s: #2fbe8b; --tok-k: #9085e9; --tok-n: #d99a1f;
      --s1:#3987e5; --s2:#199e70; --s3:#c98500; --s4:#008300;
      --s5:#9085e9; --s6:#e66767; --s7:#d55181; --s8:#d95926;
    }
  }
  * { box-sizing: border-box; margin: 0; }
  a { color: var(--link); text-underline-offset: 2px;
      text-decoration-color: color-mix(in srgb, var(--link) 45%, transparent); }
  a:hover { text-decoration-color: var(--link); }
  html, body { height: 100%; }
  body {
    font: 14px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif;
    color: var(--ink-1); background: var(--page);
    display: grid; grid-template-columns: 260px 1fr; overflow: hidden;
  }
  #side {
    border-right: 1px solid var(--grid); background: var(--surface-1);
    padding: 14px; overflow-y: auto; z-index: 2;
  }
  #side h1 { font-size: 15px; margin-bottom: 2px; }
  #side .sub { color: var(--ink-muted); font-size: 12px; margin-bottom: 12px; }
  #q {
    width: 100%; padding: 6px 8px; font: inherit; color: inherit;
    background: var(--page); border: 1px solid var(--baseline); border-radius: 6px;
    margin-bottom: 12px;
  }
  .leg { display: flex; align-items: center; gap: 8px; padding: 3px 4px;
         border-radius: 5px; cursor: pointer; user-select: none; }
  .leg:hover { background: var(--page); }
  .leg.off { opacity: 0.35; }
  .dot { width: 10px; height: 10px; border-radius: 50%; flex: none;
         box-shadow: 0 0 0 2px var(--surface-1); }
  .leg .n { margin-left: auto; color: var(--ink-muted); font-size: 12px;
            font-variant-numeric: tabular-nums; }
  #list { margin-top: 14px; border-top: 1px solid var(--grid); padding-top: 10px; }
  #list a { display: block; padding: 3px 4px; border-radius: 5px; color: var(--ink-2);
            text-decoration: none; font-size: 13px; white-space: nowrap;
            overflow: hidden; text-overflow: ellipsis; }
  #list a:hover { background: var(--page); color: var(--ink-1); }
  #stage { position: relative; overflow: hidden; }
  #tip {
    position: absolute; pointer-events: none; display: none; max-width: 320px;
    background: var(--surface-1); border: 1px solid var(--grid); border-radius: 8px;
    padding: 8px 10px; box-shadow: 0 4px 16px rgba(0,0,0,0.12); z-index: 3;
  }
  #tip b { display: block; }
  #tip .t { color: var(--ink-muted); font-size: 12px; }
  #tip .d { color: var(--ink-2); font-size: 12px; margin-top: 3px; }
  #panel {
    position: absolute; top: 0; right: 0; bottom: 0; width: min(460px, 85%);
    background: var(--surface-1); border-left: 1px solid var(--grid);
    padding: 18px; overflow-y: auto; display: none; z-index: 2;
  }
  #panel.open { display: block; }
  .resizer { position: absolute; left: 0; top: 0; bottom: 0; width: 6px;
             cursor: col-resize; touch-action: none; }
  .resizer:hover, .resizer.active { background: var(--grid); }
  #panel .close { float: right; cursor: pointer; color: var(--ink-muted);
                  font-size: 18px; border: 0; background: none; }
  #panel h2 { font-size: 17px; margin: 0 0 4px; }
  .chip { display: inline-flex; align-items: center; gap: 6px; font-size: 12px;
          color: var(--ink-2); border: 1px solid var(--grid); border-radius: 999px;
          padding: 2px 9px; margin-bottom: 10px; }
  table.fm { width: 100%; border-collapse: collapse; font-size: 12px; margin: 8px 0 14px; }
  table.fm td { border-top: 1px solid var(--grid); padding: 4px 6px; vertical-align: top; }
  table.fm td:first-child { color: var(--ink-muted); white-space: nowrap; width: 1%; }
  #body-md { font-size: 13.5px; color: var(--ink-2); }
  #body-md h3 { color: var(--ink-1); font-size: 14px; margin: 14px 0 6px; }
  #body-md p, #body-md ul, #body-md ol, #body-md pre { margin: 0 0 8px; }
  #body-md ul, #body-md ol { padding-left: 20px; }
  #body-md li { margin-bottom: 3px; }
  #body-md code { font: 12px ui-monospace, Menlo, monospace; background: var(--page);
                  border: 1px solid var(--grid); border-radius: 4px; padding: 0 4px; }
  #body-md pre { background: var(--page); border: 1px solid var(--grid); border-radius: 6px;
                 padding: 8px 10px; overflow-x: auto; }
  #body-md pre code { border: 0; background: none; padding: 0; }
  #body-md .tbl-wrap { overflow-x: auto; margin: 0 0 10px; }
  #body-md .tbl-wrap table { border-collapse: collapse; font-size: 12.5px; width: 100%; }
  #body-md .tbl-wrap th, #body-md .tbl-wrap td { border: 1px solid var(--grid);
                 padding: 4px 8px; text-align: left; vertical-align: top; }
  #body-md .tbl-wrap th { color: var(--ink-1); background: var(--page); }
  #body-md a { color: var(--link); }
  .backlinks { border-top: 1px solid var(--grid); margin-top: 14px; padding-top: 10px; }
  .backlinks h4 { font-size: 12px; color: var(--ink-muted); margin-bottom: 4px;
                  text-transform: uppercase; letter-spacing: 0.04em; }
  .back { display: inline-block; font-size: 12px; margin: 0 0 10px; }
  .src { background: var(--page); border: 1px solid var(--grid); border-radius: 6px;
         padding: 10px 12px; overflow-x: auto; white-space: pre; margin-top: 12px;
         font: 12px/1.55 ui-monospace, Menlo, monospace; color: var(--ink-2); }
  .src a { color: inherit; text-decoration: underline; text-underline-offset: 2px; }
  .src a:hover { color: var(--link); }
  .tok-c { color: var(--tok-c); font-style: italic; }
  .tok-s { color: var(--tok-s); }
  .tok-k { color: var(--tok-k); }
  .tok-n { color: var(--tok-n); }
</style>
</head>
<body>
<aside id="side">
  <h1>knowledge/ bundle</h1>
  <div class="sub" id="counts"></div>
  <input id="q" type="search" placeholder="Search concepts…" aria-label="Search concepts">
  <div id="legend"></div>
  <div id="list"></div>
</aside>
<main id="stage">
  <div id="tip"></div>
  <section id="panel" aria-live="polite"></section>
</main>
<script id="data" type="application/json">${data}</script>
<script type="module">${appJs}</script>
</body>
</html>
`;

const out = join(bundle, "viz.html");
writeFileSync(out, html);
console.log(
  `viz: ${nodes.length} nodes, ${dedupedEdges.length} edges, ${Object.keys(files).length} files -> ${out} (${(html.length / 1024).toFixed(0)} KB)`,
);
