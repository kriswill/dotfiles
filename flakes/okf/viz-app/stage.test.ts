// Stage bridge tests: reactive state changes must reach the imperative
// GraphScene API. A recording stub replaces the WebGL scene.
import { afterEach, describe, expect, test } from "bun:test";
import { flushSync, mount, unmount } from "svelte";
import { buildModel } from "./data";
import Stage from "./Stage.svelte";
import { createVizState } from "./state.svelte";
import { makeStub, node } from "./test-helpers";

const model = () =>
  buildModel({
    nodes: [node("a", "Decision", "Alpha"), node("b", "Pattern", "Beta")],
    edges: [{ s: "a", t: "b" }],
    files: { "f.ts": { html: "", lines: 1, size: 1, date: "", lang: "ts", refs: [] } },
  });

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

  test("dim bridge re-pushes when a facet selection changes (immutable facetSel replacement)", () => {
    const withFacet = createVizState(
      buildModel({
        nodes: [node("a", "Decision", "Alpha"), node("b", "Pattern", "Beta")],
        edges: [{ s: "a", t: "b" }],
        cfg: { facet: { kind: { types: { Decision: "x", Pattern: "y" } } } },
      }),
    );
    const { stub, state } = mountStage(withFacet);
    const before = stub.calls.filter(([m]) => m === "setDim").length;
    state.setFacet("kind", "x");
    flushSync();
    expect(stub.calls.filter(([m]) => m === "setDim").length).toBe(before + 1);
    expect(stub.dimFn!(0)).toBe(false); // Alpha (Decision -> "x") stays
    expect(stub.dimFn!(1)).toBe(true); // Beta (Pattern -> "y") dimmed
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
    expect(shifts().at(-1)).toEqual(["setViewShift", 260, 460]); // sidebar px, default: min(460, 85% of stage)
    state.setPanelW(555);
    flushSync();
    expect(shifts().at(-1)![2]).toBe(555);
    state.clearSelection();
    flushSync();
    expect(shifts().at(-1)![2]).toBe(0);
  });

  test("view shift and panel width re-clamp on window resize", () => {
    const { stub, state } = mountStage();
    const stage = document.getElementById("stage")!;
    Object.defineProperty(stage, "clientWidth", { value: 1000, configurable: true });
    const shifts = () => stub.calls.filter(([m]) => m === "setViewShift");
    state.selectConcept("a");
    flushSync();
    expect(shifts().at(-1)![2]).toBe(460);
    expect((document.getElementById("panel") as HTMLElement).style.width).toBe("460px");
    Object.defineProperty(stage, "clientWidth", { value: 400, configurable: true });
    window.dispatchEvent(new Event("resize"));
    flushSync();
    expect(shifts().at(-1)![2]).toBe(340); // re-clamped: min(460, 85% of 400)
    expect((document.getElementById("panel") as HTMLElement).style.width).toBe("340px");
  });

  test("theme toggle button hugs the panel's left edge when open", () => {
    const { state } = mountStage();
    const stage = document.getElementById("stage")!;
    Object.defineProperty(stage, "clientWidth", { value: 1000, configurable: true });
    const btn = document.getElementById("theme-toggle") as HTMLButtonElement;
    expect(btn.style.right).toBe("16px");
    state.selectConcept("a");
    flushSync();
    expect(btn.style.right).toBe("476px"); // default panel width (460) + 16
    state.clearSelection();
    flushSync();
    expect(btn.style.right).toBe("16px");
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
