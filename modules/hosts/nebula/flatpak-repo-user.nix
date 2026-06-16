{
  configurations.nixos.nebula.module =
    { config, pkgs, ... }:
    let
      # Wrapper that defaults the flatpak CLI to the per-user installation. Built
      # into the nix store and exposed via user k's profile
      # (/etc/profiles/per-user/k/bin), which sits ahead of /run/current-system/sw/bin
      # on PATH, so it shadows the system flatpak. flatpak hardcodes --system as the
      # default with no config to change it, so inject --user for scope-aware
      # subcommands; respect an explicit --user/-u/--system/--installation, and pass
      # non-scoped subcommands (run/ps/help/--version/build*) through untouched.
      # Calls the system's own flatpak by store path (no recursion, same version).
      flatpakUserDefault = pkgs.writeShellScriptBin "flatpak" ''
        set -euo pipefail
        real=${config.services.flatpak.package}/bin/flatpak

        # Respect an explicit scope if the caller already chose one.
        for arg in "$@"; do
          case "$arg" in
            -u | --user | --system | --installation | --installation=*)
              exec "$real" "$@"
              ;;
          esac
        done

        # First non-option argument is the subcommand.
        cmd=""
        for arg in "$@"; do
          case "$arg" in
            -*) ;;
            *)
              cmd="$arg"
              break
              ;;
          esac
        done

        case "$cmd" in
          install | uninstall | update | list | info | search | remotes | remote-add \
            | remote-modify | remote-delete | remote-ls | remote-info | mask | pin \
            | override | make-current | repair | config | create-usb)
            out=()
            inserted=0
            for arg in "$@"; do
              out+=("$arg")
              if [ "$inserted" -eq 0 ] && [ "$arg" = "$cmd" ]; then
                out+=(--user)
                inserted=1
              fi
            done
            exec "$real" "''${out[@]}"
            ;;
          *)
            exec "$real" "$@"
            ;;
        esac
      '';
    in
    {
      # Mask snowglobe's system flatpak-repo (becomes a symlink to /dev/null).
      systemd.services.flatpak-repo.enable = false;

      # Default the flatpak CLI to the per-user installation (wrapper above).
      users.users.k.packages = [ flatpakUserDefault ];

      # Per-user equivalent: register Flathub in ~/.local/share/flatpak at login.
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
