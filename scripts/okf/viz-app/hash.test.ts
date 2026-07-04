import { describe, expect, test } from "bun:test";
import { decodeHash, decodeViewHash, encodeHash, encodeViewHash } from "./hash";

const model = {
  byId: { "nvim/architecture": {} },
  files: { "scripts/okf/viz.ts": {}, "docs/50%.md": {}, "docs/what?.md": {} },
  dirs: { "flakes/ccglass": {} },
  typeCounts: { "Darwin Module": 2, Decision: 1 },
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

  test("empty filters add nothing", () => {
    expect(encodeViewHash({ sel: none, filters: { hidden: [], q: "", isolate: 0 } })).toBe("");
    expect(
      encodeViewHash({ sel: { kind: "concept", id: "nvim/architecture" }, filters: { hidden: [], q: "", isolate: 0 } }),
    ).toBe("c/nvim/architecture");
  });

  test("filters ride behind '?', hidden types sorted for a canonical form", () => {
    expect(encodeViewHash({ sel: none, filters: { hidden: ["Decision", "Darwin Module"], q: "", isolate: 0 } })).toBe(
      "?hide=Darwin+Module%2CDecision",
    );
    expect(encodeViewHash({ sel: none, filters: { hidden: ["Darwin Module", "Decision"], q: "", isolate: 0 } })).toBe(
      "?hide=Darwin+Module%2CDecision",
    );
    expect(
      encodeViewHash({
        sel: { kind: "concept", id: "nvim/architecture" },
        filters: { hidden: [], q: "tmux conf", isolate: 0 },
      }),
    ).toBe("c/nvim/architecture?q=tmux+conf");
  });

  test("isolate rides behind '?' only for a concept selection and a nonzero depth", () => {
    expect(
      encodeViewHash({ sel: { kind: "concept", id: "nvim/architecture" }, filters: { hidden: [], q: "", isolate: 2 } }),
    ).toBe("c/nvim/architecture?isolate=2");
    expect(
      encodeViewHash({ sel: { kind: "concept", id: "nvim/architecture" }, filters: { hidden: [], q: "", isolate: 0 } }),
    ).toBe("c/nvim/architecture");
    expect(encodeViewHash({ sel: none, filters: { hidden: [], q: "", isolate: 2 } })).toBe(""); // no selection -> never emitted
  });

  test("isolate is ordered after hide and q in the query string", () => {
    expect(
      encodeViewHash({
        sel: { kind: "concept", id: "nvim/architecture" },
        filters: { hidden: ["Decision"], q: "arch", isolate: 1 },
      }),
    ).toBe("c/nvim/architecture?hide=Decision&q=arch&isolate=1");
  });
});

describe("decodeViewHash", () => {
  test("selection + filters round-trip, including '%' paths", () => {
    for (const view of [
      {
        sel: { kind: "concept", id: "nvim/architecture" },
        filters: { hidden: ["Darwin Module", "Decision"], q: "", isolate: 0 },
      },
      { sel: { kind: "none" }, filters: { hidden: [], q: "a?b&c=%", isolate: 0 } },
      { sel: { kind: "file", path: "docs/50%.md" }, filters: { hidden: ["Decision"], q: "tmux", isolate: 0 } },
      { sel: { kind: "concept", id: "nvim/architecture" }, filters: { hidden: ["Decision"], q: "tmux", isolate: 1 } },
    ] as const) {
      const decoded = decodeViewHash(encodeViewHash(view as never), model);
      expect(decoded.sel).toEqual(view.sel);
      expect(decoded.filters).toEqual(view.filters as never);
    }
  });

  test("bare selection hashes decode with empty filters (old links stay valid)", () => {
    expect(decodeViewHash("c/nvim/architecture", model)).toEqual({
      sel: { kind: "concept", id: "nvim/architecture" },
      filters: { hidden: [], q: "", isolate: 0 },
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
