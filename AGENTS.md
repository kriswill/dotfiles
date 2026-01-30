# Agent Guidelines for Nix Dotfiles Repository

## Overview

Nix-based dotfiles for macOS (nix-darwin + home-manager). Primary configs: Neovim (Lua), Tmux, Zsh, CLI tools.
Platform: aarch64-darwin (Apple Silicon only). Flake-based with custom modular structure using `lib.autoImport`.

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

**Maintenance:**
- `scripts/update-opencode.sh` - Update opencode package version

## Code Style - Nix

**General:**
- Indentation: 2 spaces (enforced by nixfmt-tree)
- Line endings: LF, no trailing whitespace, final newline required
- Formatter: `nix fmt` (uses nixfmt-tree)

**Module Structure:**
Standard pattern for all modules:
```nix
{ lib, config, pkgs, ... }:
{
  options.kriswill.<feature>.enable = lib.mkEnableOption "description";
  
  config = lib.mkIf config.kriswill.<feature>.enable {
    # Configuration here
  };
}
```

**Imports:**
Use `inherit` extensively for cleaner code:
```nix
inherit (pkgs) package1 package2;
inherit (lib) mkIf mkEnableOption mkDefault;
```

**Package Lists:**
Use `builtins.attrValues` pattern:
```nix
packages = builtins.attrValues {
  inherit (pkgs) package1 package2 package3;
};
```

**Let Bindings:**
Extract common values and package paths:
```nix
let
  cfg = config.programs.nh;
  rg = "${pkgs.ripgrep}/bin/rg";
in
```

**Conditionals:**
Always wrap config with `lib.mkIf`:
```nix
config = lib.mkIf cfg.enable { ... };
```

**Options:**
- Boolean: `lib.mkEnableOption "description"`
- Program: `lib.mkProgramOption { pkgs, programName, ... }` (custom lib function)
- Defaults: `lib.mkDefault value` for overridable values

**Symlinks:**
For config files in repo that need to be linked:
```nix
let
  nvimDir = config.home.homeDirectory + "/src/dotfiles/config/nvim";
  ln = config.lib.file.mkOutOfStoreSymlink;
in
{
  "nvim/lua".source = ln (nvimDir + "/lua");
}
```

**Unfree Packages:**
Add to `allowUnfreePredicate` in `flake.nix`:
```nix
allowUnfreePredicate = pkg:
  builtins.elem (nixpkgs.lib.getName pkg) [
    "unfree-package-name"
  ];
```

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
- Indentation: 2 spaces
- Colors: Define at top (`RED`, `GREEN`, `YELLOW`, `BLUE`, `NC`)
- Variables: `UPPER_CASE` for constants, `lower_case` for locals
- Create backups before modifying files

## Naming Conventions

- **Module options:** `kriswill.<feature>.enable` (e.g., `kriswill.neovim.enable`)
- **Packages:** kebab-case (e.g., `kitten`, `iv`, `tofu-ls`)
- **Nix functions:** camelCase (e.g., `mkDarwin`, `autoImport`, `mkProgramOption`)
- **Files:** kebab-case for multi-word (e.g., `alias-en0.nix`, `update-opencode.sh`)
- **Hosts:** Descriptive names (e.g., `k`, `SOC-Kris-Williams`)
- **Shell variables:** `UPPER_CASE` for constants, `lower_case` for locals

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

Located in `lib/default.nix`:

**`autoImport dir`**
- Auto-imports all .nix files in directory except default.nix
- Key feature: Enables directory-based module organization without explicit imports
- Used in: `modules/darwin/default.nix`, `modules/darwin/core/default.nix`

**`mkDarwin hostmodule username`**
- Creates darwin configuration with home-manager integration
- Combines nix-darwin + home-manager + overlays

**`mkHomeManager username`**
- Creates home-manager user configuration
- Sets up imports and state version

**`mkProgramOption { pkgs, programName, packageName?, description?, extraPackageArgs? }`**
- Creates standardized enable option + package option
- Example: `modules/darwin/core/programs/nh/default.nix`

## Common Patterns

**Adding a New Module:**
1. Create file in `modules/darwin/` or `modules/home-manager/`
2. Follow standard structure: `options` with `kriswill.<feature>.enable` + `config` with `lib.mkIf`
3. File is auto-discovered via `lib.autoImport` in parent `default.nix`

**Adding a Custom Package:**
1. Create `pkgs/<name>/package.nix`
2. Add to `packages.${system}` in `flake.nix`
3. Create overlay in `overlays/<name>.nix`
4. If unfree: add to `allowUnfreePredicate` in `flake.nix`

**Symlinked Configs:**
- Live config files in `config/` directory
- Symlink via `config.lib.file.mkOutOfStoreSymlink` in home-manager module
- Allows editing without system rebuild
