import { describe, expect, test } from "bun:test";
import { decodeHash, decodeViewHash, encodeHash, encodeViewHash } from "./hash";

const model = {
  byId: { "nvim/architecture": {} },
  files: { "flakes/okf/viz.ts": {}, "docs/50%.md": {}, "docs/what?.md": {} },
  dirs: { "flakes/ccglass": {} },
  typeCounts: { "Darwin Module": 2, Decision: 1 },
  facets: [
    { name: "platform", values: ["macos", "linux"] },
    { name: "status", values: ["draft", "stable"] },
  ],
};

describe("encodeHash", () => {
  test("concept / file / dir / none", () => {
    expect(encodeHash({ kind: "concept", id: "nvim/architecture" })).toBe("c/nvim/architecture");
    expect(encodeHash({ kind: "file", path: "flakes/okf/viz.ts" })).toBe("f/flakes/okf/viz.ts");
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
  const f = (o: Partial<{ hidden: string[]; q: string; isolate: 0 | 1 | 2; facets: Record<string, string> }>) => ({
    hidden: [],
    q: "",
    isolate: 0 as const,
    facets: {},
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

  test("a facet rides behind '?' as its own name, always emittable (no selection gate)", () => {
    expect(encodeViewHash({ sel: none, filters: f({ facets: { platform: "macos" } }) })).toBe("?platform=macos");
    expect(
      encodeViewHash({ sel: { kind: "file", path: "docs/50%.md" }, filters: f({ facets: { platform: "linux" } }) }),
    ).toBe("f/docs/50%25.md?platform=linux");
    expect(encodeViewHash({ sel: none, filters: f({ facets: { platform: "all" } }) })).toBe(""); // "all" omitted
  });

  test("multiple active facets all encode; 'all' entries are skipped", () => {
    expect(encodeViewHash({ sel: none, filters: f({ facets: { platform: "macos", status: "all" } }) })).toBe(
      "?platform=macos",
    );
    expect(encodeViewHash({ sel: none, filters: f({ facets: { platform: "macos", status: "stable" } }) })).toBe(
      "?platform=macos&status=stable",
    );
  });

  test("hide, q, isolate, then facets appear in that order", () => {
    expect(
      encodeViewHash({
        sel: { kind: "concept", id: "nvim/architecture" },
        filters: f({ hidden: ["Decision"], q: "arch", isolate: 1, facets: { platform: "macos", status: "stable" } }),
      }),
    ).toBe("c/nvim/architecture?hide=Decision&q=arch&isolate=1&platform=macos&status=stable");
  });
});

describe("decodeViewHash", () => {
  test("selection + filters round-trip, including '%' paths", () => {
    for (const view of [
      {
        sel: { kind: "concept", id: "nvim/architecture" },
        filters: { hidden: ["Darwin Module", "Decision"], q: "", isolate: 0, facets: { platform: "all", status: "all" } },
      },
      {
        sel: { kind: "none" },
        filters: { hidden: [], q: "a?b&c=%", isolate: 0, facets: { platform: "macos", status: "all" } },
      },
      {
        sel: { kind: "file", path: "docs/50%.md" },
        filters: { hidden: ["Decision"], q: "tmux", isolate: 0, facets: { platform: "linux", status: "draft" } },
      },
      {
        sel: { kind: "concept", id: "nvim/architecture" },
        filters: { hidden: ["Decision"], q: "tmux", isolate: 1, facets: { platform: "macos", status: "all" } },
      },
    ] as const) {
      const decoded = decodeViewHash(encodeViewHash(view as never), model);
      expect(decoded.sel).toEqual(view.sel);
      expect(decoded.filters).toEqual(view.filters as never);
    }
  });

  test("bare selection hashes decode with empty filters, every facet 'all' (old links stay valid)", () => {
    expect(decodeViewHash("c/nvim/architecture", model)).toEqual({
      sel: { kind: "concept", id: "nvim/architecture" },
      filters: { hidden: [], q: "", isolate: 0, facets: { platform: "all", status: "all" } },
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
    expect(decodeViewHash("f/flakes/okf/viz.ts?isolate=1", model).filters.isolate).toBe(0);
  });

  test("garbage isolate values clamp to 0", () => {
    expect(decodeViewHash("c/nvim/architecture?isolate=3", model).filters.isolate).toBe(0);
    expect(decodeViewHash("c/nvim/architecture?isolate=abc", model).filters.isolate).toBe(0);
  });

  test("only known facet names decode; a param outside a facet's values clamps to 'all'", () => {
    expect(decodeViewHash("?platform=macos", model).filters.facets).toEqual({ platform: "macos", status: "all" });
    expect(decodeViewHash("?platform=bogus", model).filters.facets.platform).toBe("all");
    expect(decodeViewHash("?nope=macos", model).filters.facets).toEqual({ platform: "all", status: "all" });
  });

  test("os= decodes as a legacy alias for a facet literally named 'platform'", () => {
    expect(decodeViewHash("?os=macos", model).filters.facets.platform).toBe("macos");
    expect(decodeViewHash("f/flakes/okf/viz.ts?os=linux", model).filters.facets.platform).toBe("linux");
    expect(decodeViewHash("d/flakes/ccglass?os=macos", model).filters.facets.platform).toBe("macos");
    expect(decodeViewHash("c/nvim/architecture?os=bogus", model).filters.facets.platform).toBe("all");
    expect(decodeViewHash("c/nvim/architecture", model).filters.facets.platform).toBe("all");
  });

  test("os= is ignored when no facet is literally named 'platform'", () => {
    const noPlatform = { ...model, facets: [{ name: "status", values: ["draft", "stable"] }] };
    expect(decodeViewHash("?os=macos", noPlatform).filters.facets).toEqual({ status: "all" });
  });

  test("an explicit platform= wins over a simultaneous legacy os=", () => {
    expect(decodeViewHash("?platform=linux&os=macos", model).filters.facets.platform).toBe("linux");
  });

  test("a model without configured facets decodes an empty facets record", () => {
    const generic = { ...model, facets: undefined };
    expect(decodeViewHash("?os=macos", generic).filters.facets).toEqual({});
    expect(decodeViewHash("?os=macos", { ...model, facets: [] }).filters.facets).toEqual({});
  });
});

describe("decodeHash", () => {
  test("valid concept, with and without leading #", () => {
    expect(decodeHash("c/nvim/architecture", model)).toEqual({ kind: "concept", id: "nvim/architecture" });
    expect(decodeHash("#c/nvim/architecture", model)).toEqual({ kind: "concept", id: "nvim/architecture" });
  });

  test("valid file", () => {
    expect(decodeHash("f/flakes/okf/viz.ts", model)).toEqual({ kind: "file", path: "flakes/okf/viz.ts" });
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
