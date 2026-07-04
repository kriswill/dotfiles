// Shared fixtures for the viz-app test suite. Not a test file itself —
// `bun test` only picks up *.test.ts — and never bundled (only test files
// import it).
import type { ConceptNode } from "./data";
import type { SceneApi } from "./scene";

export const node = (id: string, type: string, title = id, extra: Partial<ConceptNode> = {}): ConceptNode => ({
  id,
  type,
  title,
  desc: "",
  fm: {},
  body: "",
  x: 0,
  y: 0,
  z: 0,
  ...extra,
});

/** Dotfiles-shaped raw viz config (TOML kebab spelling) for RawData.cfg —
 *  reproduces the pre-viz.toml hardcoded taxonomy/platform behavior. */
export const cfg = (over: Record<string, unknown> = {}) => ({
  taxonomy: {
    types: [
      "Darwin Module",
      "Nix Package",
      "Playbook",
      "Pattern",
      "Decision",
      "Host",
      "Sub-flake",
      "Flake-parts Module",
      "Neovim Config",
      "Neovim Plugin",
      "Overlay",
      "Reference",
    ],
    "group-order": ["Knowledge", "System", "Packages", "Neovim"],
    "dir-groups": {
      decisions: "Knowledge",
      patterns: "Knowledge",
      playbooks: "Knowledge",
      ".": "Knowledge",
      modules: "System",
      hosts: "System",
      packages: "Packages",
      nvim: "Neovim",
    },
  },
  platform: {
    values: ["darwin", "nixos"],
    "host-default": "darwin",
    types: {
      "Darwin Module": "darwin",
      "NixOS Module": "nixos",
      "Dual Module": "both",
      "Flake-parts Module": "both",
      "Neovim Plugin": "both",
      "Neovim Config": "both",
      Host: "hosts",
      "Nix Package": "packages",
      "Sub-flake": "packages",
      Overlay: "packages",
    },
    hosts: { nebula: "nixos" },
    "nix-guards": { darwin: "darwin", linux: "nixos" },
  },
  ...over,
});

/** Recording stand-in for the WebGL GraphScene. */
export interface StubScene extends SceneApi {
  calls: [string, ...unknown[]][];
  dimFn: ((i: number) => boolean) | null;
}

export const makeStub = (): StubScene => {
  const s: StubScene = {
    calls: [],
    dimFn: null,
    setDim(fn) {
      s.dimFn = fn;
      s.calls.push(["setDim"]);
    },
    setSelected(i, fly) {
      s.calls.push(["setSelected", i, fly]);
    },
    applyTheme() {
      s.calls.push(["applyTheme"]);
    },
    setViewShift(px) {
      s.calls.push(["setViewShift", px]);
    },
    resize() {},
  };
  return s;
};
