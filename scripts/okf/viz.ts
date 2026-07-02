// Render the knowledge/ bundle as a self-contained interactive graph
// (knowledge/viz.html, gitignored — regenerate any time). Nodes are concepts
// colored by `type`, edges are markdown cross-links between concepts; the
// detail panel shows frontmatter, the rendered body, and computed backlinks.
// No external assets: hand-rolled force layout + minimal markdown renderer.

import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { bundleRoot, extractLinks, isExternal, parseDoc, resolveLink, walkMd, RESERVED } from "./lib";

const bundle = bundleRoot();

interface Node { id: string; type: string; title: string; desc: string; fm: Record<string, unknown>; body: string; }

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

const data = JSON.stringify({ nodes, edges: dedupedEdges }).replace(/<\//g, "<\\/");

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
    --grid: #e1e0d9; --baseline: #c3c2b7; --ring: rgba(11,11,11,0.10);
    --link: #256abf;
    --s1:#2a78d6; --s2:#1baf7a; --s3:#eda100; --s4:#008300;
    --s5:#4a3aa7; --s6:#e34948; --s7:#e87ba4; --s8:#eb6834;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --surface-1: #1a1a19; --page: #0d0d0d;
      --ink-1: #ffffff; --ink-2: #c3c2b7; --ink-muted: #898781;
      --grid: #2c2c2a; --baseline: #383835; --ring: rgba(255,255,255,0.10);
      --link: #6da7ec;
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
  #stage { position: relative; }
  canvas { display: block; width: 100%; height: 100%; cursor: grab; }
  canvas.dragging { cursor: grabbing; }
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
  #body-md p, #body-md ul, #body-md pre { margin: 0 0 8px; }
  #body-md ul { padding-left: 20px; }
  #body-md code { font: 12px ui-monospace, Menlo, monospace; background: var(--page);
                  border: 1px solid var(--grid); border-radius: 4px; padding: 0 4px; }
  #body-md pre { background: var(--page); border: 1px solid var(--grid); border-radius: 6px;
                 padding: 8px 10px; overflow-x: auto; }
  #body-md pre code { border: 0; background: none; padding: 0; }
  #body-md a { color: var(--link); }
  .backlinks { border-top: 1px solid var(--grid); margin-top: 14px; padding-top: 10px; }
  .backlinks h4 { font-size: 12px; color: var(--ink-muted); margin-bottom: 4px;
                  text-transform: uppercase; letter-spacing: 0.04em; }
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
  <canvas id="c"></canvas>
  <div id="tip"></div>
  <section id="panel" aria-live="polite"></section>
</main>
<script id="data" type="application/json">${data}</script>
<script>
const DATA = JSON.parse(document.getElementById('data').textContent);
const css = k => getComputedStyle(document.documentElement).getPropertyValue(k).trim();
// Fixed slot order (never cycled); overflow types fold into muted "Other".
const TYPE_ORDER = ['Darwin Module','Nix Package','Playbook','Pattern','Decision','Host','Sub-flake','Flake-parts Module'];
let SLOT = {}, OTHER = '#898781';
function paint() {
  SLOT = {};
  TYPE_ORDER.forEach((t, i) => SLOT[t] = css('--s' + (i + 1)));
}
paint();
matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => { paint(); buildLegend(); });
const colorOf = t => SLOT[t] ?? OTHER;

const nodes = DATA.nodes.map(n => ({...n, x: 0, y: 0, vx: 0, vy: 0}));
const byId = Object.fromEntries(nodes.map(n => [n.id, n]));
const edges = DATA.edges.filter(e => byId[e.s] && byId[e.t]);
const inLinks = {};
edges.forEach(e => (inLinks[e.t] = inLinks[e.t] || []).push(e.s));
const deg = {};
edges.forEach(e => { deg[e.s] = (deg[e.s]||0)+1; deg[e.t] = (deg[e.t]||0)+1; });

// deterministic initial layout: golden-angle spiral
nodes.forEach((n, i) => {
  const a = i * 2.39996, r = 26 * Math.sqrt(i + 1);
  n.x = Math.cos(a) * r; n.y = Math.sin(a) * r;
});

