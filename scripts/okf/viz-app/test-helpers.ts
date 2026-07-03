// Shared fixtures for the viz-app test suite. Not a test file itself —
// `bun test` only picks up *.test.ts — and never bundled (only test files
// import it).
import type { ConceptNode } from "./data";
import type { SceneApi } from "./scene";

export const node = (id: string, type: string, title = id, extra: Partial<ConceptNode> = {}): ConceptNode => ({
  id,
  type,
  title,
  desc: "",
  fm: {},
  body: "",
  x: 0,
  y: 0,
  z: 0,
  ...extra,
});

/** Recording stand-in for the WebGL GraphScene. */
export interface StubScene extends SceneApi {
  calls: [string, ...unknown[]][];
  dimFn: ((i: number) => boolean) | null;
}

export const makeStub = (): StubScene => {
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
