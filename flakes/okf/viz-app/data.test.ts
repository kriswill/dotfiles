import { describe, expect, test } from "bun:test";
import type { FacetConfig } from "./config";
import {
  buildModel,
  conceptTree,
  dirOf,
  facetValueOf,
  neighborsWithin,
  parsePackagePlatforms,
  repoNameFromUrl,
  treeIds,
  type ConceptTree,
} from "./data";
import { cfg, node } from "./test-helpers";

const raw = {
  nodes: [node("a", "Decision", "Alpha"), node("b", "Zeta Type", "Beta"), node("c", "Alpha Module", "Gamma")],
  edges: [
    { s: "a", t: "b" },
    { s: "c", t: "b" },
    { s: "a", t: "ghost" }, // dangling — must be dropped
  ],
  files: { "flakes/okf/viz.ts": { html: "", lines: 1, size: 10, date: "", lang: "ts", refs: [] } },
  cfg: cfg(),
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

  test("type counts and taxonomy-types-first ordering with alpha overflow", () => {
    expect(m.typeCounts).toEqual({ Decision: 1, "Zeta Type": 1, "Alpha Module": 1 });
    expect(m.allTypes).toEqual(["Alpha Module", "Decision", "Zeta Type"]);
  });

  test("radius formula matches legacy scene sizing", () => {
    expect(m.radii[0]).toBeCloseTo((3.5 + Math.min(6.5, 1 * 0.8)) * 0.2058);
    expect(m.radii[1]).toBeCloseTo((3.5 + Math.min(6.5, 2 * 0.8)) * 0.2058);
  });

  test("byId and indexOf agree with node order", () => {
    expect(m.byId["b"]!.title).toBe("Beta");
    expect(m.indexOf.get("c")).toBe(2);
  });

  test("missing files/dirs/repoUrl/commitUrl/commits keys default to empty", () => {
    const empty = buildModel({ nodes: raw.nodes, edges: [] });
    expect(empty.files).toEqual({});
    expect(empty.dirs).toEqual({});
    expect(empty.repoUrl).toBeNull();
    expect(empty.commitUrl).toBeNull();
    expect(empty.repoName).toBeNull();
    expect(empty.commits).toEqual({});
  });

  test("repoName derives owner/repo from repoUrl; commitUrl passes through", () => {
    const named = buildModel({
      ...raw,
      repoUrl: "https://github.com/acme/widgets",
      commitUrl: "https://github.com/acme/widgets/commit/{hash}",
    });
    expect(named.repoName).toBe("acme/widgets");
    expect(named.commitUrl).toBe("https://github.com/acme/widgets/commit/{hash}");
  });
});

describe("repoNameFromUrl", () => {
  test("https/ssh shapes, with or without .git", () => {
    expect(repoNameFromUrl("https://github.com/o/r")).toBe("o/r");
    expect(repoNameFromUrl("https://github.com/o/r.git")).toBe("o/r");
    expect(repoNameFromUrl("git@github.com:o/r.git")).toBe("o/r");
    expect(repoNameFromUrl("git@github.com:o/r")).toBe("o/r");
  });

  test("forge-agnostic: any host works, subgroup paths kept whole", () => {
    expect(repoNameFromUrl("https://codeberg.org/earthgman/snowglobe-lib")).toBe("earthgman/snowglobe-lib");
    expect(repoNameFromUrl("https://gitlab.com/group/sub/repo.git")).toBe("group/sub/repo");
    expect(repoNameFromUrl("ssh://git@sr.ht/~o/r")).toBe("~o/r");
  });

  test("explicit ports are dropped, not captured into the name (manual vcs.url overrides never pass through normalizeRemoteUrl)", () => {
    expect(repoNameFromUrl("https://git.internal:8080/team/repo")).toBe("team/repo");
    expect(repoNameFromUrl("ssh://git@git.example.com:2222/o/r.git")).toBe("o/r");
  });

  test("null and underivable shapes yield null (display.name covers those)", () => {
    expect(repoNameFromUrl(null)).toBeNull();
    expect(repoNameFromUrl("not a url")).toBeNull();
  });
});

