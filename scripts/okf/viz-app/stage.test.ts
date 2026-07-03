// Stage bridge tests: reactive state changes must reach the imperative
// GraphScene API. A recording stub replaces the WebGL scene.
import { afterEach, describe, expect, test } from "bun:test";
import { flushSync, mount, unmount } from "svelte";
import { buildModel, type ConceptNode } from "./data";
import type { SceneApi } from "./scene";
import Stage from "./Stage.svelte";
import { createVizState } from "./state.svelte";

const node = (id: string, type: string, title: string): ConceptNode => ({
  id,
  type,
  title,
  desc: "",
  fm: {},
  body: "",
  x: 0,
  y: 0,
  z: 0,
});

const model = () =>
  buildModel({
    nodes: [node("a", "Decision", "Alpha"), node("b", "Pattern", "Beta")],
    edges: [{ s: "a", t: "b" }],
    files: { "f.ts": { html: "", lines: 1, size: 1, date: "", lang: "ts", refs: [] } },
  });

interface StubScene extends SceneApi {
  calls: [string, ...unknown[]][];
  dimFn: ((i: number) => boolean) | null;
}
const makeStub = (): StubScene => {
  const s: StubScene = {
    calls: [],
    dimFn: null,
    setDim(fn) {
      s.dimFn = fn;
      s.calls.push(["setDim"]);
    },
    setSelected(i, fly) {
      s.calls.push(["setSelected", i, fly]);
    },
    applyTheme() {
      s.calls.push(["applyTheme"]);
    },
    setViewShift(px) {
      s.calls.push(["setViewShift", px]);
    },
    resize() {},
  };
  return s;
};

let cleanup: (() => void) | null = null;
afterEach(() => {
  cleanup?.();
  cleanup = null;
  document.body.innerHTML = "";
});

function mountStage(state = createVizState(model())) {
  const stub = makeStub();
  const app = mount(Stage, {
    target: document.body,
    props: { viz: state, createScene: () => stub },
  });
  cleanup = () => unmount(app);
  flushSync();
  return { stub, state };
}

describe("Stage bridges", () => {
  test("dim bridge re-pushes on query and hidden-type changes", () => {
    const { stub, state } = mountStage();
    const before = stub.calls.filter(([m]) => m === "setDim").length;
    state.query = "alpha";
    flushSync();
    expect(stub.calls.filter(([m]) => m === "setDim").length).toBe(before + 1);
    expect(stub.dimFn!(0)).toBe(false); // Alpha matches
    expect(stub.dimFn!(1)).toBe(true); // Beta dimmed
    state.query = "";
    state.toggleType("Pattern");
    flushSync();
    expect(stub.dimFn!(1)).toBe(true);
    expect(stub.dimFn!(0)).toBe(false);
  });

  test("selection bridge flies to concepts, keeps emphasis in file view, re-fires on reselect", () => {
    const { stub, state } = mountStage();
    state.selectConcept("a");
    flushSync();
    expect(stub.calls.filter(([m]) => m === "setSelected").at(-1)).toEqual(["setSelected", 0, true]);
    stub.calls = [];
    state.selectFile("f.ts");
    flushSync();
    // file view: selection index unchanged → no scene churn
    expect(stub.calls.filter(([m]) => m === "setSelected")).toHaveLength(0);
    state.selectConcept("a"); // reselect same node re-flies (selSeq bump)
    flushSync();
    expect(stub.calls.filter(([m]) => m === "setSelected")).toHaveLength(1);
    state.clearSelection();
    flushSync();
    expect(stub.calls.filter(([m]) => m === "setSelected").at(-1)).toEqual(["setSelected", null, false]);
  });

  test("view shift follows panel open/close and width", () => {
    const { stub, state } = mountStage();
    // happy-dom reports clientWidth 0 — pin a real stage width for the clamp.
    Object.defineProperty(document.getElementById("stage")!, "clientWidth", { value: 1000 });
    const shifts = () => stub.calls.filter(([m]) => m === "setViewShift");
    state.selectConcept("a");
    flushSync();
    expect(shifts().at(-1)![1]).toBe(460); // default: min(460, 85% of stage)
    state.setPanelW(555);
    flushSync();
    expect(shifts().at(-1)![1]).toBe(555);
    state.clearSelection();
    flushSync();
    expect(shifts().at(-1)![1]).toBe(0);
  });

  test("theme bridge reapplies on dark flip and repaint", () => {
    const { stub, state } = mountStage();
    const before = stub.calls.filter(([m]) => m === "applyTheme").length;
    state.dark = !state.dark;
    flushSync();
    expect(stub.calls.filter(([m]) => m === "applyTheme").length).toBe(before + 1);
    state.repaint();
    flushSync();
    expect(stub.calls.filter(([m]) => m === "applyTheme").length).toBe(before + 2);
  });
});
