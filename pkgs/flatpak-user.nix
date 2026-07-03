# A drop-in `flatpak` that defaults the CLI to the per-user installation.
#
# flatpak hardcodes --system as the default and offers no config to change it, so
# this wrapper (placed earlier on PATH than the real flatpak) injects --user for
# scope-aware subcommands. It respects an explicit --user/-u/--system/--installation
# and passes non-scoped subcommands (run/ps/help/--version/build*) through untouched.
# Calls the real flatpak by store path, so no recursion and the same version.
{
  writeShellApplication,
  flatpak,
}:
writeShellApplication {
  name = "flatpak";
  text = ''
    real=${flatpak}/bin/flatpak

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
        # Insert --user immediately after the subcommand.
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
}
