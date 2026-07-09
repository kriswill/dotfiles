# Auto-mount the UNAS Pro 4's Personal-Drive SMB share at login via a launchd
# user agent. See docs/unifi-dream-machine.md for how nas.home.lan (a UniFi
# "Local DNS Record", not a static DNS entry) was set up. `-N` is required —
# a launchd agent has no session to show an interactive password sheet, so it
# only works because macOS already has a matching keychain entry (confirmed
# 2026-07-09: the same entry serves both the Bonjour and DNS hostnames, since
# macOS's SMB client keys off the server's negotiated identity, not the
# literal string used to connect — see the manual's "two mechanisms" note).
#
# Why an .app bundle for a background mount helper: System Settings > Login
# Items attributes a *bare* launchd agent to nobody — it reads "Item from
# unidentified developer" no matter how well the executable itself is signed
# (verified: signing the binary with a real Developer ID changed nothing).
# Apple's documented answer (DTS, developer.apple.com/forums/thread/721918)
# is to point the plist's AssociatedBundleIdentifiers at a real, signed app
# bundle; that bundle is also what supplies the custom icon. So pkgs/nas-mount
# ships both $out/bin/nas-mount and $out/Applications/NasMount.app.
#
# BTM cache gotcha: Background Task Management keys its record on the plist
# path and does NOT re-read when the plist's contents change — after any
# ProgramArguments/exec-path change (or after signing the app), the Login
# Items pane keeps showing stale attribution even across launchctl
# bootout/bootstrap. The only non-invasive refresh found (2026-07-09):
# `launchctl bootout ...; rm <plist>`, wait a few seconds for btmd to drop
# the record, restore the plist, `launchctl bootstrap ...`, then quit and
# reopen System Settings. (`sfltool resetbtm` also works but nukes and
# re-prompts EVERY login item on the machine.)
#
# Stable external path: nix-darwin's own root-run activation context cannot
# codesign this (confirmed 2026-07-09 — modern macOS walls the login
# keychain's private-key material off from root entirely, even via
# `launchctl asuser`; only a process genuinely running as the user in their
# real session can use it), and the nix store is read-only regardless. So the
# app is copied to ~/Applications and signing is a deliberate manual step the
# machine's owner runs (`sign-launchd-agents`, or see docs/unifi-dream-machine.md)
# against that copy. The copy is guarded by a stamp file holding the source
# store path, so an existing manual signature survives every `nrs` that
# doesn't actually rebuild the app.
{
  flake.modules.darwin.nas-mount =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.services.nas-mount;
      home = "/Users/k";
      mountPoint = "${home}/nas";
      share = "//k@nas.home.lan/Personal-Drive";
      bundleId = "net.kris.nas-mount";

      mountPkg = pkgs.nas-mount.override { inherit bundleId; };
      appSrc = "${mountPkg}/Applications/NasMount.app";
      appDst = "${home}/Applications/NasMount.app";
      execPath = "${appDst}/Contents/MacOS/nas-mount";
      stamp = "${home}/.local/state/nas-mount/source-store-path";

      # Written directly rather than via `launchd.user.agents`: that option's
      # serviceConfig is a *closed* submodule (nix-darwin's modules/launchd/
      # launchd.nix enumerates every allowed key) and has no
      # AssociatedBundleIdentifiers — which is the one key this whole exercise
      # needs. launchd.user.agents just funnels into environment.userLaunchAgents
      # anyway (modules/launchd/default.nix), so write the plist ourselves.
      plist = pkgs.writeText "org.nixos.nas-mount.plist" ''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>org.nixos.nas-mount</string>
          <key>AssociatedBundleIdentifiers</key>
          <array>
            <string>${bundleId}</string>
          </array>
          <key>ProgramArguments</key>
          <array>
            <string>${execPath}</string>
            <string>${mountPoint}</string>
            <string>${share}</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <!-- retry if the NAS/network wasn't ready at login -->
          <key>StartInterval</key>
          <integer>300</integer>
          <key>StandardOutPath</key>
          <string>${home}/Library/Logs/nas-mount.log</string>
          <key>StandardErrorPath</key>
          <string>${home}/Library/Logs/nas-mount.log</string>
        </dict>
        </plist>
      '';
    in
    {
      options.services.nas-mount.enable = lib.mkEnableOption "auto-mount the UNAS Pro 4 Personal-Drive SMB share at login";
      config = lib.mkIf cfg.enable {
        environment.userLaunchAgents."org.nixos.nas-mount.plist".source = plist;

        # Order 1600: same slot dotfiles-stow (1500) and other user-context
        # postActivation steps use — see claude-account-selector/default.nix.
        system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
          /usr/bin/sudo -u k --set-home /bin/sh -c '
            set -e
            mkdir -p "${home}/Applications" "$(dirname "${stamp}")"
            # Re-copy only when the built app actually changed, so a manual
            # signature on the copy survives unrelated `nrs` runs. The stamp
            # holds the source store path (content-addressed, so a changed
            # app == a changed path).
            if [ "$(cat "${stamp}" 2>/dev/null)" != "${appSrc}" ]; then
              rm -rf "${appDst}"
              cp -R "${appSrc}" "${appDst}"
              # cp preserves the store'"'"'s read-only mode; codesign/rcodesign
              # must be able to write the signature into the bundle.
              chmod -R u+w "${appDst}"
              printf %s "${appSrc}" > "${stamp}"
              # A cp-installed app is invisible to LaunchServices until
              # registered, and Login Items resolves the bundle-id
              # association through LS — without this the group shows a
              # blank icon and the raw developer name only.
              /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${appDst}"
            fi
            # Superseded by the .app bundle (was the pre-bundle exec target).
            rm -f "${home}/.local/state/nas-mount/nas-mount"
          '
        '';
      };
    };
}
