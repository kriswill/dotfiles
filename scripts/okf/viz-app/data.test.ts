import { describe, expect, test } from "bun:test";
import { normalizeVizConfig } from "./config";
import {
  buildModel,
  conceptTree,
  dirOf,
  neighborsWithin,
  parsePackagePlatforms,
  platformOf,
  repoNameFromUrl,
  treeIds,
  type ConceptTree,
} from "./data";
import { cfg, node } from "./test-helpers";

const raw = {
  nodes: [node("a", "Decision", "Alpha"), node("b", "Zeta Type", "Beta"), node("c", "Darwin Module", "Gamma")],
  edges: [
    { s: "a", t: "b" },
    { s: "c", t: "b" },
    { s: "a", t: "ghost" }, // dangling — must be dropped
  ],
  files: { "scripts/okf/viz.ts": { html: "", lines: 1, size: 10, date: "", lang: "ts", refs: [] } },
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
    expect(empty.repoName).toBeNull();
    expect(empty.commits).toEqual({});
  });

  test("repoName derives owner/repo from repoUrl", () => {
    const named = buildModel({ ...raw, repoUrl: "https://github.com/kriswill/dotfiles" });
    expect(named.repoName).toBe("kriswill/dotfiles");
  });
});

describe("repoNameFromUrl", () => {
  test("accepts the same shapes as githubRemoteUrl: https/ssh, with or without .git", () => {
    expect(repoNameFromUrl("https://github.com/o/r")).toBe("o/r");
    expect(repoNameFromUrl("https://github.com/o/r.git")).toBe("o/r");
    expect(repoNameFromUrl("git@github.com:o/r.git")).toBe("o/r");
    expect(repoNameFromUrl("git@github.com:o/r")).toBe("o/r");
  });

  test("null and non-GitHub URLs yield null (display.name covers those)", () => {
    expect(repoNameFromUrl(null)).toBeNull();
    expect(repoNameFromUrl("https://gitlab.com/o/r")).toBeNull();
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
      "Darwin Module": "System",
      Host: "System",
      "Nix Package": "Packages",
      "Neovim Plugin": "Neovim",
      "Mystery Type": "Other",
    });
  });

  test("groupOrder is the configured group-order filtered to present groups, Other trailing", () => {
    expect(gm.groupOrder).toEqual(["Knowledge", "System", "Packages", "Neovim", "Other"]);
  });

  test("groupTypes lists member types in allTypes (taxonomy-types-first) order", () => {
    expect(gm.groupTypes["Knowledge"]).toEqual(["Pattern", "Decision"]);
    expect(gm.groupTypes["System"]).toEqual(["Darwin Module", "Host"]);
    expect(gm.groupTypes["Packages"]).toEqual(["Nix Package"]);
    expect(gm.groupTypes["Neovim"]).toEqual(["Neovim Plugin"]);
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
    expect(partial.groupOrder).toEqual(["Knowledge", "Other"]); // System/Packages/Neovim absent, not phantom-included
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

  const GUARDS = { darwin: "darwin", linux: "nixos" };

  test("classifies both guarded blocks, no attrs dropped past a \${system} '}'", () => {
    expect(parsePackagePlatforms(nix, GUARDS)).toEqual({
      "apple-container": "darwin",
      podman: "darwin",
      kitten: "darwin",
      packaged: "darwin",
      "flatpak-user": "nixos",
      wowup: "nixos",
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

describe("platformOf", () => {
  const pkg = { kitten: "darwin", "flatpak-user": "nixos" } as const;
  const platform = normalizeVizConfig(cfg()).platform;

  test("modules derive from the type rule table", () => {
    expect(platformOf("Darwin Module", "modules/nh", {}, platform)).toBe("darwin");
    expect(platformOf("NixOS Module", "modules/keyring", {}, platform)).toBe("nixos");
    expect(platformOf("Dual Module", "modules/tmux", {}, platform)).toBe("both");
    expect(platformOf("Flake-parts Module", "modules/flake-parts", {}, platform)).toBe("both");
  });

  test("neovim is universal, knowledge is neutral", () => {
    expect(platformOf("Neovim Plugin", "nvim/plugins/blink", {}, platform)).toBe("both");
    expect(platformOf("Neovim Config", "nvim/keymaps", {}, platform)).toBe("both");
    expect(platformOf("Decision", "decisions/x", {}, platform)).toBe("neutral");
    expect(platformOf("Reference", "okf-profile", {}, platform)).toBe("neutral");
  });

  test("hosts look up the configured host list, else host-default", () => {
    expect(platformOf("Host", "hosts/nebula", {}, platform)).toBe("nixos");
    expect(platformOf("Host", "hosts/k", {}, platform)).toBe("darwin");
    expect(platformOf("Host", "hosts/SOC-Kris-Williams", {}, platform)).toBe("darwin");
  });

  test("packages/sub-flakes/overlays look up the guard by basename, default both", () => {
    expect(platformOf("Nix Package", "packages/kitten", pkg, platform)).toBe("darwin");
    expect(platformOf("Nix Package", "packages/flatpak-user", pkg, platform)).toBe("nixos");
    expect(platformOf("Nix Package", "packages/iv", pkg, platform)).toBe("both"); // universal
    expect(platformOf("Sub-flake", "packages/ccglass", pkg, platform)).toBe("both");
    expect(platformOf("Overlay", "packages/direnv", pkg, platform)).toBe("both");
  });

  test("unknown types default to neutral (never hidden by an OS filter)", () => {
    expect(platformOf("Some Future Type", "x/y", {}, platform)).toBe("neutral");
  });

  test("an unconfigured platform section makes everything neutral", () => {
    const bare = normalizeVizConfig({}).platform;
    expect(platformOf("Darwin Module", "modules/nh", {}, bare)).toBe("neutral");
    expect(platformOf("Host", "hosts/nebula", {}, bare)).toBe("neutral");
  });
});

describe("buildModel.platformById", () => {
  test("derives a platform for every node from type/host/package guards", () => {
    const m = buildModel({
      nodes: [
        node("modules/nh", "Darwin Module", "nh"),
        node("modules/keyring", "NixOS Module", "keyring"),
        node("packages/kitten", "Nix Package", "kitten"),
        node("packages/iv", "Nix Package", "iv"),
        node("decisions/x", "Decision", "X"),
      ],
      edges: [],
      pkgPlatforms: { kitten: "darwin" },
      cfg: cfg(),
    });
    expect(m.platformById).toEqual({
      "modules/nh": "darwin",
      "modules/keyring": "nixos",
      "packages/kitten": "darwin",
      "packages/iv": "both",
      "decisions/x": "neutral",
    });
  });

  test("missing pkgPlatforms defaults every package to both", () => {
    const m = buildModel({ nodes: [node("packages/kitten", "Nix Package", "kitten")], edges: [], cfg: cfg() });
    expect(m.platformById["packages/kitten"]).toBe("both");
  });
});

describe("generic (no-config) mode", () => {
  const m = buildModel({
    nodes: [
      node("decisions/x", "Decision", "X"),
      node("modules/z", "Darwin Module", "Z"),
      node("hosts/nebula", "Host", "Nebula"),
    ],
    edges: [],
    repoUrl: "https://github.com/kriswill/dotfiles",
  });

  test("types sort alphabetically (no configured slot order)", () => {
    expect(m.allTypes).toEqual(["Darwin Module", "Decision", "Host"]);
    expect(m.cfg.taxonomy.types).toEqual([]);
  });

  test("no legend groups at all (flat legend), not one big Other bucket", () => {
    expect(m.groupOrder).toEqual([]);
    expect(m.groupTypes).toEqual({});
    expect(m.typeGroup).toEqual({});
  });

  test("platform filter disabled: no values, every concept neutral", () => {
    expect(m.platforms).toEqual([]);
    expect(new Set(Object.values(m.platformById))).toEqual(new Set(["neutral"]));
  });

  test("display falls back to the git-derived name and generic strings", () => {
    expect(m.displayName).toBe("kriswill/dotfiles");
    expect(m.cfg.display.badge).toBe("OKF viz");
    expect(buildModel({ nodes: [], edges: [] }).displayName).toBe("OKF bundle");
  });
});
