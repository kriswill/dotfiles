import { describe, expect, test } from "bun:test";
import { buildModel, dirOf, neighborsWithin, parsePackagePlatforms, platformOf } from "./data";
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

  test("classifies both guarded blocks, no attrs dropped past a \${system} '}'", () => {
    expect(parsePackagePlatforms(nix)).toEqual({
      "apple-container": "darwin",
      podman: "darwin",
      kitten: "darwin",
      packaged: "darwin",
      "flatpak-user": "nixos",
      wowup: "nixos",
    });
    // Universal packages (outside any optionalAttrs block) are absent -> "both".
    expect(parsePackagePlatforms(nix)["iv"]).toBeUndefined();
    // A nested callPackage-arg attr on its own line is NOT captured as a package.
    expect(parsePackagePlatforms(nix)["packaged-src"]).toBeUndefined();
    // The tomato-src nested arg in the universal block is likewise never scanned.
    expect(parsePackagePlatforms(nix)["tomato-src"]).toBeUndefined();
  });

  test("absent/garbage input yields an empty map (packages default to both)", () => {
    expect(parsePackagePlatforms("")).toEqual({});
    expect(parsePackagePlatforms("no optionalAttrs here { just: braces }")).toEqual({});
  });

  test("an unbalanced (truncated) block bails instead of misclassifying", () => {
    expect(parsePackagePlatforms('// lib.optionalAttrs (system == "aarch64-darwin") { podman = x;')).toEqual({});
  });
});

describe("platformOf", () => {
  const pkg = { kitten: "darwin", "flatpak-user": "nixos" } as const;

  test("modules derive from type", () => {
    expect(platformOf("Darwin Module", "modules/nh", {})).toBe("darwin");
    expect(platformOf("NixOS Module", "modules/keyring", {})).toBe("nixos");
    expect(platformOf("Dual Module", "modules/tmux", {})).toBe("both");
    expect(platformOf("Flake-parts Module", "modules/flake-parts", {})).toBe("both");
  });

  test("neovim is universal, knowledge is neutral", () => {
    expect(platformOf("Neovim Plugin", "nvim/plugins/blink", {})).toBe("both");
    expect(platformOf("Neovim Config", "nvim/keymaps", {})).toBe("both");
    expect(platformOf("Decision", "decisions/x", {})).toBe("neutral");
    expect(platformOf("Reference", "okf-profile", {})).toBe("neutral");
  });

  test("hosts derive from host id (only nebula is nixos)", () => {
    expect(platformOf("Host", "hosts/nebula", {})).toBe("nixos");
    expect(platformOf("Host", "hosts/k", {})).toBe("darwin");
    expect(platformOf("Host", "hosts/SOC-Kris-Williams", {})).toBe("darwin");
  });

  test("packages/sub-flakes/overlays look up the guard by basename, default both", () => {
    expect(platformOf("Nix Package", "packages/kitten", pkg)).toBe("darwin");
    expect(platformOf("Nix Package", "packages/flatpak-user", pkg)).toBe("nixos");
    expect(platformOf("Nix Package", "packages/iv", pkg)).toBe("both"); // universal
    expect(platformOf("Sub-flake", "packages/ccglass", pkg)).toBe("both");
    expect(platformOf("Overlay", "packages/direnv", pkg)).toBe("both");
  });

  test("unknown types default to neutral (never hidden by an OS filter)", () => {
    expect(platformOf("Some Future Type", "x/y", {})).toBe("neutral");
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
    const m = buildModel({ nodes: [node("packages/kitten", "Nix Package", "kitten")], edges: [] });
    expect(m.platformById["packages/kitten"]).toBe("both");
  });
});
