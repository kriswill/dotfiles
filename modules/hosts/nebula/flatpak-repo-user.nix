{
  configurations.nixos.nebula.module =
    { pkgs, ... }:
    {
      # Mask snowglobe's system flatpak-repo (becomes a symlink to /dev/null).
      systemd.services.flatpak-repo.enable = false;

      # Per-user equivalent: register Flathub in ~/.local/share/flatpak at login.
      # (The CLI is defaulted to --user by pkgs.flatpak-user, wired into user k's
      # packages in users/k.)
      systemd.user.services.flatpak-repo = {
        description = "Register the Flathub remote in the per-user flatpak installation";
        wantedBy = [ "default.target" ];
        path = [ pkgs.flatpak ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          # remote-add touches the network even with --if-not-exists, and a user
          # service has no network-online.target to lean on, so gate on a real DNS
          # lookup: resolves -> add the remote; never resolves (offline / fast
          # autologin) -> exit 1 so systemd *skips* the unit cleanly and retries next
          # login, rather than marking it failed.
          ExecCondition = pkgs.writeShellScript "flathub-dns-ready" ''
            i=0
            while [ $i -lt 15 ]; do
              ${pkgs.getent}/bin/getent ahosts dl.flathub.org >/dev/null 2>&1 && exit 0
              ${pkgs.coreutils}/bin/sleep 2
              i=$((i + 1))
            done
            echo "flatpak-repo: dl.flathub.org unresolvable after ~30s; skipping until next login" >&2
            exit 1
          '';
        };
        script = ''
          flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        '';
      };
    };
}
