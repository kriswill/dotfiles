import { describe, expect, test } from "bun:test";
import { displayName, normalizeVizConfig, VizConfigError } from "./config";

/** A dotfiles-shaped raw config in TOML (kebab-case) spelling, with two
 *  facets exercising every FacetConfig field (incl. nested nulls both ways:
 *  platform has nix-packages but no frontmatter, status the reverse). */
const rawCfg = () => ({
  bundle: { dir: "knowledge", out: "viz.html" },
  display: {
    title: "OKF knowledge graph",
    badge: "OKF viz",
    "fallback-name": "knowledge/",
    "about-html": "<b>about</b>",
  },
  embed: { "max-bytes": 100 },
  taxonomy: {
    types: ["Darwin Module", "Decision"],
    "group-order": ["Knowledge", "System"],
    "dir-groups": { decisions: "Knowledge", modules: "System" } as Record<string, string>,
  },
  facet: {
    platform: {
      values: ["macos", "linux"],
      types: { "Darwin Module": "macos", "NixOS Module": "linux", Host: "macos" } as Record<string, string>,
      ids: { "hosts/nebula": "linux" } as Record<string, string>,
      "nix-packages": {
        file: "modules/packages.nix",
        guards: { darwin: "macos", linux: "linux" } as Record<string, string>,
        types: ["Nix Package"],
      },
    },
    status: {
      frontmatter: "status",
    },
  },
});