describe("grouping", () => {
  const groupedRaw = {
    nodes: [
      node("decisions/x", "Decision", "X"),
      node("patterns/y", "Pattern", "Y"),
      node("modules/z", "Alpha Module", "Z"),
      node("hosts/w", "Host", "W"),
      node("packages/p", "Nix Package", "P"),
      node("wiki/n", "Wiki Plugin", "N"),
      node("mystery/m", "Mystery Type", "M"), // unmapped dir -> Other
    ],
    edges: [],
    cfg: cfg(),
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
      "Alpha Module": "System",
      Host: "System",
      "Nix Package": "Packages",
      "Wiki Plugin": "Wiki",
      "Mystery Type": "Other",
    });
  });

  test("groupOrder is the configured group-order filtered to present groups, Other trailing", () => {
    expect(gm.groupOrder).toEqual(["Knowledge", "System", "Packages", "Wiki", "Other"]);
  });

  test("groupTypes lists member types in allTypes (taxonomy-types-first) order", () => {
    expect(gm.groupTypes["Knowledge"]).toEqual(["Pattern", "Decision"]);
    expect(gm.groupTypes["System"]).toEqual(["Alpha Module", "Host"]);
    expect(gm.groupTypes["Packages"]).toEqual(["Nix Package"]);
    expect(gm.groupTypes["Wiki"]).toEqual(["Wiki Plugin"]);
    expect(gm.groupTypes["Other"]).toEqual(["Mystery Type"]);
  });

  test("a bundle with no unmapped directory has no Other group", () => {
    const clean = buildModel({ nodes: [node("decisions/x", "Decision", "X")], edges: [], cfg: cfg() });
    expect(clean.groupOrder).toEqual(["Knowledge"]);
    expect(clean.groupTypes["Other"]).toBeUndefined();
  });

  test("groupOrder filters out missing core groups even when Other is also present", () => {
    const partial = buildModel({
      nodes: [node("decisions/x", "Decision", "X"), node("mystery/m", "Mystery Type", "M")],
      edges: [],
      cfg: cfg(),
    });
    expect(partial.groupOrder).toEqual(["Knowledge", "Other"]); // System/Packages/Wiki absent, not phantom-included
  });

  test("listing the other bucket in group-order pins it without duplicating it", () => {
    const pinnedCfg = cfg();
    pinnedCfg.taxonomy["group-order"] = ["Other", ...pinnedCfg.taxonomy["group-order"]];
    const pinned = buildModel({
      nodes: [node("decisions/x", "Decision", "X"), node("mystery/m", "Mystery Type", "M")],
      edges: [],
      cfg: pinnedCfg,
    });
    expect(pinned.groupOrder).toEqual(["Other", "Knowledge"]); // pinned first, no trailing duplicate
  });

  test("typeGroup is stable: the first node of a type fixes its group, not the last", () => {
    const firstWins = buildModel({
      nodes: [node("packages/a", "Nix Package", "A"), node("flakes/b", "Nix Package", "B")],
      edges: [],
      cfg: cfg(),
    });
    expect(firstWins.typeGroup["Nix Package"]).toBe("Packages");
    const reversed = buildModel({
      nodes: [node("flakes/b", "Nix Package", "B"), node("packages/a", "Nix Package", "A")],
      edges: [],
      cfg: cfg(),
    });
    expect(reversed.typeGroup["Nix Package"]).toBe("Other"); // still the FIRST node's group, not overwritten by the second
  });
});

