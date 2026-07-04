import { describe, expect, test } from "bun:test";
import { displayName, normalizeVizConfig, VizConfigError } from "./config";

/** A dotfiles-shaped raw config in TOML (kebab-case) spelling. */
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
  platform: {
    values: ["darwin", "nixos"],
    "packages-nix": "modules/packages.nix",
    "host-default": "darwin",
    "nix-guards": { darwin: "darwin", linux: "nixos" },
    types: { "Darwin Module": "darwin", Host: "hosts", "Nix Package": "packages", Decision: "neutral" } as Record<
      string,
      string
    >,
    hosts: { nebula: "nixos" },
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
      expect(c.platform.values).toEqual([]);
      expect(c.platform.packagesNix).toBeNull();
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
    expect(c.platform.packagesNix).toBe("modules/packages.nix");
    expect(c.platform.hostDefault).toBe("darwin");
    expect(c.platform.nixGuards).toEqual({ darwin: "darwin", linux: "nixos" });
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
  });

  test("strict: type mismatches error; lenient keeps defaults", () => {
    expect(() => normalizeVizConfig({ embed: { "max-bytes": "big" } }, { strict: true })).toThrow(VizConfigError);
    expect(normalizeVizConfig({ embed: { "max-bytes": "big" } }).embed.maxBytes).toBe(200_000);
  });

  test("strict: reserved platform value names rejected", () => {
    expect(() => normalizeVizConfig({ platform: { values: ["darwin", "both"] } }, { strict: true })).toThrow(
      /"both" is reserved/,
    );
  });

  test("strict: dangling platform.types / hosts / host-default refs rejected", () => {
    const base = rawCfg();
    base.platform.types["Windows Module"] = "windows";
    expect(() => normalizeVizConfig(base, { strict: true })).toThrow(/Windows Module/);
    const base2 = rawCfg();
    base2.platform.hosts.nebula = "bsd";
    expect(() => normalizeVizConfig(base2, { strict: true })).toThrow(/hosts\.nebula/);
    const base3 = rawCfg();
    base3.platform["host-default"] = "bsd";
    expect(() => normalizeVizConfig(base3, { strict: true })).toThrow(/host-default/);
  });

  test("strict: platform rules without values rejected", () => {
    expect(() =>
      normalizeVizConfig({ platform: { types: { Host: "hosts" } } }, { strict: true }),
    ).toThrow(/platform\.values: required/);
  });

  test("strict: dir-groups referencing a group missing from group-order rejected", () => {
    const base = rawCfg();
    base.taxonomy["dir-groups"].nvim = "Neovim";
    expect(() => normalizeVizConfig(base, { strict: true })).toThrow(/nvim.*Neovim.*group-order/s);
  });

  test("strict: path escapes rejected", () => {
    expect(() => normalizeVizConfig({ bundle: { dir: "../elsewhere" } }, { strict: true })).toThrow(/bundle\.dir/);
    const base = rawCfg();
    base.platform["packages-nix"] = "/etc/passwd";
    expect(() => normalizeVizConfig(base, { strict: true })).toThrow(/packages-nix/);
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
        platform: { values: ["x"], "packages-nix": "pkgs.nix/", "host-default": "" },
      },
      { strict: true },
    );
    expect(c.bundle.dir).toBe("kb");
    expect(c.display.name).toBeNull();
    expect(c.repo.url).toBeNull();
    expect(c.platform.packagesNix).toBe("pkgs.nix");
    expect(c.platform.hostDefault).toBeNull();
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
