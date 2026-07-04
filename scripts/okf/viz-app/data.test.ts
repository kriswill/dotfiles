import { describe, expect, test } from "bun:test";
import { buildModel, dirOf } from "./data";
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

  test("missing files/dirs/repoUrl/commits keys default to empty", () => {
    const empty = buildModel({ nodes: raw.nodes, edges: [] });
    expect(empty.files).toEqual({});
    expect(empty.dirs).toEqual({});
    expect(empty.repoUrl).toBeNull();
    expect(empty.commits).toEqual({});
  });
});

describe("grouping", () => {
  const groupedRaw = {
    nodes: [
      node("decisions/x", "Decision", "X"),
      node("patterns/y", "Pattern", "Y"),
      node("modules/z", "Darwin Module", "Z"),
      node("hosts/w", "Host", "W"),
      node("packages/p", "Nix Package", "P"),
      node("nvim/n", "Neovim Plugin", "N"),
      node("mystery/m", "Mystery Type", "M"), // unmapped dir -> Other
    ],
    edges: [],
  };
  const gm = buildModel(groupedRaw);

  test("dirOf derives the top-level bundle directory, root docs are '.'", () => {
    expect(dirOf("decisions/x")).toBe("decisions");
    expect(dirOf("okf-profile")).toBe(".");
  });

  test("typeGroup buckets each type by its concepts' directory", () => {
    expect(gm.typeGroup).toEqual({
      Decision: "Knowledge",
      Pattern: "Knowledge",
      "Darwin Module": "System",
      Host: "System",
      "Nix Package": "Packages",
      "Neovim Plugin": "Neovim",
      "Mystery Type": "Other",
    });
  });

  test("groupOrder is GROUP_ORDER filtered to present groups, Other trailing", () => {
    expect(gm.groupOrder).toEqual(["Knowledge", "System", "Packages", "Neovim", "Other"]);
  });

  test("groupTypes lists member types in allTypes (TYPE_ORDER-first) order", () => {
    expect(gm.groupTypes["Knowledge"]).toEqual(["Pattern", "Decision"]);
    expect(gm.groupTypes["System"]).toEqual(["Darwin Module", "Host"]);
    expect(gm.groupTypes["Packages"]).toEqual(["Nix Package"]);
    expect(gm.groupTypes["Neovim"]).toEqual(["Neovim Plugin"]);
    expect(gm.groupTypes["Other"]).toEqual(["Mystery Type"]);
  });

  test("a bundle with no unmapped directory has no Other group", () => {
    const clean = buildModel({ nodes: [node("decisions/x", "Decision", "X")], edges: [] });
    expect(clean.groupOrder).toEqual(["Knowledge"]);
    expect(clean.groupTypes["Other"]).toBeUndefined();
  });

  test("groupOrder filters out missing core groups even when Other is also present", () => {
    const partial = buildModel({
      nodes: [node("decisions/x", "Decision", "X"), node("mystery/m", "Mystery Type", "M")],
      edges: [],
    });
    expect(partial.groupOrder).toEqual(["Knowledge", "Other"]); // System/Packages/Neovim absent, not phantom-included
  });

  test("typeGroup is stable: the first node of a type fixes its group, not the last", () => {
    const firstWins = buildModel({
      nodes: [node("packages/a", "Nix Package", "A"), node("flakes/b", "Nix Package", "B")],
      edges: [],
    });
    expect(firstWins.typeGroup["Nix Package"]).toBe("Packages");
    const reversed = buildModel({
      nodes: [node("flakes/b", "Nix Package", "B"), node("packages/a", "Nix Package", "A")],
      edges: [],
    });
    expect(reversed.typeGroup["Nix Package"]).toBe("Other"); // still the FIRST node's group, not overwritten by the second
  });
});
