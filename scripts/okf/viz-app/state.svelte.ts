// Reactive core of the viewer (Svelte 5 runes). Components bind to this;
// Stage.svelte bridges it into the imperative GraphScene.
import { SvelteSet } from "svelte/reactivity";
import { TYPE_ORDER, type ConceptNode, type VizModel } from "./data";
import type { Selection } from "./hash";
import { applyThemeVars, defaultThemeIndex, THEMES } from "./themes";

export interface Hover {
  i: number;
  x: number;
  y: number;
}

const OTHER = "#898781";
const PANEL_KEY = "okfVizPanelW";
const THEME_KEY = "okfVizTheme";

const cssVar = (k: string) =>
  typeof document === "undefined" ? "" : getComputedStyle(document.documentElement).getPropertyValue(k).trim();

export function createVizState(model: VizModel) {
  let sel = $state<Selection>({ kind: "none" });
  let fly = $state(true);
  // Bumped on every concept select/clear so the scene bridge re-runs even when
  // the same node is re-selected (legacy re-flies the camera in that case).
  let selSeq = $state(0);
  // Scene emphasis + file-view back-link keep pointing at the last concept
  // even while a file is shown (legacy behavior).
  let lastConceptId = $state<string | null>(null);
  const hidden = new SvelteSet<string>();
  let query = $state("");
  let hover = $state<Hover | null>(null);
  let panelW = $state(typeof localStorage === "undefined" ? 0 : +(localStorage.getItem(PANEL_KEY) || 0));
  let dark = $state(typeof matchMedia === "undefined" ? false : matchMedia("(prefers-color-scheme: dark)").matches);
  let paletteVersion = $state(0);

  // Theme slider: an explicit pick is persisted and overrides the OS scheme
  // (inline :root vars beat the media block); otherwise follow the scheme.
  const storedTheme = typeof localStorage === "undefined" ? null : localStorage.getItem(THEME_KEY);
  let themeIndex = $state(
    storedTheme != null && +storedTheme >= 0 && +storedTheme < THEMES.length
      ? +storedTheme
      : defaultThemeIndex(dark),
  );
  if (storedTheme != null) applyThemeVars(themeIndex);

  const match = $derived.by(() => {
    const q = query.trim().toLowerCase();
    return q ? (n: ConceptNode) => `${n.title} ${n.id} ${n.desc} ${n.type}`.toLowerCase().includes(q) : null;
  });

  const computeSlots = () => {
    const m: Record<string, string> = {};
    TYPE_ORDER.forEach((t, i) => (m[t] = cssVar("--s" + (i + 1))));
    m["__other"] = cssVar("--s-other"); // overflow types, theme-tuned
    return m;
  };
  // Re-read on repaint() — the CSS custom properties flip with the color scheme.
  let slots = $state(computeSlots());

  const repaintNow = () => {
    slots = computeSlots();
    paletteVersion++;
  };

  const visible = (n: ConceptNode) => !hidden.has(n.type) && (!match || match(n));
  const visibleSorted = $derived(model.nodes.filter(visible).sort((a, b) => a.title.localeCompare(b.title)));

  const selectedConcept = $derived(sel.kind === "concept" ? (model.byId[sel.id] ?? null) : null);
  const backConcept = $derived(lastConceptId ? (model.byId[lastConceptId] ?? null) : null);
  const sceneSelectedIndex = $derived.by(() => {
    const id = sel.kind === "concept" ? sel.id : sel.kind === "file" ? lastConceptId : null;
    return id != null ? (model.indexOf.get(id) ?? null) : null;
  });

  return {
    model,

    get sel() {
      return sel;
    },
    get fly() {
      return fly;
    },
    get selSeq() {
      return selSeq;
    },
    get selectedConcept() {
      return selectedConcept;
    },
    get backConcept() {
      return backConcept;
    },
    get sceneSelectedIndex() {
      return sceneSelectedIndex;
    },
    selectConcept(id: string, flyTo = true) {
      if (!model.byId[id]) return;
      sel = { kind: "concept", id };
      lastConceptId = id;
      fly = flyTo;
      selSeq++;
    },
    selectFile(path: string) {
      if (!model.files[path]) return;
      sel = { kind: "file", path };
    },
    clearSelection() {
      sel = { kind: "none" };
      lastConceptId = null;
      fly = false;
      selSeq++;
    },

    hidden,
    toggleType(t: string) {
      hidden.has(t) ? hidden.delete(t) : hidden.add(t);
    },

    get query() {
      return query;
    },
    set query(v: string) {
      query = v;
    },
    get match() {
      return match;
    },
    visible,
    get visibleSorted() {
      return visibleSorted;
    },

    get hover() {
      return hover;
    },
    set hover(v: Hover | null) {
      hover = v;
    },

    get panelW() {
      return panelW;
    },
    setPanelW(px: number) {
      panelW = px;
    },
    persistPanelW() {
      if (panelW && typeof localStorage !== "undefined") localStorage.setItem(PANEL_KEY, String(panelW));
    },
    /** Effective panel width in px for a given stage width (legacy clamp). */
    panelPx(stageWidth: number) {
      const max = stageWidth * 0.92;
      return Math.min(panelW || Math.min(460, stageWidth * 0.85), max);
    },

    get dark() {
      return dark;
    },
    set dark(v: boolean) {
      dark = v;
    },
    get paletteVersion() {
      return paletteVersion;
    },
    repaint: repaintNow,
    get themeIndex() {
      return themeIndex;
    },
    setTheme(i: number) {
      if (i < 0 || i >= THEMES.length) return;
      themeIndex = i;
      applyThemeVars(i);
      if (typeof localStorage !== "undefined") localStorage.setItem(THEME_KEY, String(i));
      repaintNow();
    },
    /** OS scheme flip: move the slider only while the user hasn't picked. */
    systemSchemeChanged(isDark: boolean) {
      dark = isDark;
      if (typeof localStorage === "undefined" || localStorage.getItem(THEME_KEY) == null) {
        themeIndex = defaultThemeIndex(isDark);
      }
      repaintNow();
    },
    colorOf(t: string) {
      return slots[t] || slots["__other"] || OTHER;
    },
    theme() {
      return { bg: cssVar("--page"), labelInk: cssVar("--ink-2"), labelStroke: cssVar("--surface-1") };
    },
  };
}

export type VizState = ReturnType<typeof createVizState>;