const canvas = document.getElementById('c'), ctx = canvas.getContext('2d');
let W = 0, H = 0, dpr = devicePixelRatio || 1;
let scale = 1, ox = 0, oy = 0;   // view transform
function resize() {
  W = canvas.clientWidth; H = canvas.clientHeight;
  canvas.width = W * dpr; canvas.height = H * dpr;
  ox = ox || W / 2; oy = oy || H / 2;
}
addEventListener('resize', () => { resize(); draw(); });
resize();

let hidden = new Set();       // types toggled off
let match = null;             // search matcher or null
let selected = null, hover = null;
const visible = n => !hidden.has(n.type) && (!match || match(n));

let alpha = 1;
const ALPHA_MIN = 0.012;         // below this the layout is settled: stop ticking
function tick() {
  if (alpha < ALPHA_MIN) return;
  const vis = nodes.filter(visible);
  for (let i = 0; i < vis.length; i++) for (let j = i + 1; j < vis.length; j++) {
    const a = vis[i], b = vis[j];
    let dx = a.x - b.x, dy = a.y - b.y, d2 = dx*dx + dy*dy || 1;
    if (d2 < 260 * 260) {
      const f = 1400 / d2;
      dx *= f; dy *= f; a.vx += dx; a.vy += dy; b.vx -= dx; b.vy -= dy;
    }
  }
  for (const e of edges) {
    const a = byId[e.s], b = byId[e.t];
    if (!visible(a) || !visible(b)) continue;
    const dx = b.x - a.x, dy = b.y - a.y, d = Math.sqrt(dx*dx + dy*dy) || 1;
    const f = (d - 90) * 0.008;
    a.vx += dx / d * f; a.vy += dy / d * f; b.vx -= dx / d * f; b.vy -= dy / d * f;
  }
  for (const n of vis) {
    n.vx -= n.x * 0.003; n.vy -= n.y * 0.003;      // centering
    n.x += n.vx * alpha; n.y += n.vy * alpha;
    n.vx *= 0.6; n.vy *= 0.6;
  }
  alpha *= 0.985;                // decay to a full stop (no floor — a floor = endless jiggle)
}

function radius(n) { return 6 + Math.min(6, (deg[n.id] || 0) * 0.7); }

function draw() {
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, W, H);
  ctx.translate(ox, oy); ctx.scale(scale, scale);
  ctx.lineWidth = 1 / scale;
  ctx.strokeStyle = css('--baseline');
  for (const e of edges) {
    const a = byId[e.s], b = byId[e.t];
    if (!visible(a) || !visible(b)) continue;
    ctx.globalAlpha = selected && (e.s === selected.id || e.t === selected.id) ? 0.9 : 0.35;
    ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
  }
  ctx.globalAlpha = 1;
  for (const n of nodes) {
    if (!visible(n)) continue;
    const r = radius(n);
    ctx.beginPath(); ctx.arc(n.x, n.y, r, 0, 7);
    ctx.fillStyle = colorOf(n.type); ctx.fill();
    ctx.lineWidth = 2 / scale;                       // 2px surface ring spacer
    ctx.strokeStyle = css('--surface-1'); ctx.stroke();
    if (n === selected || n === hover) {
      ctx.lineWidth = 2 / scale; ctx.strokeStyle = css('--ink-1');
      ctx.beginPath(); ctx.arc(n.x, n.y, r + 2.5 / scale, 0, 7); ctx.stroke();
    }
  }
  if (scale > 0.75) {                                // labels: ink, never series color
    ctx.fillStyle = css('--ink-2');
    ctx.font = (11 / scale) + 'px system-ui, sans-serif';
    ctx.textAlign = 'center';
    for (const n of nodes) if (visible(n)) ctx.fillText(n.title, n.x, n.y + radius(n) + 12 / scale);
  }
}

for (let i = 0; i < 150; i++) tick();   // pre-settle before first paint
function frame() { tick(); draw(); requestAnimationFrame(frame); }
requestAnimationFrame(frame);
const reheat = () => { alpha = Math.max(alpha, 0.5); };

