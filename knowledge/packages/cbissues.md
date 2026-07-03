---
type: Nix Package
title: Cbissues
description: 'cbissues — browse/filter a Codeberg (Forgejo) repo''s issues (fzf TUI + --plain).'
resource: pkgs/cbissues.nix
tags: [package]
timestamp: '2026-07-03T20:00:48+00:00'
---

cbissues — browse/filter a Codeberg (Forgejo) repo's issues (fzf TUI + --plain). The implementation lives in ./cbissues.sh (plain bash); this just wraps it with pinned runtime deps and ShellCheck. `op` is resolved from the ambient PATH (only needed for private repos); the token reference defaults inside the script and is overridable via $CBISSUE_TOKEN_REF.

Added per the [add-package playbook](../playbooks/add-package.md).

## Source

- Package: [`pkgs/cbissues.nix`](../../pkgs/cbissues.nix)
- Overlay: [`overlays/cbissues.nix`](../../overlays/cbissues.nix) — exposes/replaces `pkgs.cbissues`