describe("neighborsWithin", () => {
  const nRaw = {
    nodes: [node("a", "Decision", "A"), node("b", "Pattern", "B"), node("c", "Pattern", "C"), node("d", "Pattern", "D")],
    edges: [
      { s: "a", t: "b" },
      { s: "b", t: "c" },
    ],
  };
  const nm = buildModel(nRaw);

  test("1-hop includes the origin and direct neighbors only", () => {
    expect(neighborsWithin(nm, "a", 1)).toEqual(new Set(["a", "b"]));
  });

  test("2-hop reaches through one more edge", () => {
    expect(neighborsWithin(nm, "a", 2)).toEqual(new Set(["a", "b", "c"]));
  });

  test("a disconnected node returns just itself", () => {
    expect(neighborsWithin(nm, "d", 1)).toEqual(new Set(["d"]));
  });

  test("an unknown id returns an empty set", () => {
    expect(neighborsWithin(nm, "nope", 1)).toEqual(new Set());
  });

  test("depth 2 finds no further growth once the 1-hop set is already closed", () => {
    // "b" (middle of a-b-c) already reaches its whole component at depth 1.
    expect(neighborsWithin(nm, "b", 2)).toEqual(new Set(["a", "b", "c"]));
  });
});

describe("conceptTree", () => {
  const all = () => true;
  // Compact tree shape: leaf -> id, branch -> [id, [child shapes]].
  const shape = (t: ConceptTree): unknown => (t.children.length ? [t.node.id, t.children.map(shape)] : t.node.id);
  const chain = buildModel({
    nodes: [
      node("a", "Decision", "Alpha"),
      node("b", "Pattern", "Beta"),
      node("c", "Pattern", "Gamma"),
      node("d", "Pattern", "Delta"),
    ],
    edges: [
      { s: "a", t: "b" },
      { s: "b", t: "c" },
    ],
  });

  test("depth 2 nests each BFS layer one level deeper", () => {
    expect(shape(conceptTree(chain, "a", 2, all)!)).toEqual(["a", [["b", ["c"]]]]);
  });

  test("depth 1 stops at direct links", () => {
    expect(shape(conceptTree(chain, "a", 1, all)!)).toEqual(["a", ["b"]]);
  });

  test("a diamond attaches the shared grandchild under one parent only (alphabetically first)", () => {
    const diamond = buildModel({
      nodes: [
        node("a", "Decision", "Alpha"),
        node("b", "Pattern", "Beta"),
        node("c", "Pattern", "Gamma"),
        node("d", "Pattern", "Delta"),
      ],
      edges: [
        { s: "a", t: "b" },
        { s: "a", t: "c" },
        { s: "b", t: "d" },
        { s: "c", t: "d" },
      ],
    });
    expect(shape(conceptTree(diamond, "a", 2, all)!)).toEqual(["a", [["b", ["d"]], "c"]]);
  });

  test("duplicate titles tie-break by id, for both sibling order and parent choice", () => {
    const dup = buildModel({
      nodes: [
        node("a", "Decision", "Alpha"),
        node("m2", "Pattern", "Mid"),
        node("m1", "Pattern", "Mid"),
        node("z", "Pattern", "Zed"),
      ],
      edges: [
        { s: "a", t: "m2" },
        { s: "a", t: "m1" },
        { s: "m1", t: "z" },
        { s: "m2", t: "z" },
      ],
    });
    expect(shape(conceptTree(dup, "a", 2, all)!)).toEqual(["a", [["m1", ["z"]], "m2"]]);
  });

  test("an invisible node is spliced out and its visible descendants promoted", () => {
    const t = conceptTree(chain, "a", 2, (n) => n.id !== "b")!;
    expect(shape(t)).toEqual(["a", ["c"]]);
    expect(treeIds(t)).toEqual(new Set(["a", "c"]));
  });

  test("the anchor is always included even when it fails visible", () => {
    expect(shape(conceptTree(chain, "a", 1, (n) => n.id !== "a")!)).toEqual(["a", ["b"]]);
  });

  test("an edge-less anchor yields a childless root", () => {
    expect(shape(conceptTree(chain, "d", 2, all)!)).toBe("d");
  });

  test("an unknown anchor returns null", () => {
    expect(conceptTree(chain, "nope", 1, all)).toBeNull();
  });

  test("a cycle emits each node exactly once", () => {
    const tri = buildModel({
      nodes: [node("a", "Decision", "Alpha"), node("b", "Pattern", "Beta"), node("c", "Pattern", "Gamma")],
      edges: [
        { s: "a", t: "b" },
        { s: "b", t: "c" },
        { s: "c", t: "a" },
      ],
    });
    expect(shape(conceptTree(tri, "a", 2, all)!)).toEqual(["a", ["b", "c"]]);
  });

  test("treeIds collects the anchor and every emitted row", () => {
    expect(treeIds(conceptTree(chain, "a", 2, all)!)).toEqual(new Set(["a", "b", "c"]));
  });
});

