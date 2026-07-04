import { describe, expect, test } from "bun:test";
import { decodeHash, decodeViewHash, encodeHash, encodeViewHash } from "./hash";

const model = {
  byId: { "nvim/architecture": {} },
  files: { "scripts/okf/viz.ts": {}, "docs/50%.md": {}, "docs/what?.md": {} },
  dirs: { "flakes/ccglass": {} },
  typeCounts: { "Darwin Module": 2, Decision: 1 },
  platforms: ["darwin", "nixos"],
};

describe("encodeHash", () => {
  test("concept / file / dir / none", () => {
    expect(encodeHash({ kind: "concept", id: "nvim/architecture" })).toBe("c/nvim/architecture");
    expect(encodeHash({ kind: "file", path: "scripts/okf/viz.ts" })).toBe("f/scripts/okf/viz.ts");
    expect(encodeHash({ kind: "dir", path: "flakes/ccglass" })).toBe("d/flakes/ccglass");
    expect(encodeHash({ kind: "none" })).toBe("");
  });

  test("literal '%' is escaped so the hash stays decodable", () => {
    expect(encodeHash({ kind: "file", path: "docs/50%.md" })).toBe("f/docs/50%25.md");
  });

  test("literal '?' is escaped so it can't read as the filter separator", () => {
    expect(encodeHash({ kind: "file", path: "docs/what?.md" })).toBe("f/docs/what%3F.md");
  });
});

describe("encodeViewHash", () => {
  const none = { kind: "none" } as const;
  const f = (o: Partial<{ hidden: string[]; q: string; isolate: 0 | 1 | 2; platform: string }>) => ({
    hidden: [],
    q: "",
    isolate: 0 as const,
    platform: "all",
    ...o,
  });

  test("empty filters add nothing", () => {
    expect(encodeViewHash({ sel: none, filters: f({}) })).toBe("");
    expect(encodeViewHash({ sel: { kind: "concept", id: "nvim/architecture" }, filters: f({}) })).toBe(
      "c/nvim/architecture",
    );
  });

  test("filters ride behind '?', hidden types sorted for a canonical form", () => {
    expect(encodeViewHash({ sel: none, filters: f({ hidden: ["Decision", "Darwin Module"] }) })).toBe(
      "?hide=Darwin+Module%2CDecision",
    );
    expect(encodeViewHash({ sel: none, filters: f({ hidden: ["Darwin Module", "Decision"] }) })).toBe(
      "?hide=Darwin+Module%2CDecision",
    );
    expect(encodeViewHash({ sel: { kind: "concept", id: "nvim/architecture" }, filters: f({ q: "tmux conf" }) })).toBe(
      "c/nvim/architecture?q=tmux+conf",
    );
  });

  test("isolate rides behind '?' only for a concept selection and a nonzero depth", () => {
    expect(encodeViewHash({ sel: { kind: "concept", id: "nvim/architecture" }, filters: f({ isolate: 2 }) })).toBe(
      "c/nvim/architecture?isolate=2",
    );
    expect(encodeViewHash({ sel: { kind: "concept", id: "nvim/architecture" }, filters: f({ isolate: 0 }) })).toBe(
      "c/nvim/architecture",
    );
    expect(encodeViewHash({ sel: none, filters: f({ isolate: 2 }) })).toBe(""); // no selection -> never emitted
  });

  test("platform rides behind '?' as os=, always emittable (no selection gate)", () => {
    expect(encodeViewHash({ sel: none, filters: f({ platform: "darwin" }) })).toBe("?os=darwin");
    expect(encodeViewHash({ sel: { kind: "file", path: "docs/50%.md" }, filters: f({ platform: "nixos" }) })).toBe(
      "f/docs/50%25.md?os=nixos",
    );
    expect(encodeViewHash({ sel: none, filters: f({ platform: "all" }) })).toBe(""); // "all" omitted
  });

  test("hide, q, isolate, os appear in a stable order", () => {
    expect(
      encodeViewHash({
        sel: { kind: "concept", id: "nvim/architecture" },
        filters: f({ hidden: ["Decision"], q: "arch", isolate: 1, platform: "darwin" }),
      }),
    ).toBe("c/nvim/architecture?hide=Decision&q=arch&isolate=1&os=darwin");
  });
});

