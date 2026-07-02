# Log

## 2026-07-02

- **Update** — `okf viz` rebuilt as a 3D orbit view in the style of
  codebase-memory-mcp's graph-ui: Three.js instanced glow spheres + bloom,
  frozen generation-time layout (`scripts/okf/layout3d.ts`), viewer app in
  `scripts/okf/viz-app/` bundled by bun into the single offline page.

- **Update** — `okf viz` now embeds every referenced source file
  (syntax-highlighted at generation time); `resource:` paths and repo-file
  links in the detail panel open an in-panel code preview with metadata and
  referencing concepts.

- **Update** — `okf` is now a dev-shell command (a `writeShellApplication`
  wrapper in `modules/dev.nix` that resolves the live checkout via git);
  [dev](modules/dev.md) and the [OKF Profile](okf-profile.md) tooling section
  updated to match.

- **Creation** — Bundle created as an OKF v0.1 proof of concept. Seeded with 5
  pattern docs, 6 decision records, 6 playbooks, and 45 scaffolded catalog
  stubs (modules, hosts, packages, sub-flakes). Tooling lives in
  `scripts/okf/` (`scaffold` / `index` / `validate` / `viz`); conventions in
  [okf-profile.md](okf-profile.md).
