---
type: Pattern
title: Cross-OS Module Twins
description: A cross-platform feature is a twin pair — one module per class dir (modules/darwin/<name>.nix ↔ modules/nixos/<name>.nix) — with non-trivial shared text extracted to pure builders in lib/ and package lists kept in sync by hand.
resource: modules/darwin/tmux.nix
tags: [nix, darwin, nixos, cross-platform]
timestamp: '2026-07-03T12:00:00-07:00'
---

Since the [dual-OS unification](../decisions/nixos-darwin-unification.md) the
flake carries two deliberately parallel module classes —
`flake.modules.darwin.*` (`modules/darwin/`) and `flake.modules.nixos.*`
(`modules/nixos/`) — each blanket-imported wholesale by its hosts (see
[host-mounted modules](host-mounted-modules.md)). A cross-platform feature is
therefore a **twin pair**: one bare `<name>.nix` per class dir under the same
feature name — [tmux](../modules/tmux.md), [git](../modules/git.md),
[zsh](../modules/zsh.md), [neovim](../modules/neovim.md),
[ghostty](../modules/ghostty.md), [direnv](../modules/direnv.md),
[direnv-nom](../modules/direnv-nom.md),
[dotfiles-stow](../modules/dotfiles-stow.md), [gpg](../modules/gpg.md),
[pass](../modules/pass.md), [nh](../modules/nh.md). Why twins instead of one
OS-branching module: nix-darwin and NixOS have disjoint option trees, and each
class is imported wholesale per host, so a single shared module would need
pervasive conditionals and couple the two evaluations to each other.

How twins stay in sync without drifting:

- **Non-trivial shared text lives in `lib/` as pure builders**, imported by
  path — `lib/` sits outside `modules/` precisely so import-tree never treats
  the builders as flake-parts modules (see the
  [Dendritic layout](dendritic-modules.md)).
  [`lib/stow-restow-script.nix`](../../lib/stow-restow-script.nix) and
  [`lib/direnv-nom-wrapper.nix`](../../lib/direnv-nom-wrapper.nix) are the
  worked examples: the twins pass only the genuinely-per-OS arguments (home
  paths, `sudo -u k --set-home` vs `runuser` for running as the user, the stow
  skip lists) and the shared generator is what keeps a future fix from landing
  on only one OS. Trivial twins ([tmux](../modules/tmux.md)'s ~10-line
  `plugins.conf`) duplicate freely — extraction is for text worth sharing.
- **Generated files link per-OS** — each class has its own link mechanism
  (activation script on darwin, tmpfiles on nixos); full treatment in
  [store-path-embedding configs](store-path-configs.md).
- **Options are declared in both twins**: a behavior setting on a universal
  module (`programs.direnv-nom.diff`) carries an identical `lib.mkOption`
  declaration in each class, so either OS can be configured the same way.
- **Package lists sync by hand** — an explicit review point when touching
  either twin (AGENTS.md rule): adding a tool to one neovim twin's
  LSP/formatter list means mirroring it in the other.
- **The lib-extension asymmetry**: the darwin realiser hands modules an
  extended `nixpkgs.lib` (`lib.kanagawa`) via `specialArgs`; the nixos
  evaluation goes through snowglobe-lib's `mkNixosHost` and does **not** —
  nixos twins import `lib/` files by path (see
  [host registry realisers](host-registry-realisers.md)).
- **Content-level OS divergence inside shared stow packages** is handled at
  the file level, not by forking the package: ghostty's stowed config ends
  with `config-file = ?os.conf` and each twin generates its own OS half;
  git signing branches in-file via `includeIf gitdir:/Users/ | /home/`. See
  the [stow skip-lists decision](../decisions/stow-os-skip-lists.md).

Overlays follow the same both-OSes discipline: every host on both OSes applies
the whole `flake.overlays` set, so an overlay that only makes sense on one OS
must be internally platform-guarded
([`overlays/podman.nix`](../../overlays/podman.nix): darwin gets the prebuilt
remote client, Linux passes nixpkgs' podman through) or only add lazy attrs
the other OS never evaluates (the hyprland overlays).

Tradeoffs: two files per feature and manual package-list sync (drift risk)
buy zero conditionals in module bodies and independent evolution of each
class. The nixos class is currently all-universal (single Linux host) —
gating retrofit is deferred until a second NixOS host appears, per the
[unification decision](../decisions/nixos-darwin-unification.md).

## Citations

- darwin module: [`modules/darwin/tmux.nix`](../../modules/darwin/tmux.nix) ↔ NixOS module: [`modules/nixos/tmux.nix`](../../modules/nixos/tmux.nix)
- Shared builders: [`lib/stow-restow-script.nix`](../../lib/stow-restow-script.nix), [`lib/direnv-nom-wrapper.nix`](../../lib/direnv-nom-wrapper.nix)
- Dual-OS merge `76a05ff` (landed via PR #22, `0b8a629`); twin machinery ported in `0576bba`