describe("parsePackagePlatforms", () => {
  // Mirrors modules/packages.nix's shape: a `${system}` interpolation (whose '}'
  // would truncate a lazy regex, dropping later attrs) plus inline `{ }` callPackage args.
  const nix = `
  packages = {
    iv = pkgs.callPackage ../pkgs/iv.nix { };
    tomato = pkgs.callPackage ../pkgs/tomato.nix { tomato-src = inputs.tomato; };
    ccglass = inputs.ccglass.packages.\${system}.ccglass;
  }
  // lib.optionalAttrs (system == "aarch64-darwin") {
    apple-container = inputs.apple-container.packages.\${system}.apple-container;
    podman = pkgs.callPackage ../pkgs/podman.nix { };
    kitten = pkgs.callPackage ../pkgs/kitten.nix { };
    // A guarded package with a MULTI-LINE nested arg: its own-line \`packaged-src =\`
    // must NOT be captured as a top-level package (depth-aware extraction).
    packaged = pkgs.callPackage ../pkgs/packaged.nix {
      packaged-src = inputs.packaged;
    };
  }
  // lib.optionalAttrs (lib.hasSuffix "linux" system) {
    flatpak-user = pkgs.callPackage ../pkgs/flatpak-user.nix { };
    wowup = pkgs.callPackage ../pkgs/wowup.nix { };
  };
`;

  const GUARDS = { darwin: "macos", linux: "linux" };

  test("classifies both guarded blocks, no attrs dropped past a \${system} '}'", () => {
    expect(parsePackagePlatforms(nix, GUARDS)).toEqual({
      "apple-container": "macos",
      podman: "macos",
      kitten: "macos",
      packaged: "macos",
      "flatpak-user": "linux",
      wowup: "linux",
    });
    // Universal packages (outside any optionalAttrs block) are absent -> "both".
    expect(parsePackagePlatforms(nix, GUARDS)["iv"]).toBeUndefined();
    // A nested callPackage-arg attr on its own line is NOT captured as a package.
    expect(parsePackagePlatforms(nix, GUARDS)["packaged-src"]).toBeUndefined();
    // The tomato-src nested arg in the universal block is likewise never scanned.
    expect(parsePackagePlatforms(nix, GUARDS)["tomato-src"]).toBeUndefined();
  });

  test("absent/garbage input yields an empty map (packages default to both)", () => {
    expect(parsePackagePlatforms("", GUARDS)).toEqual({});
    expect(parsePackagePlatforms("no optionalAttrs here { just: braces }", GUARDS)).toEqual({});
  });

  test("an unbalanced (truncated) block bails instead of misclassifying", () => {
    expect(parsePackagePlatforms('// lib.optionalAttrs (system == "aarch64-darwin") { podman = x;', GUARDS)).toEqual(
      {},
    );
  });

  test("empty guards classify nothing", () => {
    expect(parsePackagePlatforms(nix, {})).toEqual({});
  });
});

