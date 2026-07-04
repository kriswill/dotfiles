// Reactive core of the viewer (Svelte 5 runes). Components bind to this;
// Stage.svelte bridges it into the imperative GraphScene.
import { SvelteSet } from "svelte/reactivity";
import { nameColor } from "./color";
import { conceptTree, neighborsWithin, treeIds, type ConceptNode, type ConceptTree, type VizModel } from "./data";
import type { Selection } from "./hash";
import { applyThemeVars, defaultThemeIndex, THEMES } from "./themes";

export interface Hover {
  i: number;
  x: number;
  y: number;
}

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
  // Scene emphasis + file/dir-view back-link keep pointing at the last concept
  // even while a file or directory is shown (legacy behavior).
  let lastConceptId = $state<string | null>(null);
  const hidden = new SvelteSet<string>();
  let query = $state("");
  let isolateDepth = $state<0 | 1 | 2>(0);
  // "all" or one of model.platforms (the config's platform.values).
  let platform = $state("all");
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
    if (!q) return null;
    return (n: ConceptNode) => {
      const tags = Array.isArray(n.fm.tags) ? n.fm.tags.join(" ") : "";
      return `${n.title} ${n.id} ${n.desc} ${n.type} ${tags}`.toLowerCase().includes(q);
    };
  });

  const computeSlots = () => {
    const m: Record<string, string> = {};
    // Slot N = --sN; the themes ship 12 slots, overflow types fall through to
    // nameColor in colorOf (missing CSS var -> "" -> falsy).
    model.cfg.taxonomy.types.slice(0, 12).forEach((t, i) => (m[t] = cssVar("--s" + (i + 1))));
    return m;
  };
  // Re-read on repaint() — the CSS custom properties flip with the color scheme.
  let slots = $state(computeSlots());

  const repaintNow = () => {
    slots = computeSlots();
    paletteVersion++;
  };

  /** Isolate a set of types; solo the same set again to restore all. */
  const soloTypes = (types: string[]) => {
    const want = new Set(types);
    const alone = model.allTypes.every((u) => (want.has(u) ? !hidden.has(u) : hidden.has(u)));
    hidden.clear();
    if (!alone) for (const u of model.allTypes) if (!want.has(u)) hidden.add(u);
  };

  const platformOk = (n: ConceptNode) => {
    if (platform === "all") return true;
    const p = model.platformById[n.id];
    return p === "both" || p === "neutral" || p === platform;
  };
  const visible = (n: ConceptNode) =>
    !hidden.has(n.type) && (!match || match(n)) && (!neighborIds || neighborIds.has(n.id)) && platformOk(n);
  const visibleSorted = $derived(model.nodes.filter(visible).sort((a, b) => a.title.localeCompare(b.title)));
  // Search hits suppressed by type toggles, surfaced in the list so a hidden
  // type never silently swallows a match.
  const hiddenMatchCount = $derived(match ? model.nodes.filter((n) => hidden.has(n.type) && match(n)).length : 0);

  const selectedConcept = $derived(sel.kind === "concept" ? (model.byId[sel.id] ?? null) : null);
  const backConcept = $derived(lastConceptId ? (model.byId[lastConceptId] ?? null) : null);
  const focusedConcept = $derived(selectedConcept ?? backConcept);
  // Anchored on selectedConcept strictly (not focusedConcept): isolation is
  // only meaningful while a concept, not a file/dir view, is the selection.
  const neighborIds = $derived.by(() =>
    isolateDepth && selectedConcept ? neighborsWithin(model, selectedConcept.id, isolateDepth) : null,
  );
  const sceneSelectedIndex = $derived(focusedConcept ? (model.indexOf.get(focusedConcept.id) ?? null) : null);
  // Pinned sidebar listing: the focused concept at the top with linked nodes
  // nested beneath by hop distance (full isolation depth while isolation is
  // active; direct links only otherwise), then the remaining visible nodes
  // flat. Anchored on focusedConcept — the node the list highlight/scroll
  // already track — so the pin survives file/dir views, where neighborIds
  // suspends and the layout falls back to depth-1 + rest. The anchor itself
  // is always pinned even when it fails the filters, so the list can show
  // one more row than the "N of M" count.
  const listing = $derived.by(() => {
    if (!focusedConcept) return { tree: null as ConceptTree | null, rest: visibleSorted };
    // neighborIds non-null implies isolateDepth is 1 | 2 (gate at its definition).
    const tree = conceptTree(model, focusedConcept.id, neighborIds ? (isolateDepth as 1 | 2) : 1, visible);
    if (!tree) return { tree: null, rest: visibleSorted };
    const ids = treeIds(tree);
    return { tree, rest: visibleSorted.filter((n) => !ids.has(n.id)) };
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
    get focusedConcept() {
      return focusedConcept;
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
    selectDir(path: string) {
      if (!model.dirs[path]) return;
      sel = { kind: "dir", path };
    },
    clearSelection() {
      sel = { kind: "none" };
      lastConceptId = null;
      fly = false;
      selSeq++;
      isolateDepth = 0;
    },

    hidden,
    toggleType(t: string) {
      hidden.has(t) ? hidden.delete(t) : hidden.add(t);
    },
    showAllTypes() {
      hidden.clear();
    },
    hideAllTypes() {
      for (const t of model.allTypes) hidden.add(t);
    },
    soloType(t: string) {
      soloTypes([t]);
    },
    toggleGroup(g: string) {
      const types = model.groupTypes[g] ?? [];
      const allHidden = types.length > 0 && types.every((t) => hidden.has(t));
      for (const t of types) allHidden ? hidden.delete(t) : hidden.add(t);
    },
    soloGroup(g: string) {
      soloTypes(model.groupTypes[g] ?? []);
    },
    /** Replace the whole filter state (hash navigation). */
    setFilters(hiddenTypes: string[], q: string, isolate: 0 | 1 | 2 = 0, plat = "all") {
      const want = new Set(hiddenTypes);
      for (const t of [...hidden]) if (!want.has(t)) hidden.delete(t);
      for (const t of want) hidden.add(t);
      query = q;
      isolateDepth = isolate;
      platform = model.platforms.includes(plat) ? plat : "all";
    },
    get hiddenMatchCount() {
      return hiddenMatchCount;
    },

    get isolateDepth() {
      return isolateDepth;
    },
    setIsolate(depth: 0 | 1 | 2) {
      isolateDepth = depth === 1 || depth === 2 ? depth : 0;
    },
    get neighborIds() {
      return neighborIds;
    },

    get platform() {
      return platform;
    },
    setPlatform(p: string) {
      platform = model.platforms.includes(p) ? p : "all";
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
    get listing() {
      return listing;
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
      // Curated slot if registered in cfg.taxonomy.types; otherwise a stable
      // generated color at the theme's lightness/chroma.
      return slots[t] || nameColor(t, THEMES[themeIndex]!.gen);
    },
    theme() {
      return { bg: cssVar("--page"), labelInk: cssVar("--ink-2"), labelStroke: cssVar("--surface-1") };
    },
  };
}

export type VizState = ReturnType<typeof createVizState>;
