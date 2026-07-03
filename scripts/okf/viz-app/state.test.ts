import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { buildModel, type ConceptNode } from "./data";
import { createVizState } from "./state.svelte";

const node = (id: string, type: string, title: string, desc = ""): ConceptNode => ({
  id,
  type,
  title,
  desc,
  fm: {},
  body: "",
  x: 0,
  y: 0,
  z: 0,
});

const model = () =>
  buildModel({
    nodes: [
      node("a", "Decision", "Alpha", "first decision"),
      node("b", "Pattern", "Beta"),
      node("c", "Decision", "Gamma"),
    ],
    edges: [{ s: "a", t: "b" }],
    files: { "scripts/okf/viz.ts": { html: "", lines: 1, size: 10, date: "", lang: "ts", refs: ["a"] } },
  });

beforeEach(() => localStorage.clear());

describe("selection", () => {
  test("selectConcept sets sel, fly, scene index", () => {
    const s = createVizState(model());
    s.selectConcept("a");
    expect(s.sel).toEqual({ kind: "concept", id: "a" });
    expect(s.fly).toBe(true);
    expect(s.selectedConcept?.title).toBe("Alpha");
    expect(s.sceneSelectedIndex).toBe(0);
  });

  test("unknown ids are ignored", () => {
    const s = createVizState(model());
    s.selectConcept("nope");
    s.selectFile("nope.ts");
    expect(s.sel).toEqual({ kind: "none" });
  });

  test("file view keeps scene emphasis and back-link on last concept", () => {
    const s = createVizState(model());
    s.selectConcept("a");
    s.selectFile("scripts/okf/viz.ts");
    expect(s.sel).toEqual({ kind: "file", path: "scripts/okf/viz.ts" });
    expect(s.selectedConcept).toBeNull();
    expect(s.backConcept?.id).toBe("a");
    expect(s.sceneSelectedIndex).toBe(0);
  });

  test("clearSelection resets everything", () => {
    const s = createVizState(model());
    s.selectConcept("a");
    s.clearSelection();
    expect(s.sel).toEqual({ kind: "none" });
    expect(s.backConcept).toBeNull();
    expect(s.sceneSelectedIndex).toBeNull();
  });
});

describe("filtering", () => {
  test("toggleType hides and shows", () => {
    const s = createVizState(model());
    s.toggleType("Decision");
    expect(s.visible(s.model.nodes[0]!)).toBe(false);
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["b"]);
    s.toggleType("Decision");
    expect(s.visibleSorted).toHaveLength(3);
  });

  test("query matches title/id/desc/type, case-insensitive", () => {
    const s = createVizState(model());
    s.query = "ALPHA";
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["a"]);
    s.query = "pattern";
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["b"]);
    s.query = "first decision";
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["a"]);
    s.query = "";
    expect(s.visibleSorted).toHaveLength(3);
  });

  test("visibleSorted sorts by title", () => {
    const s = createVizState(model());
    expect(s.visibleSorted.map((n) => n.title)).toEqual(["Alpha", "Beta", "Gamma"]);
  });
});

describe("panel width", () => {
  test("default clamp: min(460, 85%) capped at 92%", () => {
    const s = createVizState(model());
    expect(s.panelPx(1000)).toBe(460);
    expect(s.panelPx(400)).toBe(340);
  });

  test("explicit width respected up to 92% of stage", () => {
    const s = createVizState(model());
    s.setPanelW(800);
    expect(s.panelPx(1000)).toBe(800);
    s.setPanelW(2000);
    expect(s.panelPx(1000)).toBe(920);
  });

  test("persistPanelW round-trips through localStorage", () => {
    const s = createVizState(model());
    s.setPanelW(555);
    s.persistPanelW();
    expect(localStorage.getItem("okfVizPanelW")).toBe("555");
    const s2 = createVizState(model());
    expect(s2.panelW).toBe(555);
  });
});

describe("palette", () => {
  test("colorOf falls back to muted Other without CSS vars", () => {
    const s = createVizState(model());
    expect(s.colorOf("Unknown Type")).toBe("#898781");
    expect(s.colorOf("Decision")).toBe("#898781"); // happy-dom has no :root vars
  });
});

describe("theme slider", () => {
  const rootVar = (k: string) => document.documentElement.style.getPropertyValue(k);
  beforeEach(() => document.documentElement.removeAttribute("style"));
  afterEach(() => {
    localStorage.removeItem("okfVizTheme");
    document.documentElement.removeAttribute("style");
  });

  test("defaults to light (index 0) with no stored choice and light scheme", () => {
    const s = createVizState(model());
    expect(s.themeIndex).toBe(0);
    expect(rootVar("--page")).toBe(""); // no inline override until a pick
  });

  test("setTheme applies inline vars, persists, and bumps the palette", () => {
    const s = createVizState(model());
    const before = s.paletteVersion;
    s.setTheme(1);
    expect(s.themeIndex).toBe(1);
    expect(rootVar("--page")).toBe("#8b8b86"); // medium
    expect(localStorage.getItem("okfVizTheme")).toBe("1");
    expect(s.paletteVersion).toBe(before + 1);
    s.setTheme(99); // out of range ignored
    expect(s.themeIndex).toBe(1);
  });

  test("stored choice restores and applies on startup", () => {
    localStorage.setItem("okfVizTheme", "3");
    const s = createVizState(model());
    expect(s.themeIndex).toBe(3);
    expect(rootVar("--page")).toBe("#0d0d0d"); // black
  });

  test("OS scheme flip moves the slider only while unpicked", () => {
    const s = createVizState(model());
    s.systemSchemeChanged(true);
    expect(s.themeIndex).toBe(3);
    s.setTheme(1);
    s.systemSchemeChanged(false);
    expect(s.themeIndex).toBe(1); // explicit pick wins
  });
});
