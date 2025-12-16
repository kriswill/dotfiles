# Agent Guidelines for Nix Dotfiles Repository

## Overview

Nix-based dotfiles for macOS (nix-darwin + home-manager). Primary configs: Neovim (Lua), Tmux, Zsh, CLI tools.

## Build & Commands

- **Apply config**: `darwin-rebuild switch --flake .` (rebuild system)
- **Format**: `nix fmt` (formats all Nix files with nixfmt-tree)
- **Lint**: `statix check .` (Nix linter)
- **Dead code**: `deadnix .` (find unused code)
- **Validate**: `nix flake check` (validate flake structure)
- **Dev shell**: `nix develop` (enter shell with devtools: deadnix, statix, nixfmt-tree, just)

## Code Style - Nix

- **Indentation**: 2 spaces (all file types)
- **Formatter**: nixfmt-rfc-style (automatic via `nix fmt`)
- **Line endings**: LF, no trailing whitespace
- **Imports**: Use `inherit` for cleaner code: `inherit (pkgs) pkg1 pkg2;`
- **Package lists**: `builtins.attrValues { inherit (pkgs) ...; }` pattern
- **Module structure**: `{ lib, config, pkgs, ... }:` with `options` and `config` attributes
- **Options**: `lib.mkEnableOption "description"` for boolean options
- **Conditionals**: `lib.mkIf config.kriswill.feature.enable { ... }`

## Code Style - Lua (Neovim)

- **Formatter**: stylua (2-space indent, collapse_simple_statement = "FunctionOnly", sort_requires = true)
- **Format check**: Automatic via conform.nvim on save

## Naming Conventions

- **Module options**: `kriswill.<feature>.enable` pattern
- **Packages**: kebab-case (e.g., `claude-code`, `kitten`)
- **Hosts**: descriptive names (e.g., `k`, `SOC-Kris-Williams`)