// --- interaction ------------------------------------------------------------
const toWorld = (px, py) => [(px - ox) / scale, (py - oy) / scale];
function nodeAt(px, py) {
  const [x, y] = toWorld(px, py);
  let best = null, bd = 12 / scale + 6;              // generous hit target
  for (const n of nodes) {
    if (!visible(n)) continue;
    const d = Math.hypot(n.x - x, n.y - y);
    if (d < Math.max(radius(n) + 4, bd) && (!best || d < bd)) { best = n; bd = d; }
  }
  return best;
}
let drag = null, panning = false, px0 = 0, py0 = 0;
canvas.addEventListener('pointerdown', e => {
  const n = nodeAt(e.offsetX, e.offsetY);
  if (n) { drag = n; } else { panning = true; }
  px0 = e.offsetX; py0 = e.offsetY;
  canvas.classList.add('dragging');
  canvas.setPointerCapture(e.pointerId);
});
canvas.addEventListener('pointermove', e => {
  if (drag) {
    const [x, y] = toWorld(e.offsetX, e.offsetY);
    drag.x = x; drag.y = y; drag.vx = drag.vy = 0; reheat();
  } else if (panning) {
    ox += e.offsetX - px0; oy += e.offsetY - py0; px0 = e.offsetX; py0 = e.offsetY;
  } else {
    const n = nodeAt(e.offsetX, e.offsetY);
    hover = n;
    const tip = document.getElementById('tip');
    if (n) {
      tip.style.display = 'block';
      tip.style.left = Math.min(e.offsetX + 14, W - 330) + 'px';
      tip.style.top = (e.offsetY + 14) + 'px';
      tip.innerHTML = '<b>' + esc(n.title) + '</b><span class="t">' + esc(n.type) +
                      '</span><div class="d">' + esc(n.desc) + '</div>';
    } else tip.style.display = 'none';
  }
});
canvas.addEventListener('pointerup', e => {
  if (drag && Math.hypot(e.offsetX - px0, e.offsetY - py0) < 4) select(drag);
  if (panning && Math.hypot(e.offsetX - px0, e.offsetY - py0) < 4) select(null);
  drag = null; panning = false; canvas.classList.remove('dragging');
});
canvas.addEventListener('wheel', e => {
  e.preventDefault();
  const k = Math.exp(-e.deltaY * 0.0015), s = Math.min(4, Math.max(0.2, scale * k));
  ox = e.offsetX - (e.offsetX - ox) * (s / scale);
  oy = e.offsetY - (e.offsetY - oy) * (s / scale);
  scale = s;
}, { passive: false });

// --- legend / list / search --------------------------------------------------
const typeCounts = {};
nodes.forEach(n => typeCounts[n.type] = (typeCounts[n.type] || 0) + 1);
const allTypes = [...TYPE_ORDER.filter(t => typeCounts[t]),
                  ...Object.keys(typeCounts).filter(t => !TYPE_ORDER.includes(t)).sort()];
function buildLegend() {
  document.getElementById('legend').innerHTML = allTypes.map(t =>
    '<div class="leg' + (hidden.has(t) ? ' off' : '') + '" data-t="' + esc(t) + '">' +
    '<span class="dot" style="background:' + colorOf(t) + '"></span>' + esc(t) +
    '<span class="n">' + typeCounts[t] + '</span></div>').join('');
}
buildLegend();
document.getElementById('counts').textContent =
  nodes.length + ' concepts · ' + edges.length + ' links';
document.getElementById('legend').addEventListener('click', e => {
  const el = e.target.closest('.leg'); if (!el) return;
  const t = el.dataset.t;
  hidden.has(t) ? hidden.delete(t) : hidden.add(t);
  buildLegend(); buildList(); reheat();
});
function buildList() {
  const vis = nodes.filter(visible).sort((a, b) => a.title.localeCompare(b.title));
  document.getElementById('list').innerHTML = vis.map(n =>
    '<a href="#" data-id="' + esc(n.id) + '">' + esc(n.title) + '</a>').join('');
}
buildList();
document.getElementById('list').addEventListener('click', e => {
  const a = e.target.closest('a'); if (!a) return;
  e.preventDefault(); select(byId[a.dataset.id], true);
});
document.getElementById('q').addEventListener('input', e => {
  const q = e.target.value.trim().toLowerCase();
  match = q ? (n => (n.title + ' ' + n.id + ' ' + n.desc + ' ' + n.type).toLowerCase().includes(q)) : null;
  buildList(); reheat();
});

