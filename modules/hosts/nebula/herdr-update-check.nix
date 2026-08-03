# Daily reminder to drop the herdr preview-flake pin (flake.nix) once
# nixos-unstable ships a herdr newer than the 0.7.5 the pin shadows — see
# docs/fastfetch.md. One raw-file HTTP fetch, no nix eval. Pops a dismissable
# critical notification; clicking the action opens the upstream releases page.
# DELETE THIS FILE together with the pin.
{
  configurations.nixos.nebula.module =
    { pkgs, ... }:
    {
      systemd.user.services.herdr-update-check = {
        description = "Notify when nixos-unstable carries herdr > 0.7.5 (drop the preview pin)";
        serviceConfig = {
          Type = "oneshot";
          # notify-send -A blocks until the notification is clicked or
          # dismissed; give it all day instead of systemd's default 90s
          # (which would kill notify-send and tear the notification down).
          TimeoutStartSec = "13h";
        };
        path = [
          pkgs.curl
          pkgs.libnotify
          pkgs.xdg-utils
        ];
        script = ''
          pinned="0.7.5" # the stable version the preview pin shadows
          v=$(curl -fsSL --max-time 30 \
            https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-unstable/pkgs/by-name/he/herdr/package.nix \
            | sed -n 's/.*version = "\([0-9.]*\)".*/\1/p' | head -1) || true
          [ -n "$v" ] || exit 0 # network/path hiccup — try again tomorrow
          newest=$(printf '%s\n' "$pinned" "$v" | sort -V | tail -1)
          if [ "$newest" != "$pinned" ]; then
            # timeout < TimeoutStartSec so an ignored notification ends the
            # run cleanly (it re-fires next day anyway).
            action=$(timeout 12h notify-send -u critical -A open="Open herdr releases" \
              "herdr $v is in nixos-unstable" \
              "Stable now exceeds the pinned $pinned — drop the preview pin (flake.nix, modules/nixos/herdr.nix); see docs/fastfetch.md" \
              || true)
            if [ "$action" = "open" ]; then
              xdg-open "https://github.com/ogulcancelik/herdr/releases"
            fi
          fi
        '';
      };

      systemd.user.timers.herdr-update-check = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          # Fire on next login if the machine was off/asleep at the scheduled time.
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    };
}
