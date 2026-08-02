---
type: Dual Module
title: Devenv
description: 'devenv.sh''s Nix developer-environment CLI on both OSes; cd auto-activation comes from devenv 2.1''s native zsh hook in the stowed integrations.zsh, not direnv.'
resource: modules/darwin/devenv.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-08-01T18:07:17-07:00'
---

The module itself only installs `pkgs.devenv` — all integration lives in the
stow tree: `home/zsh/.config/zsh/integrations.zsh` runs a guarded
`eval "$(devenv hook zsh)"` right after the [direnv](direnv.md) hook (same
`command -v` guard idiom). The hook registers a `precmd` function; entering a
project trusted via `devenv allow` **spawns a nested `devenv shell`** (the
libghostty-backed VT introduced in devenv 2.1) rather than diff-exporting env
into the outer shell, and cd-ing outside `DEVENV_ROOT` exits that subshell,
handing the target directory back to the parent via
`.devenv/exit-dir`. No `.envrc` is involved (`devenv init` since 2.1 no
longer generates one); the environment re-evaluates in the background on file
changes and applies at the next prompt.

Deliberately NOT wired through direnv — see the
[decision record](../decisions/devenv-native-hook-over-direnv.md): devenv's
direnvrc redefines nix-direnv helper functions with different bodies, so it
cannot share `~/.config/direnv/lib` with `nix-direnv.sh`. The two hooks
coexist: direnv keeps owning `use flake` projects, devenv only claims
directories explicitly allowed.

Gotcha: activation is prompt-driven (precmd), so non-interactive shells never
auto-activate — agents and scripts use `devenv shell -- <cmd>` explicitly.

## Twin differences

None — both classes are the same one-line package install; see the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).

Mounted ungated on every host of both classes
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/devenv.nix`](../../modules/darwin/devenv.nix)
- NixOS module: [`modules/nixos/devenv.nix`](../../modules/nixos/devenv.nix)
- Shell hook: [`home/zsh/.config/zsh/integrations.zsh`](../../home/zsh/.config/zsh/integrations.zsh) — see the [stow tree pattern](../patterns/stow-tree.md)

## Citations

- [devenv.sh getting started](https://devenv.sh/getting-started/)
- [devenv 2.1 announcement — native zsh/fish/nushell shells + `devenv hook`](https://devenv.sh/blog/2026/05/07/devenv-21-nix-with-zsh-fish-and-nushell-via-libghostty/)
- [nixpkgs `devenv` package](https://mynixos.com/nixpkgs/package/devenv)
