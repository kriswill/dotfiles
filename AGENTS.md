# Agent Guidelines for Nix Dotfiles Repository

## Overview

Nix-based dotfiles for **macOS (nix-darwin)** and **NixOS** in one flake; every config
is a per-class system module + the shared GNU Stow tree under `home/`.
Hosts: `k`, `mini`, `SOC-Kris-Williams` (aarch64-darwin) and
`nebula` (x86_64-linux desktop: Hyprland/Noctalia on
[snowglobe-lib](https://github.com/kriswill/snowglobe-lib)
(GitHub fork of the Codeberg upstream)).
Primary configs: Neovim (Lua), Tmux, Zsh, CLI tools;
nebula adds the Wayland desktop stack. Flake-based, using flake-parts + `import-tree` (the Dendritic pattern):
every `.nix` file under `modules/` is auto-discovered as a flake-parts module.

## Nested Agent Docs

Some subtrees carry their own `AGENTS.md` (+ thin `CLAUDE.md`) **When working
on files in a subdirectory, always look for and follow the nearest `AGENTS.md`
up the tree from those files** — it holds the local conventions this root file
omits. `modules/AGENTS.md` anchors the Nix layer — code style, the
module/package/sub-flake wiring walkthroughs, `lib/`, sops secrets — and
`pkgs/`, `overlays/`, and `flakes/` each carry their own cross-linked
`AGENTS.md` with that dir's local conventions.

## Knowledge Bundle (`knowledge/`)

`knowledge/` is the repo's authored knowledge layer — an
[OKF v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
bundle of architecture patterns, decision records, playbooks, and a scaffolded catalog
of every module/package/host/nvim-plugin, cross-linked into a graph.
Conventions: `knowledge/okf-profile.md`. Start reading at `knowledge/index.md`
(each directory's `index.md` discloses one level at a time).

**Keep it current as part of any change** (the `knowledge-bundle` skill has the full procedure):
after adding a module/package/host/nvim-plugin run `okf scaffold` + `okf index`;
record non-obvious decisions in `knowledge/decisions/`; append `knowledge/log.md`;
`okf validate` must exit 0 before committing. `okf viz` renders an interactive graph at
`knowledge/viz.html` (gitignored). The `okf` command is on the dev-shell PATH (`modules/dev.nix`),
nix-built from okf's own repo (`kriswill/okflight`, public — consumed as a FlakeHub input,
`https://flakehub.com/f/kriswill/okflight/0`); outside the dev shell use `nix run .#okf -- <cmd>`.

## Build & Commands

**Primary Commands:**

- `darwin-rebuild switch --flake .` — apply system configuration (macOS); or `nrs`
- `sudo nixos-rebuild switch --flake .#nebula` — apply on nebula (or `nrs`;
  run after `cd` into the real checkout — nix's `--flake <path>` does not
  follow a symlinked path like `~/src/dotfiles` on nebula)
- `nix develop` — dev shell (deadnix, statix, nixfmt-tree, just, okf, nil,
  nix-output-monitor, sops, age, ssh-to-age, stow)

**Testing & Validation:**

- `nix flake check` — validate flake + build the current system's host checks
  (other-system checks eval only)
- `nix build .#darwinConfigurations.<host>.system` — test-build a darwin host
- `nix eval .#nixosConfigurations.nebula.config.system.build.toplevel.drvPath`
  — full cross-eval of the NixOS host from a Mac (the pre-hardware gate)
- `nix eval .#darwinConfigurations.k.config.<path>` — evaluate specific values
- `nix build .#packages.<system>.<package>` — build a specific package

**Code Quality:**

- `nix fmt` — format all Nix files (nixfmt-tree)
- `statix check .` / `deadnix .` — lint Nix code

**Token-optimized wrappers (rtk):** prefix these with `rtk` — custom filters in
`~/.config/rtk/filters.toml` strip nix/direnv store-fetch and loading noise
(agents only, not auto-rewritten by the Claude Code hook, so the `rtk` prefix
must be typed explicitly):

- `rtk nix run …` / `rtk nix shell …` / `rtk nix develop -c …`
- `rtk nix build …` / `rtk nix flake check …`
- `rtk direnv exec . …`

## Code Style - Shell Scripts

- Always start with: `set -euo pipefail`
- Use `trap 'cleanup_command' EXIT` for temp resources
- Colors: Define at top (`RED`, `GREEN`, `YELLOW`, `BLUE`, `NC`)
- Variables: `UPPER_CASE` for constants, `lower_case` for locals
- Create backups before modifying files

## Naming Conventions

- **Module options:** `programs.<name>.*` (user-facing programs) /
  `services.<name>.*` (daemons, sub-flake modules) for darwin host-selective
  features; universal modules define no options
- **Packages:** kebab-case (e.g., `kitten`, `iv`, `tofu-ls`, `helium-config`)
- **Nix functions:** camelCase (e.g., `kanagawa`)
- **Files:** kebab-case for multi-word (e.g., `alias-en0.nix`, `update-opencode.sh`)
- **Hosts:** Descriptive names (e.g., `k`, `nebula`, `SOC-Kris-Williams`)

## File Organization

```text
├── modules/             # Every .nix here is auto-imported as a flake-parts module
│   ├── flake-parts.nix  # systems list (aarch64-darwin + x86_64-linux) + plumbing
│   ├── darwin.nix       # realises `configurations.darwin.<host>` → darwinConfigurations
│   ├── nixos.nix        # realises `configurations.nixos.<host>` → nixosConfigurations
│   │                    #   (through snowglobe-lib's mkNixosHost; hardware metadata in the registry)
│   ├── packages.nix, overlays.nix, dev.nix
│   ├── darwin/          # nix-darwin feature modules (universal ungated; host-selective gated)
│   ├── nixos/           # NixOS feature modules (all universal within the class today)
│   └── hosts/           # One folder/file per host (exact hostname)
│       ├── k/, mini/, SOC-Kris-Williams/        (darwin; default.nix + side files)
│       └── nebula.nix + nebula/                 (nixos; registry entry + host files,
│                                                 secrets.yaml, users/k/, disko.nix, …)
├── home/                # GNU Stow tree — one package per dir mirroring $HOME, SHARED by both OSes
│   ├── nvim/, tmux/, zsh/, git/, ghostty/, starship/, fastfetch/, direnv/
│   │                    #   …cross-platform (deployed everywhere)
│   ├── ssh/, kitty/, karabiner/, glow/, oksh/, podman-desktop/, yazi/   # macOS-only (skip-listed on nixos)
│   ├── hyprland/, fuzzel/, gtk/, mimeapps/, pupgui/, desktop-entries/, diffnav/   # Linux-only (skip-listed on darwin)
│   │                    #   deployed by modules/{darwin,nixos}/dotfiles-stow.nix on every rebuild
├── config/              # NON-symlinkable app-owned configs (Helium, Noctalia, gh) — snapshot
│                        #   sync via helium-config/noctalia-config/gh-config CLIs; see config/README.md
├── pkgs/                # Custom package definitions (*.nix files or subdirectories)
├── flakes/              # Self-contained sub-flakes consumed via relative-path inputs (ccglass, apple-container)
├── overlays/            # Nixpkgs overlays (makes custom packages available)
├── lib/                 # Pure lib helpers (kanagawa, direnv-nom-wrapper) — outside modules/ so import-tree skips them
├── docs/                # Task-focused manuals (hyprland, noctalia, helium, tmux, fastfetch, …)
└── scripts/             # Helper scripts for package updates
```

## Common Patterns

Nix-side patterns (adding a module / package / sub-flake) live in
`modules/AGENTS.md`. The patterns below cover config deployment (`home/`,
`config/`).

**Symlinked Configs — the stow tree (`home/`), pointing at the live repo (editable without rebuild):**

Each dir under `home/` is one stow package mirroring `$HOME` (e.g.
`home/tmux/.config/tmux/tmux.conf`), **shared by both OSes**. Each OS's
dotfiles-stow module restows every package during activation (`--no-folding`,
conflicts logged + skipped per package, stale links self-healed) — except the
packages on its `skip` list (macOS-only packages skipped on nixos and vice
versa; the two lists mirror each other in
`modules/{darwin,nixos}/dotfiles-stow.nix`). Adding a package = adding a
directory (deployed on BOTH OSes unless skip-listed); no nix edit needed.
Capture an existing file with `dots-adopt <pkg> <relpath-under-$HOME>`; pull
live edits of an already-tracked file back with
`stow -d ~/src/dotfiles/home -t ~ --no-folding --adopt <pkg>` (overwrites the
repo copy). Files that must embed /nix/store paths (e.g. tmux `plugins.conf`,
ghostty's per-OS `os.conf`) are generated by the feature's module per class.

**Non-symlinkable configs — `config/`:**

Apps that rewrite their config via atomic rename (Helium/Chromium, Noctalia,
gh) break stow symlinks, so their settings are git-tracked as **snapshots**
under `config/` and synced manually with per-app CLIs (`helium-config`,
`noctalia-config`, `gh-config`: `capture` / `restore` / `diff`; Helium
snapshots are age-encrypted). Helium/Noctalia are nebula-only; gh is
cross-platform. Full design: `config/README.md`.

## Manuals (`docs/`)

`docs/` holds task-focused reference manuals (hyprland, noctalia, helium,
suspend, fastfetch, tmux, libreoffice, CVE audits, svelte…) — researched,
machine-verified, written for agent reuse. Consult the relevant manual before
working on its topic and keep it current: lead with the verified version/state,
keep a dated "Learned behaviours & workarounds" section, correct stale claims
rather than appending contradictions.
