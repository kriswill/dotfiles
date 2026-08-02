# Agent Guidelines — modules/ & the Nix Layer

Every `.nix` file under `modules/` is auto-discovered by `import-tree` as a
flake-parts module — no manual imports; prefix a path component with `_` to
exclude it (e.g. `yazi/_themes/`). **`git add` new files before `nix build`**
— flakes only see git-tracked files. This file holds the Nix code style and
the cross-dir wiring walkthroughs; the sibling dirs modules/ wires up carry
their own local conventions in `pkgs/AGENTS.md`, `overlays/AGENTS.md`, and
`flakes/AGENTS.md` (`lib/` is documented below).

## Code Style - Nix

- **Module pattern:** two deliberately parallel classes, one per OS —
  `flake.modules.darwin.<name>` (`modules/darwin/`) and
  `flake.modules.nixos.<name>` (`modules/nixos/`). Hosts blanket-import their
  whole class: universal modules are ungated; darwin host-selective ones gate
  behind `programs.<name>.enable` / `services.<name>.enable` (the nixos class
  is all-universal today — single host). Config for exactly one machine goes
  beside that host's registration in `modules/hosts/` instead. Full
  walkthrough: "Adding a New Module" below.
- **Cross-platform twins:** a feature on both OSes gets a module in each class
  dir (`modules/darwin/git.nix` ↔ `modules/nixos/git.nix`); keep the twins'
  package lists in sync; share generated-file text via `lib/`.
- **Idioms:** `inherit` for destructuring; package lists via
  `builtins.attrValues { inherit (pkgs) ...; }`.
- **Overrides:** universal modules mark override-prone scalars `lib.mkDefault`;
  hosts override anything else with `lib.mkForce`.
- **Files embedding /nix/store paths** can't live in the stow tree — the
  feature's module generates them (darwin: activation script; nixos:
  `systemd.tmpfiles.rules` — see the tmux twins).
- **Overlays** apply to every host on both OSes — a one-OS overlay must be
  internally platform-guarded (`overlays/podman.nix`) or only ADD lazy attrs
  the other OS never evaluates.
- **Unfree** is off by default; darwin allows per-package via
  `allowUnfreePredicate` in `modules/darwin/core.nix`; nebula's policy comes
  from snowglobe-lib profiles.

## Adding a New Module

1. Create a bare `<name>.nix` in `modules/darwin/` or `modules/nixos/` defining
   `flake.modules.<class>.<name>` (a directory only when bundling adjacent
   config files). Universal: no options, no `lib.mkIf`. Darwin host-selective:
   gate behind `programs.<name>.enable` / `services.<name>.enable`
   (`lib.mkEnableOption` + `lib.mkIf`; see `modules/darwin/podman-desktop.nix`)
   and flip it in each wanting host's `modules/hosts/<hostname>/default.nix`.
2. Cross-platform feature? Add the twin in the other class dir; share generated
   file text via `lib/` if non-trivial.
3. Config that only ever applies to one machine (fixed IPs, hardware quirks)
   skips the class dirs entirely: put it in a file beside that host's
   registration merging into `configurations.<class>.<hostname>.module`.

## Adding a Custom Package

1. Create `pkgs/<name>.nix` (or `pkgs/<name>/package.nix`)
2. Add `<name> = pkgs.callPackage ../pkgs/<name>.nix { };` to
   `perSystem.packages` in `modules/packages.nix` — under the right platform
   guard (`lib.optionalAttrs`) if it only builds on one OS
3. To make it available to hosts, create `overlays/<name>.nix` and register it
   in `modules/overlays.nix` (`flake.overlays.<name>`)
4. If unfree: add a `nixpkgs.config.allowUnfreePredicate` entry in
   `modules/darwin/core.nix`

## Adding a Custom Package as a Sub-flake (extraction pattern)

For a package that warrants its own flake — forked/patched source,
standalone-buildable, or destined to become a separate repo — put it under
`flakes/<name>/` instead of `pkgs/`:

1. Create `flakes/<name>/{flake.nix,package.nix,…}`. `flake.nix` uses
   flake-parts and exposes `packages.<system>.<name>` (+ `default`).
   **`git add` it** — sub-flake files must be git-tracked to be seen.
2. Add a relative-path input in the root `flake.nix`:
   `inputs.<name>.url = "./flakes/<name>";` with
   `inputs.<name>.inputs.{nixpkgs,flake-parts}.follows` to dedupe nixpkgs.
3. Re-export in `modules/packages.nix`:
   `<name> = inputs.<name>.packages.${system}.<name>;`.
4. If a host needs it on `pkgs`, add an **inline** overlay in
   `modules/overlays.nix` (which receives `inputs`).

Later extraction to a separate repo is just swapping the input URL
`"./flakes/<name>"` → `"github:owner/<name>"`. See `flakes/ccglass/` for a
worked example.

## Custom Library Functions (`lib/`)

Pure helpers live in `lib/` (the `kanagawa` palette via `lib/default.nix`, plus
standalone builder files like `lib/direnv-nom-wrapper.nix` imported by path) —
outside `modules/` so import-tree skips them. `modules/darwin.nix` extends
`nixpkgs.lib` with `lib/default.nix` and hands the result to the darwin
evaluation via specialArgs, so darwin modules reach them as `lib.kanagawa`.
The nixos evaluation goes through snowglobe-lib's `mkNixosHost` and does NOT
get the extended lib — nixos modules import lib files by path when needed.

## Secrets (sops-nix)

- Recipients and creation rules: `.sops.yaml` (repo root). Every host's age
  identity is derived from its SSH host key — on a new machine run
  `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub` and add an anchor + rule.
- Secrets files: `modules/hosts/<host>/secrets.yaml`, edited with
  `sops modules/hosts/<host>/secrets.yaml` (tools in the dev shell).
- Machinery: darwin imports `sops-nix.darwinModules.sops` via
  `modules/darwin/sops.nix`; nebula gets the NixOS module via snowglobe-lib.
  A host consumes secrets with `sops.defaultSopsFile` + `sops.secrets.<name>`.
- git commit signing is NOT gpg: it's SSH-format signing through the 1Password
  agent, OS-branched inside `home/git/.config/git/config` via
  `includeIf gitdir:/Users/ | /home/`. gpg-agent (both OSes) only backs `pass`
  and ad-hoc gpg; `enableSSHSupport` stays false.
