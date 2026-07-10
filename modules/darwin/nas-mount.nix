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
# Stable external path: the nix store is read-only, so the app is copied to
# ~/Applications and the Developer ID signature goes on that copy. Signing is
# automated in the activation block below via rcodesign + a dedicated
# sops-held PEM identity (key + cert chain minted specifically for this —
# NOT the personal Keychain identity, which stays non-exportable; see
# knowledge/decisions/nas-mount-codesigning.md, 2026-07-10 update). rcodesign
# signs from a key *file*, which sidesteps the login-keychain boundary that
# rules out OS `codesign` here (confirmed 2026-07-09: macOS walls the login
# keychain's private-key material off from root entirely, even via
# `launchctl asuser`). The copy is guarded by a stamp file holding the source
# store path, so the signature survives every `nrs` that doesn't actually
# rebuild the app. `sign-launchd-agents` remains the manual tool for OTHER
# launchd agents (see docs/darwin-codesigning.md).
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

      # Developer ID signing of the deployed copy, run as user k during
      # postActivation. sops-nix installs /run/secrets/* earlier in this SAME
      # postActivation run (its installScript is lib.mkAfter = order 1500, we
      # run at 1600), so the PEM is already present when the block executes.
      # The `or` fallback keeps eval working on a host that enables nas-mount
      # without declaring the secret — the runtime -r check warns and skips.
      pemSecret = config.sops.secrets.nas-signing-pem.path or "/run/secrets/nas-signing-pem";
      # Keep in sync with TIMESTAMP_URL in scripts/sign-launchd-agents.ts.
      timestampUrl = "http://timestamp.apple.com/ts01";

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
            # Re-copy only when the built app actually changed, so the
            # signature on the copy survives unrelated `nrs` runs. The stamp
            # holds the source store path (content-addressed, so a changed
            # app == a changed path).
            fresh=0
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
              fresh=1
            fi
            # Superseded by the .app bundle (was the pre-bundle exec target).
            rm -f "${home}/.local/state/nas-mount/nas-mount"
            # Developer ID signing with the dedicated sops-held identity.
            # Trigger on a fresh copy (only ad-hoc-signed from the store) or
            # a deployed bundle without a Developer ID signature (first
            # rollout, an earlier failed sign, tampering). Gate on Authority=,
            # NOT TeamIdentifier= — an Apple Development cert shows the same
            # team through the wrong chain (see the decision record). A
            # failure warns instead of failing activation; the Authority
            # check re-arms the sign attempt on the next activation.
            if [ "$fresh" = 1 ] || ! /usr/bin/codesign -dvv "${appDst}" 2>&1 | grep -q "Authority=Developer ID Application"; then
              if [ -r "${pemSecret}" ]; then
                if ${pkgs.rcodesign}/bin/rcodesign sign --pem-file "${pemSecret}" --timestamp-url "${timestampUrl}" "${appDst}"; then
                  echo "nas-mount: signed ${appDst} with Developer ID" >&2
                else
                  echo "nas-mount: WARNING: Developer ID signing failed; bundle keeps its current signature" >&2
                fi
              else
                echo "nas-mount: WARNING: signing PEM ${pemSecret} missing or unreadable; skipping Developer ID signing" >&2
              fi
            fi
          '
        '';
      };
    };
}
