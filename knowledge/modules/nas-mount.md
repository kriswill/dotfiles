---
type: Darwin Module
title: Nas Mount
description: 'Auto-mount the UNAS Pro 4''s Personal-Drive SMB share at login via a launchd user agent.'
resource: modules/darwin/nas-mount.nix
tags: [darwin-module]
timestamp: '2026-07-09T17:56:49+00:00'
---

Auto-mounts the UNAS Pro 4's Personal-Drive SMB share at `~/nas` at login via
a `launchd.user.agents.nas-mount` job (`RunAtLoad` + `StartInterval = 300` to
retry if the NAS/network wasn't up yet). Full backstory — how `nas.home.lan`
was created as a UniFi "Local DNS Record" (not a static DNS entry), and why
mounting via it conflicts with the pre-existing Bonjour-based mount (macOS
treats both hostnames as the same negotiated server identity and refuses a
second concurrent mount) — is in
[docs/unifi-dream-machine.md](../../docs/unifi-dream-machine.md).

**`-N` (keychain-only auth) is load-bearing, not cosmetic**: a launchd agent
has no session to show an interactive password sheet, so the job only works
because macOS already resolves a matching keychain entry for this server —
confirmed the same entry serves both the Bonjour and DNS hostnames. The mount
script is idempotent (`mount | grep` guard) so `RunAtLoad` firing against an
already-mounted share is a harmless no-op.

**A compiled binary (`pkgs/nas-mount/`), not a shell script.** Originally
`pkgs.writeShellScriptBin`; rewritten (2026-07-09) to a genuine Mach-O binary
— `main.rs` (pure `std`, no crates, built via a bare `rustc -O` rather than
`rustPlatform.buildRustPackage`) — because `rcodesign` (the codesigning tool
this module's ecosystem uses; see below) only recognizes Mach-O/bundle/DMG/pkg
and errors `specified path is not of a recognized type` on a plain script.
`mountPoint`/`share` are passed as CLI args via launchd's `ProgramArguments`
rather than baked into the binary. Bonus: rustc/the linker auto-ad-hoc-signs
the output at build time (`flags=0x20002(adhoc,linker-signed)`) — Login Items
shows 🔏 ad-hoc rather than ❌ unsigned even before any manual signing.

Either form (script or binary) already avoided the hash-prefixed-name
problem the same way: the store path's *directory* carries the content hash,
but `$out/bin/nas-mount` (what launchd actually execs) doesn't, so Login
Items shows a clean `nas-mount`. `cbm-daemon`, `gh-config`, etc. show up
clean the same way — while nix-darwin/sops-nix's own system daemons
(`activate-system`, `sops-install-secrets`) show as generic `sh`: nix-darwin
wraps *system* LaunchDaemons in a `/bin/sh -c "wait4path /nix/store && exec
..."` trampoline upstream (guards against the store not being mounted yet at
boot), which is out of any individual module's control.

Imported on every darwin host but disabled by default — hosts opt in with
`services.nas-mount.enable = true;`
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)):
enabled on [k](../hosts/k.md), deliberately not on mini or SOC-Kris-Williams
(personal NAS, personal machine); auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

**Login Items shows "NasMount" + custom icon + Kris's developer identity**
(resolved 2026-07-09, after a long arc). Attribution needs an *associated
app bundle*, not a signed executable — so `pkgs/nas-mount` also builds
`NasMount.app` (ad-hoc signed at build time via rcodesign in postFixup; an
unsigned bundle is an invalid code object launchd rejects with `EX_CONFIG`),
the module deploys it to `~/Applications` with a stamp-guarded copy (so a
manual Developer ID signature survives routine `nrs` runs) plus
`lsregister -f` (cp-installed apps are invisible to LaunchServices), and the
launchd plist — written via `environment.userLaunchAgents` because the
`launchd.user.agents` submodule is closed and lacks the key — carries
`AssociatedBundleIdentifiers = [ net.kris.nas-mount ]`. BTM caches by plist
path; the module header documents the bootout + rm + wait + restore +
bootstrap refresh dance. Full history (keychain ACL boundary, sops
rejection, wrong-identity export, bundle requirement):
[nas-mount-codesigning](../decisions/nas-mount-codesigning.md) and
`docs/unifi-dream-machine.md`.

## Source

- Module: [`modules/darwin/nas-mount.nix`](../../modules/darwin/nas-mount.nix)
- Package: [`pkgs/nas-mount/`](../../pkgs/nas-mount/) (`main.rs`, `package.nix`)
- Options under: `services.nas-mount`
- Decision: [nas-mount-codesigning](../decisions/nas-mount-codesigning.md)