// --- detail panel -------------------------------------------------------------
function esc(s) { return String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])); }
function resolveMd(fromId, target) {
  if (/^[a-z][a-z0-9+.-]*:/.test(target) || target.startsWith('#')) return null;
  const base = fromId.split('/').slice(0, -1);
  for (const part of target.split('#')[0].split('/')) {
    if (part === '' || part === '.') continue;
    if (part === '..') base.pop(); else base.push(part);
  }
  const p = base.join('/');
  return p.endsWith('.md') && byId[p.slice(0, -3)] ? p.slice(0, -3) : null;
}
function mdToHtml(md, fromId) {
  const out = []; let inFence = false, fence = [], list = null;
  const flushList = () => { if (list) { out.push('<ul>' + list.join('') + '</ul>'); list = null; } };
  const inline = s => esc(s)
    .replace(/\\\`([^\\\`]+)\\\`/g, '<code>$1</code>')
    .replace(/\\*\\*([^*]+)\\*\\*/g, '<b>$1</b>')
    .replace(/(?<!!)\\[([^\\]]*)\\]\\(([^)\\s]+)\\)/g, (m, txt, href) => {
      const nid = resolveMd(fromId, href);
      if (nid) return '<a href="#" data-node="' + esc(nid) + '">' + txt + '</a>';
      if (/^https?:/.test(href)) return '<a href="' + esc(href) + '" target="_blank" rel="noopener">' + txt + '</a>';
      return '<a title="' + esc(href) + '">' + txt + '</a>';
    });
  for (const line of md.split('\\n')) {
    if (/^(\\\`\\\`\\\`|~~~)/.test(line)) {
      if (inFence) { out.push('<pre><code>' + esc(fence.join('\\n')) + '</code></pre>'); fence = []; }
      inFence = !inFence; continue;
    }
    if (inFence) { fence.push(line); continue; }
    const h = line.match(/^(#{1,4})\\s+(.*)/);
    if (h) { flushList(); out.push('<h3>' + inline(h[2]) + '</h3>'); continue; }
    const li = line.match(/^\\s*[-*]\\s+(.*)/);
    if (li) { (list = list || []).push('<li>' + inline(li[1]) + '</li>'); continue; }
    if (!line.trim()) { flushList(); continue; }
    flushList(); out.push('<p>' + inline(line) + '</p>');
  }
  flushList();
  if (inFence) out.push('<pre><code>' + esc(fence.join('\\n')) + '</code></pre>');
  return out.join('');
}
function select(n, center) {
  selected = n;
  const panel = document.getElementById('panel');
  if (!n) { panel.classList.remove('open'); return; }
  if (center) { ox = W / 2 - n.x * scale; oy = H / 2 - n.y * scale; }
  const fmRows = Object.entries(n.fm).map(([k, v]) =>
    '<tr><td>' + esc(k) + '</td><td>' + esc(Array.isArray(v) ? v.join(', ') : v) + '</td></tr>').join('');
  const out = edges.filter(e => e.s === n.id).map(e => e.t);
  const inn = inLinks[n.id] || [];
  const linkList = ids => ids.map(i =>
    '<a href="#" data-node="' + esc(i) + '">' + esc(byId[i].title) + '</a>').join(' · ') || '<span style="color:var(--ink-muted)">none</span>';
  panel.innerHTML =
    '<button class="close" aria-label="Close">×</button>' +
    '<h2>' + esc(n.title) + '</h2>' +
    '<span class="chip"><span class="dot" style="background:' + colorOf(n.type) + '"></span>' + esc(n.type) + '</span>' +
    '<table class="fm">' + fmRows + '</table>' +
    '<div id="body-md">' + mdToHtml(n.body, n.id) + '</div>' +
    '<div class="backlinks"><h4>Links to</h4>' + linkList(out) + '</div>' +
    '<div class="backlinks"><h4>Cited by</h4>' + linkList(inn) + '</div>';
  panel.classList.add('open');
}
document.getElementById('panel').addEventListener('click', e => {
  if (e.target.closest('.close')) { select(null); return; }
  const a = e.target.closest('a[data-node]');
  if (a) { e.preventDefault(); select(byId[a.dataset.node], true); }
});
</script>
</body>
</html>
`;

const out = join(bundle, "viz.html");
writeFileSync(out, html);
console.log(`viz: ${nodes.length} nodes, ${dedupedEdges.length} edges -> ${out}`);
