---
type: Nix Package
title: Cbissue
description: cbissue — open Codeberg (Forgejo) issues from the CLI.
resource: pkgs/cbissue.nix
tags: [package]
timestamp: '2026-07-03T20:00:48+00:00'
---

cbissue — open Codeberg (Forgejo) issues from the CLI. The implementation lives in ./cbissue.sh (plain bash); this just wraps it with pinned runtime deps and ShellCheck via writeShellApplication. `op` (1Password CLI) is intentionally NOT pinned — it must be the system's wrapped, desktop-integrated `op` from the ambient PATH. The 1Password token reference defaults inside the script and is overridable per call via $CBISSUE_TOKEN_REF.

Added per the [add-package playbook](../playbooks/add-package.md).

## Source

- Package: [`pkgs/cbissue.nix`](../../pkgs/cbissue.nix)
- Overlay: [`overlays/cbissue.nix`](../../overlays/cbissue.nix) — exposes/replaces `pkgs.cbissue`