describe("decodeViewHash", () => {
  test("selection + filters round-trip, including '%' paths", () => {
    for (const view of [
      {
        sel: { kind: "concept", id: "nvim/architecture" },
        filters: { hidden: ["Darwin Module", "Decision"], q: "", isolate: 0, platform: "all" },
      },
      { sel: { kind: "none" }, filters: { hidden: [], q: "a?b&c=%", isolate: 0, platform: "darwin" } },
      { sel: { kind: "file", path: "docs/50%.md" }, filters: { hidden: ["Decision"], q: "tmux", isolate: 0, platform: "nixos" } },
      { sel: { kind: "concept", id: "nvim/architecture" }, filters: { hidden: ["Decision"], q: "tmux", isolate: 1, platform: "darwin" } },
    ] as const) {
      const decoded = decodeViewHash(encodeViewHash(view as never), model);
      expect(decoded.sel).toEqual(view.sel);
      expect(decoded.filters).toEqual(view.filters as never);
    }
  });

  test("bare selection hashes decode with empty filters (old links stay valid)", () => {
    expect(decodeViewHash("c/nvim/architecture", model)).toEqual({
      sel: { kind: "concept", id: "nvim/architecture" },
      filters: { hidden: [], q: "", isolate: 0, platform: "all" },
    });
  });

  test("unknown hidden types are dropped against the model", () => {
    expect(decodeViewHash("?hide=Decision,Nope,", model).filters.hidden).toEqual(["Decision"]);
  });

  test("junk filter params fall back to empty filters", () => {
    expect(decodeViewHash("c/nvim/architecture?%%%", model).sel).toEqual({
      kind: "concept",
      id: "nvim/architecture",
    });
  });

  test("a stray isolate= on a non-concept selection is dropped on decode", () => {
    expect(decodeViewHash("?isolate=2", model).filters.isolate).toBe(0);
    expect(decodeViewHash("f/scripts/okf/viz.ts?isolate=1", model).filters.isolate).toBe(0);
  });

  test("garbage isolate values clamp to 0", () => {
    expect(decodeViewHash("c/nvim/architecture?isolate=3", model).filters.isolate).toBe(0);
    expect(decodeViewHash("c/nvim/architecture?isolate=abc", model).filters.isolate).toBe(0);
  });

  test("os= decodes for any selection kind; values outside model.platforms clamp to 'all'", () => {
    expect(decodeViewHash("?os=darwin", model).filters.platform).toBe("darwin");
    expect(decodeViewHash("f/scripts/okf/viz.ts?os=nixos", model).filters.platform).toBe("nixos");
    expect(decodeViewHash("d/flakes/ccglass?os=darwin", model).filters.platform).toBe("darwin");
    expect(decodeViewHash("c/nvim/architecture?os=bogus", model).filters.platform).toBe("all");
    expect(decodeViewHash("c/nvim/architecture", model).filters.platform).toBe("all");
  });

  test("a model without configured platforms clamps every os= to 'all'", () => {
    const generic = { ...model, platforms: undefined };
    expect(decodeViewHash("?os=darwin", generic).filters.platform).toBe("all");
    expect(decodeViewHash("?os=darwin", { ...model, platforms: [] }).filters.platform).toBe("all");
  });
});

describe("decodeHash", () => {
  test("valid concept, with and without leading #", () => {
    expect(decodeHash("c/nvim/architecture", model)).toEqual({ kind: "concept", id: "nvim/architecture" });
    expect(decodeHash("#c/nvim/architecture", model)).toEqual({ kind: "concept", id: "nvim/architecture" });
  });

  test("valid file", () => {
    expect(decodeHash("f/scripts/okf/viz.ts", model)).toEqual({ kind: "file", path: "scripts/okf/viz.ts" });
  });

  test("valid dir", () => {
    expect(decodeHash("d/flakes/ccglass", model)).toEqual({ kind: "dir", path: "flakes/ccglass" });
  });

  test("percent-encoded hashes decode", () => {
    expect(decodeHash("c/nvim%2Farchitecture", model)).toEqual({ kind: "concept", id: "nvim/architecture" });
  });

  test("unknown targets and junk fall back to none", () => {
    expect(decodeHash("c/nope", model)).toEqual({ kind: "none" });
    expect(decodeHash("f/nope.ts", model)).toEqual({ kind: "none" });
    expect(decodeHash("d/nope", model)).toEqual({ kind: "none" });
    expect(decodeHash("garbage", model)).toEqual({ kind: "none" });
    expect(decodeHash("", model)).toEqual({ kind: "none" });
  });

  test("round-trips", () => {
    const sel = { kind: "concept", id: "nvim/architecture" } as const;
    expect(decodeHash(encodeHash(sel), model)).toEqual(sel);
    const pct = { kind: "file", path: "docs/50%.md" } as const;
    expect(decodeHash(encodeHash(pct), model)).toEqual(pct);
  });
});