describe("normalizeVizConfig", () => {
  test("empty/undefined input yields generic defaults", () => {
    for (const raw of [undefined, null, {}]) {
      const c = normalizeVizConfig(raw);
      expect(c.bundle).toEqual({ dir: "knowledge", out: "viz.html" });
      expect(c.display.badge).toBe("OKF viz");
      expect(c.display.fallbackName).toBe("OKF bundle");
      expect(c.display.name).toBeNull();
      expect(c.display.aboutHtml).toContain("Open Knowledge Format");
      expect(c.embed.maxBytes).toBe(200_000);
      expect(c.taxonomy).toEqual({ types: [], dirGroups: {}, groupOrder: [], other: "Other" });
      expect(c.facets).toEqual([]);
      expect(c.repo.url).toBeNull();
    }
  });

  test("kebab-case TOML keys map to camelCase config", () => {
    const c = normalizeVizConfig(rawCfg(), { strict: true });
    expect(c.display.fallbackName).toBe("knowledge/");
    expect(c.display.aboutHtml).toBe("<b>about</b>");
    expect(c.embed.maxBytes).toBe(100);
    expect(c.taxonomy.groupOrder).toEqual(["Knowledge", "System"]);
    expect(c.taxonomy.dirGroups).toEqual({ decisions: "Knowledge", modules: "System" });
    expect(c.facets).toHaveLength(2);
    expect(c.facets[0]).toEqual({
      name: "platform",
      values: ["macos", "linux"],
      types: { "Darwin Module": "macos", "NixOS Module": "linux", Host: "macos" },
      ids: { "hosts/nebula": "linux" },
      frontmatter: null,
      nixPackages: { file: "modules/packages.nix", guards: { darwin: "macos", linux: "linux" }, types: ["Nix Package"] },
    });
    expect(c.facets[1]).toEqual({
      name: "status",
      values: [],
      types: {},
      ids: {},
      frontmatter: "status",
      nixPackages: null,
    });
  });

  test("facet declaration order (TOML file order) is preserved", () => {
    const c = normalizeVizConfig(rawCfg(), { strict: true });
    expect(c.facets.map((f) => f.name)).toEqual(["platform", "status"]);
  });

  test("idempotent: normalizing a JSON round-trip of its own output is identity", () => {
    const once = normalizeVizConfig(rawCfg(), { strict: true });
    expect(normalizeVizConfig(JSON.parse(JSON.stringify(once)))).toEqual(once);
    expect(normalizeVizConfig(JSON.parse(JSON.stringify(once)), { strict: true })).toEqual(once);
  });

  test("strict: unknown keys error with their path", () => {
    expect(() => normalizeVizConfig({ dsiplay: {} }, { strict: true })).toThrow(/dsiplay: unknown key/);
    expect(() => normalizeVizConfig({ display: { bagde: "x" } }, { strict: true })).toThrow(
      /display\.bagde: unknown key/,
    );
    expect(() => normalizeVizConfig({ facet: { platform: { bogus: 1 } } }, { strict: true })).toThrow(
      /facet\.platform\.bogus: unknown key/,
    );
  });

  test("strict: type mismatches error; lenient keeps defaults", () => {
    expect(() => normalizeVizConfig({ embed: { "max-bytes": "big" } }, { strict: true })).toThrow(VizConfigError);
    expect(normalizeVizConfig({ embed: { "max-bytes": "big" } }).embed.maxBytes).toBe(200_000);
  });

  test('"both" is now a legal ordinary facet value — no reserved rule sentinels', () => {
    const c = normalizeVizConfig(
      { facet: { platform: { values: ["both", "macos"], types: { "Dual Module": "both" } } } },
      { strict: true },
    );
    expect(c.facets[0]!.values).toEqual(["both", "macos"]);
    expect(c.facets[0]!.types).toEqual({ "Dual Module": "both" });
  });

  test('strict: reserved facet value "all" rejected', () => {
    expect(() => normalizeVizConfig({ facet: { platform: { values: ["macos", "all"] } } }, { strict: true })).toThrow(
      /"all" is reserved/,
    );
  });

  test("strict: facet.values duplicates/empty rejected", () => {
    expect(() =>
      normalizeVizConfig({ facet: { platform: { values: ["macos", "macos"] } } }, { strict: true }),
    ).toThrow(/facet\.platform\.values: duplicate/);
    expect(() => normalizeVizConfig({ facet: { platform: { values: ["macos", ""] } } }, { strict: true })).toThrow(
      /facet\.platform\.values: empty string/,
    );
  });

  test("strict: facet name must match ^[a-z][a-z0-9-]*$", () => {
    expect(() => normalizeVizConfig({ facet: { Platform: {} } }, { strict: true })).toThrow(/name must match/);
    expect(() => normalizeVizConfig({ facet: { "1nvalid": {} } }, { strict: true })).toThrow(/name must match/);
    expect(() => normalizeVizConfig({ facet: { "with_underscore": {} } }, { strict: true })).toThrow(
      /name must match/,
    );
  });

  test("strict: reserved facet names rejected (hash-param collisions)", () => {
    for (const name of ["hide", "q", "isolate", "os", "all"]) {
      expect(() => normalizeVizConfig({ facet: { [name]: {} } }, { strict: true })).toThrow(/reserved name/);
    }
  });

  test("strict: duplicate facet names rejected (array shape)", () => {
    expect(() =>
      normalizeVizConfig({ facets: [{ name: "platform" }, { name: "platform" }] }, { strict: true }),
    ).toThrow(/duplicate facet names/);
  });

  test("strict: facet (table) and facets (array) are mutually exclusive", () => {
    expect(() =>
      normalizeVizConfig({ facet: { platform: {} }, facets: [{ name: "platform" }] }, { strict: true }),
    ).toThrow(/cannot specify both/);
  });

  test("strict: dangling facet.types / ids / nix-packages.guards refs rejected", () => {
    const base = () => ({
      facet: {
        platform: {
          values: ["macos", "linux"],
          types: {} as Record<string, string>,
          ids: {} as Record<string, string>,
          "nix-packages": { file: "modules/packages.nix", guards: {} as Record<string, string>, types: ["Nix Package"] },
        },
      },
    });
    const b1 = base();
    b1.facet.platform.types["Windows Module"] = "windows";
    expect(() => normalizeVizConfig(b1, { strict: true })).toThrow(/facet\.platform\.types\."Windows Module"/);
    const b2 = base();
    b2.facet.platform.ids["hosts/bsd"] = "bsd";
    expect(() => normalizeVizConfig(b2, { strict: true })).toThrow(/facet\.platform\.ids\."hosts\/bsd"/);
    const b3 = base();
    b3.facet.platform["nix-packages"].guards["win"] = "windows";
    expect(() => normalizeVizConfig(b3, { strict: true })).toThrow(/facet\.platform\.nix-packages\.guards\.win/);
  });

  test("strict: nix-packages requires file/guards/types", () => {
    expect(() =>
      normalizeVizConfig({ facet: { platform: { values: ["macos"], "nix-packages": {} } } }, { strict: true }),
    ).toThrow(/nix-packages\.file: required/);
    expect(() =>
      normalizeVizConfig(
        { facet: { platform: { values: ["macos"], "nix-packages": { file: "x.nix" } } } },
        { strict: true },
      ),
    ).toThrow(/nix-packages\.guards: required/);
    expect(() =>
      normalizeVizConfig(
        { facet: { platform: { values: ["macos"], "nix-packages": { file: "x.nix", guards: { a: "macos" } } } } },
        { strict: true },
      ),
    ).toThrow(/nix-packages\.types: required/);
  });

  test("strict: nix-packages.file path escape rejected", () => {
    expect(() =>
      normalizeVizConfig(
        {
          facet: {
            platform: {
              values: ["macos"],
              "nix-packages": { file: "/etc/passwd", guards: { a: "macos" }, types: ["X"] },
            },
          },
        },
        { strict: true },
      ),
    ).toThrow(/nix-packages\.file: must be a relative path/);
  });

  test("strict: a rule-less facet with values warns (no-op lens)", () => {
    const warnings: string[] = [];
    normalizeVizConfig(
      { facet: { platform: { values: ["macos", "linux"] } } },
      { strict: true, warn: (m) => warnings.push(m) },
    );
    expect(warnings.join()).toContain("no resolution rule");
  });

  test("strict: dir-groups referencing a group missing from group-order rejected", () => {
    const base = rawCfg();
    base.taxonomy["dir-groups"].nvim = "Neovim";
    expect(() => normalizeVizConfig(base, { strict: true })).toThrow(/nvim.*Neovim.*group-order/s);
  });

  test("strict: path escapes rejected", () => {
    expect(() => normalizeVizConfig({ bundle: { dir: "../elsewhere" } }, { strict: true })).toThrow(/bundle\.dir/);
  });

  test("strict: duplicate taxonomy.types / group-order entries rejected", () => {
    expect(() => normalizeVizConfig({ taxonomy: { types: ["A", "B", "A"] } }, { strict: true })).toThrow(
      /taxonomy\.types: duplicate/,
    );
    expect(() => normalizeVizConfig({ taxonomy: { "group-order": ["G", "G"] } }, { strict: true })).toThrow(
      /taxonomy\.group-order: duplicate/,
    );
  });

  test("path fields drop trailing slashes; '' unsets nullable overrides", () => {
    const c = normalizeVizConfig(
      {
        bundle: { dir: "kb/" },
        display: { name: "" },
        repo: { url: "" },
        facet: { platform: { values: ["x"], "nix-packages": { file: "pkgs.nix/", guards: { a: "x" }, types: ["T"] } } },
      },
      { strict: true },
    );
    expect(c.bundle.dir).toBe("kb");
    expect(c.display.name).toBeNull();
    expect(c.repo.url).toBeNull();
    expect(c.facets[0]!.nixPackages!.file).toBe("pkgs.nix");
  });

  test("strict: >12 taxonomy types warns but does not throw", () => {
    const warnings: string[] = [];
    const types = Array.from({ length: 13 }, (_, i) => "T" + i);
    const c = normalizeVizConfig({ taxonomy: { types } }, { strict: true, warn: (m) => warnings.push(m) });
    expect(c.taxonomy.types).toHaveLength(13);
    expect(warnings.join()).toContain("12 palette slots");
  });
});

describe("displayName", () => {
  const cfg = (over: Record<string, unknown> = {}) => normalizeVizConfig({ display: over });
  test("config name overrides git-derived name", () => {
    expect(displayName(cfg({ name: "my/repo" }), "kriswill/dotfiles")).toBe("my/repo");
  });
  test("falls back to git-derived name, then fallback-name", () => {
    expect(displayName(cfg(), "kriswill/dotfiles")).toBe("kriswill/dotfiles");
    expect(displayName(cfg(), null)).toBe("OKF bundle");
    expect(displayName(cfg({ "fallback-name": "knowledge/" }), null)).toBe("knowledge/");
  });
  test("an empty-string name override means 'derive', not a blank header", () => {
    expect(displayName(cfg({ name: "" }), "kriswill/dotfiles")).toBe("kriswill/dotfiles");
  });
});
