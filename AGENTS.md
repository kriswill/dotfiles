# Agent Guidelines for Nix Dotfiles Repository

## Overview

Nix-based dotfiles for MacOS (nix-darwin + home-manager). Primary configs: Neovim (Lua), Tmux, Zsh, CLI tools.
Platform: aarch64-darwin (Apple Silicon only). Flake-based, using flake-parts + `import-tree` (the Dendritic pattern): every `.nix` file under `modules/` is auto-discovered as a flake-parts module.

## Build & Commands

**Primary Commands:**

- `darwin-rebuild switch --flake .` - Apply system configuration
- `nix develop` - Enter dev shell (deadnix, statix, nixfmt-tree, just)

**Testing & Validation:**

- `nix flake check` - Validate flake structure
- `nix build .#darwinConfigurations.k.system` - Test build without applying
- `nix eval .#darwinConfigurations.k.config.<path>` - Evaluate specific config values
- `nix flake show` - Show all flake outputs
- `nix build .#packages.aarch64-darwin.<package>` - Build specific package

**Code Quality:**

- `nix fmt` - Format all Nix files (nixfmt-tree)
- `statix check .` - Lint Nix code
- `deadnix .` - Find unused Nix code

## Code Style - Nix

- **Module pattern:** wrap in `flake.modules.{darwin,homeManager}.<name> = { ... }: { options … config … }`; `options` with `kriswill.<feature>.enable` + `config` with `lib.mkIf`. See `modules/darwin/nh.nix` for reference.
- **Imports:** Use `inherit` for cleaner destructuring
- **Package lists:** Use `builtins.attrValues { inherit (pkgs) ...; }` pattern
- **Options:** `lib.mkEnableOption`, `lib.mkProgramOption` (custom), `lib.mkDefault`
- **Symlinks:** Use `config.lib.file.mkOutOfStoreSymlink` (see neovim module)
- **Unfree packages:** Repo sets `nixpkgs.config.allowUnfree = false` in `modules/darwin/core.nix`; to permit a specific unfree package add a `nixpkgs.config.allowUnfreePredicate` there

## Code Style - Lua (Neovim)

**Formatter:** stylua (configured in `config/nvim/.stylua.toml`)

- `indent_width = 2`
- `collapse_simple_statement = "FunctionOnly"`
- `sort_requires.enabled = true`

**Structure:**

- Entry: `init.lua` → `require("config")`
- Core config: `lua/config/` (options, keymaps, autocmds, LSP)
- Plugins: `lua/plugins/` (lazy.nvim plugin specs)

## Code Style - Shell Scripts

- Always start with: `set -euo pipefail`
- Use `trap 'cleanup_command' EXIT` for temp resources
- Colors: Define at top (`RED`, `GREEN`, `YELLOW`, `BLUE`, `NC`)
- Variables: `UPPER_CASE` for constants, `lower_case` for locals
- Create backups before modifying files

## Naming Conventions

- **Module options:** `kriswill.<feature>.enable` (e.g., `kriswill.neovim.enable`)
- **Packages:** kebab-case (e.g., `kitten`, `iv`, `tofu-ls`)
- **Nix functions:** camelCase (e.g., `mkProgramOption`, `kanagawa`)
- **Files:** kebab-case for multi-word (e.g., `alias-en0.nix`, `update-opencode.sh`)
- **Hosts:** Descriptive names (e.g., `k`, `SOC-Kris-Williams`)

## File Organization

