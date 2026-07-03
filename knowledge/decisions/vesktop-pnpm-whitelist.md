---
type: Decision
title: Tolerate the pnpm-10.29.2 Whitelist for Vesktop (For Now)
description: nebula permits insecure pnpm-10.29.2 because nixpkgs' vesktop deliberately pins it (newer pnpm breaks its electron-builder at runtime); the analyzed whitelist-free fix — repacking upstream's prebuilt AppImage like wowup — is deferred until the whitelist actually blocks something or upstream stalls.
tags: [nixos, security, discord, nixpkgs]
timestamp: '2026-07-03T15:30:00-07:00'
---

**Status:** active (revisit on nixpkgs bumps). **Where:**
[nebula](../hosts/nebula.md), `modules/hosts/nebula/configuration.nix`
(`nixpkgs.config.permittedInsecurePackages`).

## Context

The post-merge `nix flake update` (`5497cb0`) moved nixpkgs to `b5aa0fb`,
which marks `pnpm-10.29.2` insecure (CVE-2026-48995 plus six more). nebula's
Discord client is vesktop — snowglobe-lib's `programs.discord` weak-defaults
`package = pkgs.vesktop` (snowglobe `nixosModules/snowglobe-lib/default.nix:181`)
— and nixpkgs' vesktop builds from source with a **deliberately pinned**
`pnpm_10_29_2`: pnpm 10.29.3+ made a breaking change
([pnpm/pnpm#10601](https://github.com/pnpm/pnpm/issues/10601)) that crashes
apps using electron-builder < 26.8.2 at launch, and vesktop's lockfile is
below that. So the flagged pnpm is structural, not an oversight:

- Installing `pkgs.vesktop` directly (bypassing snowglobe's module) hits the
  identical eval error — the flag lives in vesktop's own recipe.
- nixos-unstable HEAD (checked 2026-07-03) still fails the same way; waiting
  for a routine bump fixes nothing until vesktop upstream moves to a newer
  electron-builder.
- Overriding vesktop to build with the fixed `pnpm_10` (10.34.4) risks the
  documented runtime break plus a `pnpmDeps` FOD hash churn — fragile.

## Decision

Keep `nixpkgs.config.permittedInsecurePackages = [ "pnpm-10.29.2" ]` on the
nebula host (`ba044b3`), scoped to that one host with a dated removal
comment. The exposure is build-time only — pnpm never lands in the installed
system; it fetches/assembles vesktop's JS dependencies inside the sandboxed
build.

Whitelist-free alternatives analyzed, in preference order for when this is
revisited:

1. **Repack upstream's prebuilt AppImage** — Vencord/Vesktop publishes
   `Vesktop-<v>.AppImage` (same 1.6.5 as nixpkgs) from its own CI. A
   `pkgs/vesktop-bin.nix` via `appimageTools.wrapType2` mirrors
   [wowup](../packages/wowup.md) exactly; nebula then sets
   `programs.discord.package = pkgs.vesktop-bin` (normal priority beats
   snowglobe's `setDefault` 1337 — the commented `# package = ...` line in
   `configuration.nix` is that hook). Keeps full vesktop (Vencord, Wayland
   screenshare); trades source-build-with-vulnerable-tool for
   trust-upstream-binary — the same model already accepted for wowup, podman,
   and kitten. Cost: manual version/hash bumps.
2. **Official client** (`programs.discord.package = pkgs.discord`) — prebuilt,
   no pnpm, but unfree and materially worse Wayland screen-sharing (the reason
   vesktop exists) on a Hyprland gaming desktop.
3. **Flatpak** (`dev.vencord.Vesktop`) — nebula's per-user Flathub machinery
   already exists and it auto-updates, but the install is imperative, outside
   the nix closure.

## Consequences

Every nixpkgs bump should re-test dropping the whitelist
(`nix eval .#nixosConfigurations.nebula.config.system.build.toplevel.drvPath`
after removing the line) — upstream vesktop bumping electron-builder ≥ 26.8.2
dissolves the problem. If the whitelist ever has to grow instead, switch to
alternative 1 rather than widening it.

## Citations

- Commits `5497cb0` (flake update that surfaced the flag), `ba044b3` (scoped
  whitelist + dated comment).
- nixpkgs `pkgs/development/tools/pnpm/default.nix` (the pinned `10_29_2`
  variant and its CVE list), `pkgs/by-name/ve/vesktop/package.nix` (the pin).
