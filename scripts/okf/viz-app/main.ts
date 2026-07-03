// Viewer entry: sidebar (search / type legend / concept list), the Three.js
// scene, tooltip, and the detail panel with markdown bodies and highlighted
// source-file previews. Data + layout are baked in by scripts/okf/viz.ts.

import { createMd, esc } from "./markdown";
import { GraphScene } from "./scene";

interface ConceptNode {
  id: string; type: string; title: string; desc: string;
  fm: Record<string, unknown>; body: string;
  x: number; y: number; z: number;
}

const DATA = JSON.parse(document.getElementById("data")!.textContent!);
const FILES: Record<string, any> = DATA.files || {};
const nodes: ConceptNode[] = DATA.nodes;
const byId: Record<string, ConceptNode> = Object.fromEntries(nodes.map((n) => [n.id, n]));
const indexOf = new Map(nodes.map((n, i) => [n.id, i]));
const edges: { s: string; t: string }[] = DATA.edges.filter((e: any) => byId[e.s] && byId[e.t]);
const edgeIdx: [number, number][] = edges.map((e) => [indexOf.get(e.s)!, indexOf.get(e.t)!]);

const deg: Record<string, number> = {};
const inLinks: Record<string, string[]> = {};
for (const e of edges) {
  deg[e.s] = (deg[e.s] || 0) + 1;
  deg[e.t] = (deg[e.t] || 0) + 1;
  (inLinks[e.t] = inLinks[e.t] || []).push(e.s);
}

const md = createMd({ files: FILES, byId });

/* --- palette ------------------------------------------------------------- */
const css = (k: string) => getComputedStyle(document.documentElement).getPropertyValue(k).trim();
// Fixed slot order (never cycled); overflow types fold into muted "Other".
const TYPE_ORDER = ["Darwin Module", "Nix Package", "Playbook", "Pattern", "Decision", "Host", "Sub-flake", "Flake-parts Module"];
let SLOT: Record<string, string> = {};
const OTHER = "#898781";
function paint() {
  SLOT = {};
  TYPE_ORDER.forEach((t, i) => (SLOT[t] = css("--s" + (i + 1))));
}
paint();
const colorOf = (t: string) => SLOT[t] ?? OTHER;
const theme = () => ({ bg: css("--page"), labelInk: css("--ink-2"), labelStroke: css("--surface-1") });

/* --- scene ----------------------------------------------------------------- */
const stage = document.getElementById("stage")!;
const sceneNodes = nodes.map((n) => ({
  x: n.x, y: n.y, z: n.z,
  r: (3.5 + Math.min(6.5, (deg[n.id] || 0) * 0.8)) * 0.42,
  color: colorOf(n.type),
  title: n.title,
}));

let hidden = new Set<string>();
let match: ((n: ConceptNode) => boolean) | null = null;
const visible = (n: ConceptNode) => !hidden.has(n.type) && (!match || match(n));

const scene = new GraphScene(stage, sceneNodes, edgeIdx, theme(), {
  onHover(i, cx, cy) {
    const tip = document.getElementById("tip")!;
    if (i === null) { tip.style.display = "none"; return; }
    const n = nodes[i];
    const rect = stage.getBoundingClientRect();
    tip.style.display = "block";
    tip.style.left = Math.min(cx - rect.left + 14, rect.width - 330) + "px";
    tip.style.top = cy - rect.top + 14 + "px";
    tip.innerHTML = `<b>${esc(n.title)}</b><span class="t">${esc(n.type)}</span><div class="d">${esc(n.desc)}</div>`;
  },
  onSelect(i) { select(i === null ? null : nodes[i], true); },
});
const applyDim = () => scene.setDim((i) => !visible(nodes[i]));

matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
  paint();
  sceneNodes.forEach((sn, i) => (sn.color = colorOf(nodes[i].type)));
  scene.applyTheme(theme());
  buildLegend();
});

