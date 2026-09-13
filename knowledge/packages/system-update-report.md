---
type: Nix Package
title: System Update Report
description: 'HTML "what changed" page after a rebuild: nvd diff of the booted (NixOS) or previous (darwin) generation vs current, plus the latest flake.lock commit parsed into a flake-input from/to table.'
resource: pkgs/system-update-report/package.nix
tags: [package, cross-platform, bun]
generated: { by: human:kris, at: 2026-09-13T00:00:00+00:00 }
---

Cross-platform bun/TypeScript CLI (`pkgs/system-update-report/main.ts`,
wrapped by `writeShellApplication` with bun, nvd and git pinned) that renders
a themed standalone HTML report of a system update. Two data sources:

- `nvd diff FROM TO` — parsed into upgraded / downgraded / added / removed /
  rebuilt tables plus a highlights table (pinned names like linux, nvidia,
  hyprland, plus every major-version bump). `FROM` defaults to
  `/run/booted-system` on NixOS; darwin has no booted-system, so it falls
  back to the previous `/nix/var/nix/profiles/system-N-link`. `TO` defaults
  to `/run/current-system`.
- the latest commit touching `flake.lock` in the dotfiles repo (`--repo`,
  `$DOTFILES`, or `~/src/dotfiles`) — its message's `• Updated/Added/Removed
  input` blocks become a stacked from/to table with a token-level diff
  highlighting only the parts that changed. A repo with no such commit
  just omits the section.

Output defaults to `~/Documents/system-update-<host>-<date>.html` (`-o` to
override). The page theme is the html-doc skill's `theme.html`, read from its
git-tracked home in the stow tree (`home/agents/.agents/skills/html-doc/`) so
there is one source; nvd's ANSI colors are kept as spans on the theme
palette. On the dev-shell PATH via
[dev](../modules/dev.md).

Added per the [add-package playbook](../playbooks/add-package.md).

## Source

- Package: [`pkgs/system-update-report/package.nix`](../../pkgs/system-update-report/package.nix)