describe("facetValueOf", () => {
  // Layered fixture: every stage of the pipeline has a live rule, so each
  // test isolates one precedence hop by choosing which stages the fixture
  // node actually hits.
  const facet: FacetConfig = {
    name: "platform",
    values: ["macos", "linux"],
    types: { "Alpha Module": "macos", "Beta Module": "linux" },
    ids: { "hosts/europa": "linux" },
    frontmatter: "os",
    classify: {
      provider: "nix-optional-attrs",
      file: "modules/packages.nix",
      guards: { darwin: "macos", linux: "linux" },
      types: ["Nix Package"],
      key: "basename",
    },
  };
  const nix = { kitten: "macos", "flatpak-user": "linux" };

  test("ids wins over classify, frontmatter, and types", () => {
    const n = node("hosts/europa", "Alpha Module", "Europa", { fm: { os: "macos" } });
    expect(facetValueOf(n, facet, nix)).toBe("linux");
  });

  test("classify wins over frontmatter and types when the type is listed", () => {
    const n = node("packages/kitten", "Nix Package", "kitten", { fm: { os: "linux" } });
    expect(facetValueOf(n, facet, nix)).toBe("macos");
  });

  test("a classify miss falls through to frontmatter, then types — it does not resolve to unresolved", () => {
    const withFm = node("packages/iv", "Nix Package", "iv", { fm: { os: "linux" } });
    expect(facetValueOf(withFm, facet, nix)).toBe("linux");
    const bare = node("packages/iv", "Nix Package", "iv", {});
    expect(facetValueOf(bare, facet, nix)).toBeUndefined(); // classify miss, no fm, "Nix Package" unlisted in types
  });

  test('classify key = "id" looks up by full concept id instead of basename', () => {
    const byId: FacetConfig = {
      ...facet,
      classify: { provider: "command", command: ["x"], types: ["Nix Package"], key: "id" },
    };
    const n = node("packages/kitten", "Nix Package", "kitten", {});
    expect(facetValueOf(n, byId, { "packages/kitten": "linux" })).toBe("linux");
    expect(facetValueOf(n, byId, { kitten: "linux" })).toBeUndefined();
  });

  test("frontmatter wins over types when present", () => {
    const n = node("decisions/x", "Alpha Module", "X", { fm: { os: "linux" } });
    expect(facetValueOf(n, facet, {})).toBe("linux");
  });

  test("non-string frontmatter values are ignored, falling through to types", () => {
    const n = node("modules/nh", "Alpha Module", "Nh", { fm: { os: 123 } });
    expect(facetValueOf(n, facet, {})).toBe("macos");
  });

  test("a frontmatter value outside an explicit values list is unresolved, no fall-through to types", () => {
    const n = node("modules/nh", "Alpha Module", "Nh", { fm: { os: "bsd" } });
    expect(facetValueOf(n, facet, {})).toBeUndefined();
  });

  test("types is the last resort", () => {
    const n = node("modules/keyring", "Beta Module", "Keyring", {});
    expect(facetValueOf(n, facet, {})).toBe("linux");
  });

  test("an unlisted type with no ids/nix/fm hit resolves to undefined (unresolved, always visible)", () => {
    const n = node("decisions/x", "Decision", "X", {});
    expect(facetValueOf(n, facet, {})).toBeUndefined();
  });

  test("a facet with no explicit values accepts any frontmatter string (inference source)", () => {
    const inferFacet: FacetConfig = {
      name: "status",
      values: [],
      types: {},
      ids: {},
      frontmatter: "status",
      classify: null,
    };
    const n = node("x", "Decision", "X", { fm: { status: "draft" } });
    expect(facetValueOf(n, inferFacet, {})).toBe("draft");
  });
});

