import { describe, expect, test } from "bun:test";
import { formatDate } from "./dates";

describe("formatDate", () => {
  test("bare ISO dates format per style", () => {
    expect(formatDate("2026-07-03", "us")).toBe("Jul 3, 2026");
    expect(formatDate("2026-07-03", "international")).toBe("3 Jul 2026");
    expect(formatDate("2026-12-31", "us")).toBe("Dec 31, 2026");
  });

  test("timestamps format from the literal date — no timezone conversion, time dropped", () => {
    // A UTC-offset conversion could shift this to Jul 3 or Jul 5 depending on
    // the viewer's timezone; the written calendar day must win.
    expect(formatDate("2026-07-04T00:00:00-07:00", "us")).toBe("Jul 4, 2026");
    expect(formatDate("2026-07-03T20:00:48+00:00", "us")).toBe("Jul 3, 2026");
    expect(formatDate("2026-07-03T12:00:00Z", "international")).toBe("3 Jul 2026");
    expect(formatDate("2026-07-03 12:00:00", "us")).toBe("Jul 3, 2026");
    expect(formatDate("2026-07-03T12:00", "us")).toBe("Jul 3, 2026");
  });

  test("iso mode is a pass-through (null: caller renders as written)", () => {
    expect(formatDate("2026-07-03", "iso")).toBeNull();
    expect(formatDate("2026-07-03T12:00:00-07:00", "iso")).toBeNull();
  });

  test("non-date values are left alone", () => {
    expect(formatDate("released on 2026-07-03 at noon", "us")).toBeNull(); // embedded, not full-match
    expect(formatDate("flakes/okf/viz.ts", "us")).toBeNull();
    expect(formatDate("2026-13-01", "us")).toBeNull(); // month out of range
    expect(formatDate("2026-07-99", "us")).toBeNull(); // day out of range
    expect(formatDate(["2026-07-03"], "us")).toBeNull();
    expect(formatDate(42, "us")).toBeNull();
    expect(formatDate(undefined, "us")).toBeNull();
  });
});
