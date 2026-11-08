{
  # Jellyfin Desktop (the official client, ex-Jellyfin Media Player) with
  # upstream's fix for "white video": audio and the player controls work but
  # an opaque white web page covers mpv's picture. Connecting to a server by
  # hand (first launch) navigates the web view cross-origin onto a new
  # Chromium renderer process, and the view's transparent background isn't
  # re-applied to it. Upstream jellyfin/jellyfin-desktop#1267 (e520e122,
  # in v2.1.0-pre1) re-applies it on every renderer switch and page load.
  # nixpkgs pins 2cb4a445 (2.0.0-unstable-2026-08-31), from before the fix.
  #
  # The patch is tied to that exact rev: once nixpkgs moves the package, the
  # stock build is used and every evaluation warns to delete this file (move
  # pkgs.jellyfin-desktop back into configuration.nix's systemPackages).
  configurations.nixos.nebula.module =
    { pkgs, lib, ... }:
    let
      pinnedRev = "2cb4a4456fd29b5b62d825ef0e5df93ed6913328";
      needed = pkgs.jellyfin-desktop.src.rev == pinnedRev;
      patched = pkgs.jellyfin-desktop.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (pkgs.fetchpatch {
            name = "jellyfin-desktop-reapply-transparent-background.patch";
            url = "https://github.com/jellyfin/jellyfin-desktop/commit/e520e122f5f6ae6915f6ea2e70a9d42af777df4a.patch";
            hash = "sha256-RPyD2pwtqi8pXOe44o/rSI/gRzZyhVw+iV8FN23fIU8=";
          })
        ];
      });
    in
    {
      # mpv playback; reuses the system's ffmpeg 9 (no extra nixploit findings).
      environment.systemPackages = [ (if needed then patched else pkgs.jellyfin-desktop) ];
      warnings =
        lib.optional (!needed)
          "nixpkgs moved jellyfin-desktop to ${pkgs.jellyfin-desktop.version} (rev ${pkgs.jellyfin-desktop.src.rev}), so the white-video patch is switched off. If that version includes jellyfin/jellyfin-desktop#1267 (v2.1.0-pre1+), delete modules/hosts/nebula/jellyfin-desktop.nix and put pkgs.jellyfin-desktop back in configuration.nix.";
    };
}