describe("buildModel facets", () => {
  test("legacy-parity: matches the old platformOf resolution, minus former both/neutral nodes", () => {
    const m = buildModel({
      nodes: [
        node("modules/nh", "Alpha Module", "nh"),
        node("modules/keyring", "Beta Module", "keyring"),
        node("modules/tmux", "Dual Module", "tmux"), // formerly "both" -> unresolved (unlisted type)
        node("packages/kitten", "Nix Package", "kitten"),
        node("packages/iv", "Nix Package", "iv"), // formerly "both" -> unresolved (nix miss, no fm/types entry)
        node("hosts/europa", "Host", "europa"),
        node("hosts/k", "Host", "k"),
        node("decisions/x", "Decision", "x"), // formerly "neutral" -> unresolved (unlisted type)
      ],
      edges: [],
      facetMaps: { platform: { kitten: "macos" } },
      cfg: cfg(),
    });
    expect(m.facets).toEqual([{ name: "platform", values: ["macos", "linux"] }]);
    expect(m.facetById["platform"]).toEqual({
      "modules/nh": "macos",
      "modules/keyring": "linux",
      "packages/kitten": "macos",
      "hosts/europa": "linux", // ids override
      "hosts/k": "macos", // types default
    });
    for (const dropped of ["modules/tmux", "packages/iv", "decisions/x"])
      expect(m.facetById["platform"]![dropped]).toBeUndefined();
  });

  test("missing facetMaps: classify concepts fall through (unresolved here, no fm/types entry)", () => {
    const m = buildModel({ nodes: [node("packages/kitten", "Nix Package", "kitten")], edges: [], cfg: cfg() });
    expect(m.facetById["platform"]!["packages/kitten"]).toBeUndefined();
  });

  test("values inference: a frontmatter-driven facet with no explicit values alpha-sorts observed values", () => {
    const m = buildModel({
      nodes: [
        node("a", "Decision", "A", { fm: { status: "stable" } }),
        node("b", "Decision", "B", { fm: { status: "draft" } }),
        node("c", "Decision", "C", {}), // no status -> unresolved, doesn't contribute a value
      ],
      edges: [],
      cfg: { facet: { status: { frontmatter: "status" } } },
    });
    expect(m.facets).toEqual([{ name: "status", values: ["draft", "stable"] }]);
    expect(m.facetById["status"]).toEqual({ a: "stable", b: "draft" });
  });

  test("multiple facets resolve independently", () => {
    const m = buildModel({
      nodes: [node("a", "Alpha Module", "A", { fm: { status: "stable" } })],
      edges: [],
      cfg: {
        facet: {
          platform: { values: ["macos", "linux"], types: { "Alpha Module": "macos" } },
          status: { frontmatter: "status" },
        },
      },
    });
    expect(m.facets).toEqual([
      { name: "platform", values: ["macos", "linux"] },
      { name: "status", values: ["stable"] },
    ]);
    expect(m.facetById["platform"]).toEqual({ a: "macos" });
    expect(m.facetById["status"]).toEqual({ a: "stable" });
  });

  test("a facet with no rule and no explicit values is dropped entirely (no-op lens)", () => {
    const m = buildModel({ nodes: [node("a", "Decision", "A")], edges: [], cfg: { facet: { empty: {} } } });
    expect(m.facets).toEqual([]);
    expect(m.facetById["empty"]).toBeUndefined();
  });
});

describe("generic (no-config) mode", () => {
  const m = buildModel({
    nodes: [
      node("decisions/x", "Decision", "X"),
      node("modules/z", "Alpha Module", "Z"),
      node("hosts/europa", "Host", "Europa"),
    ],
    edges: [],
    repoUrl: "https://github.com/acme/widgets",
  });

  test("types sort alphabetically (no configured slot order)", () => {
    expect(m.allTypes).toEqual(["Alpha Module", "Decision", "Host"]);
    expect(m.cfg.taxonomy.types).toEqual([]);
  });

  test("no legend groups at all (flat legend), not one big Other bucket", () => {
    expect(m.groupOrder).toEqual([]);
    expect(m.groupTypes).toEqual({});
    expect(m.typeGroup).toEqual({});
  });

  test("no facets configured: no lenses at all, nothing hidden by any facet", () => {
    expect(m.facets).toEqual([]);
    expect(m.facetById).toEqual({});
  });

  test("display falls back to the git-derived name and generic strings", () => {
    expect(m.displayName).toBe("acme/widgets");
    expect(m.cfg.display.badge).toBe("OKF viz");
    expect(buildModel({ nodes: [], edges: [] }).displayName).toBe("OKF bundle");
  });
});
