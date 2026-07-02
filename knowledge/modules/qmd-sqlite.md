---
type: Darwin Module
title: Qmd Sqlite
description: Custom sqlite with loadable-extension support, for sqlite-vec and qmd (system-level port of the sqliteWithExtensions package + linkSqliteForQmd activation that used to live in home-manager/core.nix).
resource: modules/darwin/qmd-sqlite.nix
tags: [darwin-module]
timestamp: '2026-06-28T18:27:01-07:00'
---

Custom sqlite with loadable-extension support, for sqlite-vec and qmd (system-level port of the sqliteWithExtensions package + linkSqliteForQmd activation that used to live in home-manager/core.nix). qmd (bun-installed, outside nix) hardcodes two Homebrew paths in its setCustomSQLite() call and ignores env vars. We point the Apple-Silicon path at this extension-enabled nix sqlite so qmd can dlopen it; we skip if a real Homebrew sqlite is already installed there.

Follows the [module option pattern](../patterns/module-option-pattern.md), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/qmd-sqlite.nix`](../../modules/darwin/qmd-sqlite.nix)
