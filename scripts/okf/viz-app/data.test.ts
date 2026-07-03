import { describe, expect, test } from "bun:test";
import { buildModel } from "./data";
import { node } from "./test-helpers";

const raw = {
  nodes: [node("a", "Decision", "Alpha"), node("b", "Zeta Type", "Beta"), node("c", "Darwin Module", "Gamma")],
  edges: [
    { s: "a", t: "b" },
    { s: "c", t: "b" },
    { s: "a", t: "ghost" }, // dangling — must be dropped
  ],
  files: { "scripts/okf/viz.ts": { html: "", lines: 1, size: 10, date: "", lang: "ts", refs: [] } },
};

describe("buildModel", () => {
  const m = buildModel(raw);

  test("drops edges with missing endpoints", () => {
    expect(m.edges).toHaveLength(2);
    expect(m.edgeIdx).toEqual([
      [0, 1],
      [2, 1],
    ]);
  });

  test("degree and inbound links", () => {
    expect(m.deg).toEqual({ a: 1, b: 2, c: 1 });
    expect(m.inLinks).toEqual({ b: ["a", "c"] });
  });

  test("type counts and TYPE_ORDER-first ordering with alpha overflow", () => {
    expect(m.typeCounts).toEqual({ Decision: 1, "Zeta Type": 1, "Darwin Module": 1 });
    expect(m.allTypes).toEqual(["Darwin Module", "Decision", "Zeta Type"]);
  });

  test("radius formula matches legacy scene sizing", () => {
    expect(m.radii[0]).toBeCloseTo((3.5 + Math.min(6.5, 1 * 0.8)) * 0.42);
    expect(m.radii[1]).toBeCloseTo((3.5 + Math.min(6.5, 2 * 0.8)) * 0.42);
  });

  test("byId and indexOf agree with node order", () => {
    expect(m.byId["b"]!.title).toBe("Beta");
    expect(m.indexOf.get("c")).toBe(2);
  });

  test("missing files/dirs keys default to empty records", () => {
    const empty = buildModel({ nodes: raw.nodes, edges: [] });
    expect(empty.files).toEqual({});
    expect(empty.dirs).toEqual({});
  });
});
