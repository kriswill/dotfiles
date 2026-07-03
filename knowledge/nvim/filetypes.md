---
type: Neovim Config
title: Filetype Detection & ftplugins
description: Custom filetype registrations plus shebang-based detection for extensionless scripts; per-filetype tweaks under ftplugin/.
resource: home/nvim/.config/nvim/lua/config/filetypes.lua
tags: [nvim, filetypes]
timestamp: '2026-07-02T00:00:00-07:00'
---

Filetype is what drives LSP attach and treesitter, so
[`lua/config/filetypes.lua`](../../home/nvim/.config/nvim/lua/config/filetypes.lua)
makes sure less-common files resolve to a real filetype.

## Registrations

- Extensions: `.gotmpl` → gotmpl, `.templ` → templ, `.tfvars` →
  terraform-vars.
- Filenames: `go.work` → gowork; `docker-compose.yml`/`compose.yaml` (and
  variants) → `yaml.docker-compose` so the yaml language server can apply the
  compose schema.

## Shebang detection for extensionless scripts

A pattern rule maps a script's shebang interpreter to a filetype — e.g.
`#!/usr/bin/env bun` (also deno/tsx/ts-node) → typescript, node →
javascript — handling `env -S` flags and absolute interpreter paths. That
gives repo tools like `scripts/okf/okf.ts` companions full LSP + treesitter
without an extension. Two subtleties, straight from the source comments:

- The rule is guarded to extensionless paths and registered at
  `priority = -10` so any explicit rule wins.
- The pattern key is `".+"` rather than `".*"` **on purpose**:
  `vim.filetype.add` overwrites patterns by key, and
  [snacks](plugins/snacks.md)' bigfile feature already claims `".*"`. A
  distinct-but-equally-catch-all key lets both coexist.

## ftplugin/

[`ftplugin/`](../../home/nvim/.config/nvim/ftplugin/) holds per-filetype
buffer tweaks. `markdown.lua` is the substantive one: wrap + linebreak +
`j`/`k` as display-line motions, and spell-checking with `spellfile` pointed
into the dotfiles repo ([stow tree](../patterns/stow-tree.md) path) so words
added with `zg` are version-controlled. The other five (gotmpl, gowork,
templ, terraform-vars, yaml.docker-compose) are intentionally empty
placeholders for filetypes whose real config lives in [LSP](lsp.md).

## Citations

- [`lua/config/filetypes.lua`](../../home/nvim/.config/nvim/lua/config/filetypes.lua)
- [`ftplugin/markdown.lua`](../../home/nvim/.config/nvim/ftplugin/markdown.lua)
