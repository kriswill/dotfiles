# nebula — NixOS configuration

A [NixOS](https://nixos.org) flake that defines the system configuration for the
host **`nebula`** — an AMD CPU / NVIDIA GPU UEFI desktop running Wayland
(niri + Hyprland). It is built on top of
[`snowglobe-lib`](https://codeberg.org/earthgman/snowglobe-lib), which supplies
the host builder and a large set of ready-made profiles and desktop modules, and
it is organised with the **dendritic pattern**
([flake-parts](https://flake.parts) + [`import-tree`](https://github.com/vic/import-tree)).

> This is the `nebula` host branch of a personal dotfiles repo. It has
> independent history from `main` (which holds the cross-host macOS / nix-darwin
> configuration). Both branches share the same dendritic layout.

## What's in the box

| Area | Choice |
|---|---|
| Hardware | AMD CPU, NVIDIA GPU (RTX 5080, open kernel modules), UEFI, single NVMe (ext4 + ESP via [disko](https://github.com/nix-community/disko)) |
| Compositors | [niri](https://github.com/YaLTeR/niri) and [Hyprland](https://hyprland.org) (HDR-focused — see [`docs/`](docs/)) |
| Login | `ly` greeter; default session `hyprland-uwsm` |
| snowglobe profiles | `hacker-mode`, `gaming`, `office`, `hardware-tools`, `nix-tools`, `harden` |
| Secrets | [sops-nix](https://github.com/Mic92/sops-nix), `age`-encrypted |
| Dotfiles | user configs under `~/.config` managed with [GNU Stow](https://www.gnu.org/software/stow/) |
| Custom packages | `helium` (browser), `wowup` (WoW addon manager), `dots-adopt` (capture helper) |

## Architecture

The flake is **dendritic**: `flake.nix`'s entire `outputs` is

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
```

`import-tree` recursively discovers **every `.nix` file under `modules/`** and
hands each to flake-parts as a module. There is no central `imports = [ … ]` list
to maintain — dropping a file into `modules/` wires it in. Definitions are
exposed through flake-parts outputs (`flake.nixosConfigurations`,
`flake.overlays`, `flake.modules.nixos.*`, per-system `packages`).

Two registries do the assembly:

- **`flake.modules.nixos.<name>`** — shared, always-on feature modules. Each file
  in `modules/nixos/` is `{ flake.modules.nixos.<name> = <nixos module>; }`. The
  host pulls them all in with `builtins.attrValues config.flake.modules.nixos`.
- **`configurations.nixos.<host>`** — the host registry (declared in
  `modules/nixos.nix`). Each entry holds hardware metadata plus a `module` of type
  `deferredModule`. `modules/nixos.nix` maps every entry through
  `snowglobe-lib`'s `mkNixosHost` into `flake.nixosConfigurations.<host>` (plus a
  `flake.checks` build check).

Because `module` is a `deferredModule`, **host-specific config is split across
ordinary first-class files** that each *merge* into the host:

```nix
# modules/hosts/nebula/configuration.nix
{ configurations.nixos.nebula.module = { /* normal NixOS module */ }; }
```

So `configuration.nix`, `disko.nix`, `hardware-configuration.nix`, `users/k`, …
all live under `modules/hosts/nebula/` as normal dendritic files and combine into
one host — no path exclusions and no hand-maintained imports list.
(`hardware-configuration.nix` is wrapped in this same form; if you regenerate it
with `nixos-generate-config`, re-apply the two-line wrapper noted at the top of
the file.)

### Build flow

```
flake.nix
  └─ flake-parts.lib.mkFlake (import-tree ./modules)
       ├─ modules/flake-parts.nix     enables flake.modules.<class>.<name>; systems
       ├─ modules/nixos/*.nix         → flake.modules.nixos.*           (shared features)
       ├─ modules/hosts/nebula.nix    → configurations.nixos.nebula     (metadata + baseline)
       ├─ modules/hosts/nebula/*.nix  → configurations.nixos.nebula.module  (host config, merged)
       ├─ modules/overlays.nix        → flake.overlays
       ├─ modules/packages.nix        → perSystem packages
       └─ modules/nixos.nix           configurations.nixos.* ──mkNixosHost──▶ flake.nixosConfigurations.nebula
```

### Repository layout

```
.
├── flake.nix                       # mkFlake (import-tree ./modules)
├── modules/
│   ├── flake-parts.nix             # flake-parts wiring + systems
│   ├── nixos.nix                   # host realizer (registry → nixosConfigurations + checks)
│   ├── overlays.nix                # flake.overlays
│   ├── packages.nix                # per-system packages
│   ├── nixos/                      # shared feature modules → flake.modules.nixos.*
│   │   ├── dotfiles-stow.nix  gtk-dark.nix  keyring.nix  libreoffice-paths.nix
│   │   └── neovim.nix  node-runtime.nix  tmux.nix  zsh.nix
│   └── hosts/
│       ├── nebula.nix              # host registration + shared baseline
│       └── nebula/                 # host-specific config (first-class dendritic files)
│           ├── configuration.nix   disko.nix  hardware-configuration.nix
│           ├── console-quiet.nix   ly.nix  sudo-1password.nix
│           ├── windows-mount.nix   flatpak-repo-network.nix
│           ├── users/k/default.nix
│           └── secrets.yaml  *.pub # non-.nix → ignored by import-tree
├── home/                           # GNU Stow tree mirroring $HOME (niri, ghostty, nvim, …)
├── packages/                       # custom callPackage derivations
├── docs/                           # task-focused reference manuals
├── CLAUDE.md                       # guidance for the Claude Code agent
└── .sops.yaml                      # sops creation rules (age recipients)
```

## Usage

Requires Nix with flakes enabled. All commands run from the repo checkout.

> **Path gotcha:** `nixos-rebuild --flake <path>` does not follow a path that is
> itself a symlink. `cd` into the real checkout first so `.` resolves correctly,
> then use `.#nebula` (or pass the real absolute path). `--flake /etc/nixos#nebula`
> fails when `/etc/nixos` is a symlink.

```sh
cd /etc/nixos          # or the real checkout, e.g. ~/src/github/<owner>/dotfiles

# Rebuild and switch the running system
sudo nixos-rebuild switch --flake .#nebula

# Build for the next boot without activating
sudo nixos-rebuild boot --flake .#nebula

# Dry build — quickest way to typecheck a change (no activation, no GC root)
nixos-rebuild build --flake .#nebula

# Evaluate the whole flake / surface errors
nix flake check

# Update inputs (nixpkgs is pinned via snowglobe-lib)
nix flake update
```

### Secrets

Encrypted with sops-nix using the `nebula` `age` key (recipients in `.sops.yaml`):

```sh
sops modules/hosts/nebula/secrets.yaml
```

### Dotfiles (GNU Stow)

User configs that aren't Nix-managed live in `home/` — each top-level directory
is one Stow *package* mirroring `$HOME` (e.g. `home/niri/.config/niri/config.kdl`
→ `~/.config/niri/config.kdl`). On every `nixos-rebuild switch`, the
`dotfiles-stow` module restows every package against the live repo checkout, so
the symlinks stay editable in place.

```sh
# Capture a new config into the repo (move it in + replace with a symlink)
dots-adopt <pkg> <relpath-under-$HOME>     # e.g. dots-adopt waybar .config/waybar/config

# Pull live edits of an already-tracked file back into the repo
stow -d ~/src/dotfiles/home -t ~ --no-folding --adopt <pkg>
```

### Extending the configuration

- **Shared feature** → add `{ flake.modules.nixos.<name> = <module>; }` under
  `modules/nixos/`. Auto-imported and applied to the host.
- **Host-specific config** → add `{ configurations.nixos.nebula.module = <module>; }`
  under `modules/hosts/nebula/`. Merges into the host automatically — no imports
  edit needed.
- **Custom package** → add a `callPackage` derivation to `packages/`; it becomes
  `pkgs.<name>` (via the `my-packages` overlay) and a `packages.<system>.<name>`
  flake output.
- **Another host** → add `modules/hosts/<host>.nix` registering
  `configurations.nixos.<host>` plus a `modules/hosts/<host>/` directory.

## Reference manuals

Task-focused, machine-verified notes live in [`docs/`](docs/):

| Manual | Covers |
|---|---|
| [`docs/hyprland.md`](docs/hyprland.md) | Hyprland config, binds, rules, layouts, NVIDIA, nebula gotchas |
| [`docs/hdr-hyprland-june-2026.md`](docs/hdr-hyprland-june-2026.md) | HDR under Hyprland (current session) |
| [`docs/hdr-niri-june-2026.md`](docs/hdr-niri-june-2026.md) | HDR under niri (historical) |
| [`docs/bootloader-issues-jun-06.md`](docs/bootloader-issues-jun-06.md) | Boot-failure investigation notes |
| [`docs/libreoffice.md`](docs/libreoffice.md) | LibreOffice dark theme & XDG paths |

## Credits

- [`snowglobe-lib`](https://codeberg.org/earthgman/snowglobe-lib) — host builder, profiles, desktop modules
- [flake-parts](https://flake.parts) + [`import-tree`](https://github.com/vic/import-tree) — the dendritic module system
- The [dendritic pattern](https://github.com/mightyiam/dendritic)
