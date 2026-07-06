---
type: Playbook
title: Add a Feature Module
description: Create a new darwin or NixOS feature module — universal (ungated) or host-selective (behind a programs./services. enable); registration is automatic.
tags: [nix, module]
timestamp: '2026-07-03T12:00:00-07:00'
---

## Examples

1. Create `modules/<class>/<name>.nix` (`darwin/` or `nixos/`) defining
   `flake.modules.<class>.<name>` — a bare file; a directory only when
   bundling adjacent config files. Pick the tier per the
   [host-mounted modules pattern](../patterns/host-mounted-modules.md):
   - **Universal** (every host of the class): no options, no `lib.mkIf`
     ([tmux](../modules/tmux.md) is the reference). The nixos class is
     all-universal today (single Linux host) — retrofit gates when a second
     NixOS host appears.
   - **Host-selective** (darwin): gate behind `programs.<name>.enable` /
     `services.<name>.enable` ([podman-desktop](../modules/podman-desktop.md))
     and flip it in each wanting host's `modules/hosts/<hostname>/default.nix`.
   - **One machine only** (fixed IPs, hardware quirks): skip the class dirs;
     add a file beside that host's registration merging into
     `configurations.<class>.<hostname>.module`
     ([alias-en0](../modules/alias-en0.md), `modules/hosts/nebula/*.nix`).
2. Cross-platform feature? Add the twin in the other class dir
   (`modules/darwin/git.nix` ↔ `modules/nixos/git.nix`); extract shared
   generated-file text to `lib/` and keep the twins' package lists in sync.
3. No import wiring — discovery is automatic per the
   [Dendritic module layout](../patterns/dendritic-modules.md). Prefix a path
   component with `_` to exclude it.
4. **`git add` the file** — flakes only see tracked files.
5. Verify: `nix flake check`, then build or switch per
   [rebuild-and-rollback](rebuild-and-rollback.md). For a nixos module, the
   pre-hardware gate from a Mac is
   `nix eval .#nixosConfigurations.nebula.config.system.build.toplevel.drvPath`.

Afterwards: run `okf scaffold` to stub the module's catalog doc in this
bundle, and `okf index` to list it (dev-shell PATH; outside it,
`nix run .#okf -- <cmd>`).