```text
├── modules/             # Every .nix here is auto-imported as a flake-parts module
│   ├── flake-parts.nix  # systems list + flake-parts plumbing
│   ├── darwin.nix       # realises `configurations.darwin.<host>` → darwinConfigurations
│   ├── home.nix         # wires home-manager into nix-darwin
│   ├── lib.nix, packages.nix, overlays.nix, dev.nix
│   ├── darwin/          # nix-darwin system feature modules (core, homebrew, ghostty, …)
│   ├── home-manager/    # User-level tool configs (neovim, tmux, zsh, git, …)
│   └── hosts/           # Per-host config (k, mini, SOC-Kris-Williams)
├── config/              # Actual config files (symlinked to XDG locations)
│   ├── nvim/            # Neovim Lua configuration
│   └── tmux/            # Tmux configuration
├── pkgs/                # Custom package definitions (*.nix files or subdirectories)
├── flakes/              # Self-contained sub-flakes consumed by the root via relative-path inputs (e.g. flakes/ccglass)
├── overlays/            # Nixpkgs overlays (makes custom packages available)
├── lib/                 # Pure lib helpers (mkProgramOption, kanagawa) — outside modules/ so import-tree skips them
└── scripts/             # Helper scripts for package updates
```

## Custom Library Functions

Pure helpers live in `lib/default.nix`: `mkProgramOption` and `kanagawa`. They're merged onto `nixpkgs.lib` in `modules/lib.nix` (exposed as `config.kriswill.lib`) and handed to the darwin/home-manager evaluations via specialArgs, so modules reach them as `lib.mkProgramOption` / `lib.kanagawa`. Module auto-discovery and the old `mkDarwin`/`mkHomeManager`/`autoImport` builders are gone — flake-parts + `import-tree ./modules` (wired in `flake.nix`) handles discovery, and `modules/{darwin,home}.nix` realise the configurations.

## Common Patterns

**Adding a New Module:**

1. Create a `.nix` file in `modules/darwin/` or `modules/home-manager/` (a bare `<name>.nix`; only use a directory when bundling adjacent config files)
2. Define `flake.modules.darwin.<name>` or `flake.modules.homeManager.<name>` following the module pattern (see Code Style - Nix above)
3. File is auto-discovered by `import-tree` — no manual import needed (prefix a path component with `_` to exclude it, e.g. `yazi/_themes/`)
4. **Must `git add` new files before `nix build`** — flakes only see git-tracked files

**Adding a Custom Package:**

1. Create `pkgs/<name>.nix` (or `pkgs/<name>/package.nix`)
2. Add `<name> = pkgs.callPackage ../pkgs/<name>.nix { };` to `perSystem.packages` in `modules/packages.nix`
3. To make it available to hosts, create `overlays/<name>.nix` and register it in `modules/overlays.nix` (`flake.overlays.<name>`)
4. If unfree: add a `nixpkgs.config.allowUnfreePredicate` entry in `modules/darwin/core.nix`

**Adding a Custom Package as a Sub-flake (extraction pattern):**

For a package that warrants its own flake — forked/patched source, standalone-buildable, or destined to become a separate repo — put it under `flakes/<name>/` instead of `pkgs/`:

1. Create `flakes/<name>/{flake.nix,package.nix,…}`. `flake.nix` uses flake-parts and exposes `packages.<system>.<name>` (+ `default`). **`git add` it** — sub-flake files must be git-tracked to be seen.
2. Add a relative-path input in `flake.nix`: `inputs.<name>.url = "./flakes/<name>";` with `inputs.<name>.inputs.{nixpkgs,flake-parts}.follows` to dedupe nixpkgs.
3. Re-export in `modules/packages.nix`: `<name> = inputs.<name>.packages.${system}.<name>;` (plus a `flake.packages` block for systems outside the root `systems` list).
4. If a host needs it on `pkgs`, add an **inline** overlay in `modules/overlays.nix` (which receives `inputs`): `<name> = _final: prev: { <name> = inputs.<name>.packages.${prev.stdenv.hostPlatform.system}.<name>; };`.

Later extraction to a separate repo is just swapping the input URL `"./flakes/<name>"` → `"github:owner/<name>"`. See `flakes/ccglass/` for a worked example.

**Symlinked Configs:**

- Live config files in `config/` directory
- Symlink via `config.lib.file.mkOutOfStoreSymlink` in home-manager module
- Allows editing without system rebuild