/* --- sidebar ---------------------------------------------------------------- */
const typeCounts: Record<string, number> = {};
nodes.forEach((n) => (typeCounts[n.type] = (typeCounts[n.type] || 0) + 1));
const allTypes = [
  ...TYPE_ORDER.filter((t) => typeCounts[t]),
  ...Object.keys(typeCounts).filter((t) => !TYPE_ORDER.includes(t)).sort(),
];
function buildLegend() {
  document.getElementById("legend")!.innerHTML = allTypes
    .map(
      (t) =>
        `<div class="leg${hidden.has(t) ? " off" : ""}" data-t="${esc(t)}">` +
        `<span class="dot" style="background:${colorOf(t)}"></span>${esc(t)}` +
        `<span class="n">${typeCounts[t]}</span></div>`,
    )
    .join("");
}
buildLegend();
document.getElementById("counts")!.textContent = `${nodes.length} concepts · ${edges.length} links`;
document.getElementById("legend")!.addEventListener("click", (e) => {
  const el = (e.target as Element).closest(".leg") as HTMLElement | null;
  if (!el) return;
  const t = el.dataset.t!;
  hidden.has(t) ? hidden.delete(t) : hidden.add(t);
  buildLegend();
  buildList();
  applyDim();
});
function buildList() {
  const vis = nodes.filter(visible).sort((a, b) => a.title.localeCompare(b.title));
  document.getElementById("list")!.innerHTML = vis
    .map((n) => `<a href="#" data-id="${esc(n.id)}">${esc(n.title)}</a>`)
    .join("");
}
buildList();
document.getElementById("list")!.addEventListener("click", (e) => {
  const a = (e.target as Element).closest("a") as HTMLAnchorElement | null;
  if (!a) return;
  e.preventDefault();
  select(byId[a.dataset.id!], true);
});
document.getElementById("q")!.addEventListener("input", (e) => {
  const q = (e.target as HTMLInputElement).value.trim().toLowerCase();
  match = q ? (n) => `${n.title} ${n.id} ${n.desc} ${n.type}`.toLowerCase().includes(q) : null;
  buildList();
  applyDim();
});

/* --- detail panel -------------------------------------------------------------- */
const panel = document.getElementById("panel")!;
let selected: ConceptNode | null = null;

function select(n: ConceptNode | null, fly = false) {
  selected = n;
  scene.setSelected(n ? indexOf.get(n.id)! : null, fly);
  updateHash(n ? "c/" + n.id : "");
  if (!n) {
    panel.classList.remove("open");
    scene.setViewShift(0);
    return;
  }
  scene.setViewShift(panelPx());
  const fmRows = Object.entries(n.fm)
    .map(([k, v]) => {
      let val = esc(Array.isArray(v) ? v.join(", ") : v);
      if (k === "resource" && FILES[v as string]) val = `<a href="#" data-file="${esc(v)}">${val}</a>`;
      else if (k === "description") val = md.autolinkPaths(val);
      return `<tr><td>${esc(k)}</td><td>${val}</td></tr>`;
    })
    .join("");
  const out = edges.filter((e) => e.s === n.id).map((e) => e.t);
  const inn = inLinks[n.id] || [];
  const linkList = (ids: string[]) =>
    ids.map((i) => `<a href="#" data-node="${esc(i)}">${esc(byId[i].title)}</a>`).join(" · ") ||
    '<span style="color:var(--ink-muted)">none</span>';
  panel.style.width = panelWidth();
  panel.innerHTML =
    '<div class="resizer"></div>' +
    '<button class="close" aria-label="Close">×</button>' +
    `<h2>${esc(n.title)}</h2>` +
    `<span class="chip"><span class="dot" style="background:${colorOf(n.type)}"></span>${esc(n.type)}</span>` +
    `<table class="fm">${fmRows}</table>` +
    `<div id="body-md">${md.mdToHtml(n.body, n.id)}</div>` +
    `<div class="backlinks"><h4>Links to</h4>${linkList(out)}</div>` +
    `<div class="backlinks"><h4>Cited by</h4>${linkList(inn)}</div>`;
  panel.classList.add("open");
  panel.scrollTop = 0;
}

