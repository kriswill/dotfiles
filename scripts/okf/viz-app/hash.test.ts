import { describe, expect, test } from "bun:test";
import { decodeHash, encodeHash } from "./hash";

const model = { byId: { "nvim/architecture": {} }, files: { "scripts/okf/viz.ts": {} } };

describe("encodeHash", () => {
  test("concept / file / none", () => {
    expect(encodeHash({ kind: "concept", id: "nvim/architecture" })).toBe("c/nvim/architecture");
    expect(encodeHash({ kind: "file", path: "scripts/okf/viz.ts" })).toBe("f/scripts/okf/viz.ts");
    expect(encodeHash({ kind: "none" })).toBe("");
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

  test("percent-encoded hashes decode", () => {
    expect(decodeHash("c/nvim%2Farchitecture", model)).toEqual({ kind: "concept", id: "nvim/architecture" });
  });

  test("unknown targets and junk fall back to none", () => {
    expect(decodeHash("c/nope", model)).toEqual({ kind: "none" });
    expect(decodeHash("f/nope.ts", model)).toEqual({ kind: "none" });
    expect(decodeHash("garbage", model)).toEqual({ kind: "none" });
    expect(decodeHash("", model)).toEqual({ kind: "none" });
  });

  test("round-trips", () => {
    const sel = { kind: "concept", id: "nvim/architecture" } as const;
    expect(decodeHash(encodeHash(sel), model)).toEqual(sel);
  });
});
