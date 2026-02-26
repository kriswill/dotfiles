# Agent Guidelines for Nix Dotfiles Repository

## Overview

Nix-based dotfiles for macOS (nix-darwin + home-manager). Primary configs: Neovim (Lua), Tmux, Zsh, CLI tools.
Platform: aarch64-darwin (Apple Silicon only). Flake-based with custom modular structure using `lib.autoImport`.

## MANDATORY: Use td for Task Management

Run td usage --new-session at conversation start (or after /clear). This tells you what to work on next.

Sessions are automatic (based on terminal/agent context). Optional:

- td session "name" to label the current session
- td session --new to force a new session in the same context

Use td usage -q after first read.

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

- **Module pattern:** `options` with `kriswill.<feature>.enable` + `config` with `lib.mkIf`. See `modules/darwin/core/programs/nh/default.nix` for reference.
- **Imports:** Use `inherit` for cleaner destructuring
- **Package lists:** Use `builtins.attrValues { inherit (pkgs) ...; }` pattern
- **Options:** `lib.mkEnableOption`, `lib.mkProgramOption` (custom), `lib.mkDefault`
- **Symlinks:** Use `config.lib.file.mkOutOfStoreSymlink` (see neovim module)
- **Unfree packages:** Add to `allowUnfreePredicate` in `flake.nix`

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
- **Nix functions:** camelCase (e.g., `mkDarwin`, `autoImport`, `mkProgramOption`)
- **Files:** kebab-case for multi-word (e.g., `alias-en0.nix`, `update-opencode.sh`)
- **Hosts:** Descriptive names (e.g., `k`, `SOC-Kris-Williams`)

## File Organization

```
├── modules/
│   ├── darwin/          # nix-darwin system modules (uses lib.autoImport)
│   │   ├── core/        # Essential system configuration
│   │   └── mixins/      # Optional features (homebrew, aliases)
│   └── home-manager/    # User-level tool configs (neovim, tmux, zsh, git, etc.)
├── config/              # Actual config files (symlinked to XDG locations)
│   ├── nvim/            # Neovim Lua configuration
│   └── tmux/            # Tmux configuration
├── pkgs/                # Custom package definitions (*.nix files or subdirectories)
├── overlays/            # Nixpkgs overlays (makes custom packages available)
├── hosts/               # Host-specific configurations
├── lib/                 # Custom library functions (autoImport, mkDarwin, etc.)
└── scripts/             # Helper scripts for package updates
```

## Custom Library Functions

Located in `lib/default.nix`: `autoImport` (directory-based module loading), `mkDarwin`, `mkHomeManager`, `mkProgramOption`. See file for API details.

## Common Patterns

**Adding a New Module:**

1. Create file in `modules/darwin/` or `modules/home-manager/`
2. Follow module pattern (see Code Style - Nix above)
3. File is auto-discovered via `lib.autoImport` in parent `default.nix`
4. **Must `git add` new files before `nix build`** — flakes only see git-tracked files

**Adding a Custom Package:**

1. Create `pkgs/<name>/package.nix`
2. Add to `packages.${system}` in `flake.nix`
3. Create overlay in `overlays/<name>.nix`
4. If unfree: add to `allowUnfreePredicate` in `flake.nix`

**Symlinked Configs:**

- Live config files in `config/` directory
- Symlink via `config.lib.file.mkOutOfStoreSymlink` in home-manager module
- Allows editing without system rebuild
