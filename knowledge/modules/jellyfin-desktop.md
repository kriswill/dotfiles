---
type: NixOS Module
title: Jellyfin Desktop
description: 'Installs nebula''s Jellyfin client (jellyfin-desktop) with upstream''s fix for white video (an opaque web view over mpv after a manual server connect), applied only while nixpkgs pins the pre-fix 2cb4a445 snapshot; then it falls back to stock and warns.'
resource: modules/hosts/nebula/jellyfin-desktop.nix
tags: [nixos-module, host-specific]
generated: { by: claude-code/opus-5.5, at: 2026-11-07T22:00:00-08:00 }
sources:
  - id: pr-1267
    resource: https://github.com/jellyfin/jellyfin-desktop/pull/1267
    title: 'jellyfin/jellyfin-desktop#1267: Re-apply the transparent web view background after a renderer switch'
---

Adds `jellyfin-desktop` (the official client, formerly Jellyfin Media
Player) to `environment.systemPackages`. Playback runs through libmpv, which
uses ffmpeg 9, already in nebula's closure, so the client adds no nixploit
findings.

**White video.** HDR10 HEVC + DTS direct-played with audio and controls
working, but the picture stayed white. mpv was decoding (`vulkan-copy`,
`VO: [libmpv] … p010`). The web UI, drawn by Qt WebEngine on top of the mpv
layer, had lost its transparent background. Connecting to a server by hand
(the first launch) navigates cross-origin from the bundled page to the
server's web client, which moves the view to a new Chromium renderer process
that never gets the transparent background. Upstream fixed it by re-applying
the background on every renderer switch and page load.[^pr-1267] The fix is
in v2.1.0-pre1, but nixpkgs pins `2cb4a445` (2.0.0-unstable-2026-08-31), so
this module adds the commit (`e520e122`, a `webview.qml` change) as a
`fetchpatch`.

`needed` compares the package's `src.rev` with that pin. Once nixpkgs moves
the package, the stock build is installed and a NixOS warning says to delete
the file and put `pkgs.jellyfin-desktop` back in
[configuration](configuration.md). [gajim-pillow](gajim-pillow.md) and
[brotli-graft](brotli-graft.md) retire the same way.

Not the same bug as jellyfin/jellyfin-desktop#1291 (Flathub's Qt 6.11
runtime, where mpv's VO fails to open with `No render context set` and the
client silently falls back to the web player). Here that line appears only
at startup and the VO opens at playback.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/jellyfin-desktop.nix`](../../modules/hosts/nebula/jellyfin-desktop.nix)

[^pr-1267]: jellyfin/jellyfin-desktop#1267: Re-apply the transparent web view background after a renderer switch