function selectFile(path: string) {
  const f = FILES[path];
  if (!f) return;
  updateHash("f/" + path);
  scene.setViewShift(panelPx());
  const back = selected
    ? `<a href="#" class="back" data-node="${esc(selected.id)}">← ${esc(selected.title)}</a>`
    : "";
  const meta = [
    ["path", esc(path)], ["language", esc(f.lang)], ["lines", f.lines],
    ["size", (f.size / 1024).toFixed(1) + " KB"], ["last commit", esc(f.date)],
  ]
    .map(([k, v]) => `<tr><td>${k}</td><td>${v}</td></tr>`)
    .join("");
  const refs =
    f.refs
      .filter((i: string) => byId[i])
      .map((i: string) => `<a href="#" data-node="${esc(i)}">${esc(byId[i].title)}</a>`)
      .join(" · ") || '<span style="color:var(--ink-muted)">none</span>';
  panel.style.width = panelWidth();
  panel.innerHTML =
    '<div class="resizer"></div>' +
    '<button class="close" aria-label="Close">×</button>' + back +
    `<h2>${esc(path.split("/").pop())}</h2>` +
    `<span class="chip"><span class="dot" style="background:var(--ink-muted)"></span>${esc(f.lang)}</span>` +
    `<table class="fm">${meta}</table>` +
    `<div class="backlinks" style="border-top:0;margin-top:0;padding-top:0"><h4>Referenced by</h4>${refs}</div>` +
    `<pre class="src">${f.html}</pre>`;
  panel.classList.add("open");
  panel.scrollTop = 0;
}

panel.addEventListener("click", (e) => {
  const t = e.target as Element;
  if (t.closest(".close")) { select(null); return; }
  const af = t.closest("a[data-file]") as HTMLElement | null;
  if (af) { e.preventDefault(); selectFile(af.dataset.file!); return; }
  const a = t.closest("a[data-node]") as HTMLElement | null;
  if (a) { e.preventDefault(); select(byId[a.dataset.node!], true); }
});

/* --- panel resize (drag the left edge; width persists) -------------------------- */
let panelW = +(localStorage.getItem("okfVizPanelW") || 0);
function panelPx() {
  const max = stage.clientWidth * 0.92;
  return Math.min(panelW || Math.min(460, stage.clientWidth * 0.85), max);
}
function panelWidth() {
  return panelPx() + "px";
}
{
  let resizing = false;
  panel.addEventListener("pointerdown", (e) => {
    const r = (e.target as Element).closest(".resizer");
    if (!r) return;
    e.preventDefault();
    resizing = true;
    r.classList.add("active");
    panel.setPointerCapture(e.pointerId);
  });
  panel.addEventListener("pointermove", (e) => {
    if (!resizing) return;
    const rect = stage.getBoundingClientRect();
    panelW = Math.round(Math.min(Math.max(300, rect.right - e.clientX), rect.width * 0.92));
    panel.style.width = panelW + "px";
    scene.setViewShift(panelW);
  });
  panel.addEventListener("pointerup", () => {
    if (!resizing) return;
    resizing = false;
    panel.querySelector(".resizer")?.classList.remove("active");
    if (panelW) localStorage.setItem("okfVizPanelW", String(panelW));
  });
}

/* --- URL state (hash) — selections survive reload and back/forward -------------- */
let currentState: string | null = null;
function updateHash(h: string) {
  if (currentState === h) return;
  currentState = h;
  if (location.hash.slice(1) !== h) {
    if (h) location.hash = h;
    else {
      try { history.pushState(null, "", location.pathname + location.search); }
      catch { location.hash = ""; }
    }
  }
}
function applyHash() {
  const h = decodeURIComponent(location.hash.slice(1));
  if (h === currentState) return;
  currentState = h;
  if (h.startsWith("c/") && byId[h.slice(2)]) select(byId[h.slice(2)], true);
  else if (h.startsWith("f/") && FILES[h.slice(2)]) selectFile(h.slice(2));
  else select(null);
}
addEventListener("hashchange", applyHash);
addEventListener("popstate", applyHash);
applyHash();

// Debug/scripting hook (also used by automated visual checks).
(window as any).__okf = { select: (id: string, fly = true) => select(byId[id] ?? null, fly), selectFile, scene, nodes };
