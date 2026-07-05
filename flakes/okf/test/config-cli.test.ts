// Unit tests for config-cli.ts's pure section splitter — the build-side
// normalizer for CLI-only okf.toml sections ([profile], later [vcs]/
// [scaffold]/[index]). loadContext() itself (fs + git) is exercised by the
// repo's own battery (okf validate/index/viz), not here.

import { describe, expect, test } from "bun:test";
import { OkfConfigError, splitCliSections } from "../config-cli";

describe("splitCliSections: [profile]", () => {
  test("absent config -> exact defaults", () => {
    const { profile } = splitCliSections({});
    expect(profile).toEqual({
      requiredFields: ["type"],
      recommendedFields: ["title", "description", "timestamp"],
      reservedFiles: ["index.md", "log.md"],
      rootedLinks: "error",
      repoLinks: "check",
    });
  });

  test("non-table top level passes through for the viz normalizer to reject", () => {
    for (const raw of [undefined, null, "nope", 42, ["a"]]) {
      const { profile, rest } = splitCliSections(raw);
      expect(rest).toBe(raw);
      expect(profile.requiredFields).toEqual(["type"]);
    }
  });

  test("kebab and camel spellings both accepted (idempotent re-normalization)", () => {
    const kebab = splitCliSections({
      profile: { "required-fields": ["type", "title"], "rooted-links": "allow" },
    });
    const camel = splitCliSections({
      profile: { requiredFields: ["type", "title"], rootedLinks: "allow" },
    });
    expect(kebab.profile).toEqual(camel.profile);
    expect(kebab.profile.requiredFields).toEqual(["type", "title"]);
    expect(kebab.profile.rootedLinks).toBe("allow");
  });

  test("'type' is always enforced — prepended when a config omits it", () => {
    const { profile } = splitCliSections({ profile: { "required-fields": ["title"] } });
    expect(profile.requiredFields).toEqual(["type", "title"]);
  });

  test("profile section is consumed; other sections pass through untouched", () => {
    const { rest } = splitCliSections({
      profile: { "repo-links": "ignore" },
      bundle: { dir: "kb" },
      display: { title: "T" },
    });
    expect(rest).toEqual({ bundle: { dir: "kb" }, display: { title: "T" } });
  });

  test("null section (JSON round-trip of unset) keeps defaults", () => {
    const { profile } = splitCliSections({ profile: null });
    expect(profile.repoLinks).toBe("check");
  });

  test("unknown key fails with its path", () => {
    expect(() => splitCliSections({ profile: { "reserved-file": ["x.md"] } })).toThrow(OkfConfigError);
    expect(() => splitCliSections({ profile: { "reserved-file": ["x.md"] } })).toThrow(/profile\.reserved-file: unknown key/);
  });

  test("bad enum value fails with the allowed set", () => {
    expect(() => splitCliSections({ profile: { "repo-links": "verify" } })).toThrow(/expected one of: check, ignore, forbid/);
    expect(() => splitCliSections({ profile: { "rooted-links": true } })).toThrow(/expected one of: error, allow/);
  });

  test("non-string / empty-string array entries fail", () => {
    expect(() => splitCliSections({ profile: { "reserved-files": ["index.md", ""] } })).toThrow(/non-empty strings/);
    expect(() => splitCliSections({ profile: { "required-fields": "type" } })).toThrow(/profile\.required-fields/);
  });

  test("profile as a non-table fails", () => {
    expect(() => splitCliSections({ profile: "strict" })).toThrow(/profile: expected a table/);
  });

  test("every error is reported at once", () => {
    try {
      splitCliSections({ profile: { "rooted-links": "nope", bogus: 1 } });
      expect.unreachable();
    } catch (e) {
      const msg = (e as Error).message;
      expect(msg).toContain("profile.rooted-links");
      expect(msg).toContain("profile.bogus: unknown key");
    }
  });
});

describe("splitCliSections: [vcs] (mixed section)", () => {
  test("defaults: provider auto, no ignore globs", () => {
    const { vcs } = splitCliSections({});
    expect(vcs).toEqual({ provider: "auto", ignore: [] });
  });

  test("provider/ignore consumed; viewer keys stay in rest for the viz normalizer", () => {
    const { vcs, rest } = splitCliSections({
      vcs: {
        provider: "none",
        ignore: ["dist/**", "*.log"],
        url: "https://codeberg.org/o/r",
        "commit-url-template": "{url}/commit/{hash}",
      },
    });
    expect(vcs.provider).toBe("none");
    expect(vcs.ignore).toEqual(["dist/**", "*.log"]);
    expect(rest).toEqual({
      vcs: { url: "https://codeberg.org/o/r", "commit-url-template": "{url}/commit/{hash}" },
    });
  });

  test("bad provider / bad ignore fail with paths", () => {
    expect(() => splitCliSections({ vcs: { provider: "p4" } })).toThrow(/vcs\.provider: expected one of: auto, git, none/);
    expect(() => splitCliSections({ vcs: { ignore: "dist" } })).toThrow(/vcs\.ignore/);
  });
});
