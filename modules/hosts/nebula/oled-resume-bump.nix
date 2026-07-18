{
  # DP-3 (ASUS PG34WCDM OLED) sometimes stays black after resume from S3: the
  # panel doesn't wake even though Hyprland reports the output live
  # (disabled:false, dpmsStatus:1). A DPMS off/on bounce on just that output
  # wakes it (verified 2026-07-15), so do it on every resume. If a plain DPMS
  # bounce ever stops sufficing, escalate to the two-step mode bounce in
  # docs/hyprland.md → Learned behaviours (same failure class as the 240Hz
  # no-DSC blank).
  configurations.nixos.nebula.module =
    { config, pkgs, ... }:
    {
      powerManagement.resumeCommands = ''
        # Runs as root; talk to k's Hyprland instance as k so the IPC peer
        # matches. hyprctl must come from programs.hyprland.package, not
        # pkgs.hyprland (see docs/hyprland.md — mismatched-closure gotcha).
        hyprDir=/run/user/1000/hypr
        if [ -d "$hyprDir" ]; then
          sig=$(${pkgs.coreutils}/bin/ls -t "$hyprDir" | ${pkgs.coreutils}/bin/head -n1)
          if [ -n "$sig" ]; then
            hyprBump() {
              ${pkgs.util-linux}/bin/runuser -u k -- ${pkgs.coreutils}/bin/env \
                XDG_RUNTIME_DIR=/run/user/1000 \
                HYPRLAND_INSTANCE_SIGNATURE="$sig" \
                ${config.programs.hyprland.package}/bin/hyprctl dispatch "$1"
            }
            ${pkgs.coreutils}/bin/sleep 2
            hyprBump 'hl.dsp.dpms("off", "DP-3")' || true
            ${pkgs.coreutils}/bin/sleep 1
            hyprBump 'hl.dsp.dpms("on", "DP-3")' || true
          fi
        fi
      '';
    };
}
