{
  writeShellApplication,
  coreutils,
  diffutils,
  procps,
}:
# Snapshot/restore Noctalia's settings.toml between the live state dir
# (~/.local/state/noctalia, app-owned) and the dotfiles repo, WITHOUT symlinking
# the live file.
#
# Why not just stow-symlink settings.toml? Noctalia saves it by writing a
# complete same-dir temp then `mv -f` over the target (atomic rename), which
# replaces any per-file symlink with a real file — breaking stow tracking on the
# first GUI save. A directory-symlink variant avoids that but then the repo's
# tracked file *is* the live file, so routine git ops (`reset --hard`,
# `checkout`, `clean -xfd`) silently revert/delete/corrupt the running config,
# and the whole runtime state dir (clipboard with secrets, nested plugin .git)
# ends up physically in the repo. A bake-off (5 adversarial lenses) found that
# approach has 2 critical + ~6 high data-loss vectors; this snapshot/sync model
# has one narrow, opt-in one. See docs/noctalia.md "Tracking settings.toml".
#
#   noctalia-config capture   # live  -> repo snapshot   (run after GUI edits)
#   noctalia-config restore   # snapshot -> live (atomic; e.g. a fresh machine)
#   noctalia-config diff      # show snapshot vs live
writeShellApplication {
  name = "noctalia-config";
  runtimeInputs = [
    coreutils
    diffutils
    procps
  ];
  text = ''
    set -euo pipefail

    state="''${NOCTALIA_STATE:-$HOME/.local/state/noctalia}"
    live="$state/settings.toml"
    repo="''${DOTFILES:-$HOME/src/dotfiles}"
    snap="$repo/config/noctalia/settings.toml"

    case "''${1:-}" in
      capture)
        [ -f "$live" ] || { echo "no live settings.toml at $live" >&2; exit 1; }
        mkdir -p "$(dirname "$snap")"
        cp -f "$live" "$snap"
        chmod 644 "$snap"                 # repo copy; 0600 is restored on restore
        echo "captured: $live -> $snap"
        echo "review:   git -C $repo diff -- config/noctalia/settings.toml"
        ;;
      restore)
        [ -f "$snap" ] || { echo "no snapshot at $snap" >&2; exit 1; }
        # A GUI save racing this restore can be lost (last-writer-wins). Refuse
        # while noctalia runs unless FORCE=1.
        if pgrep -x noctalia >/dev/null 2>&1 && [ "''${FORCE:-}" != 1 ]; then
          echo "noctalia is running — quit it first, or re-run with FORCE=1." >&2
          exit 1
        fi
        mkdir -p "$state"
        [ -f "$live" ] && cp -f "$live" "$state/.settings.toml.bak"  # same-dir backup
        tmp="$state/.settings.toml.new.$$"
        cp -f "$snap" "$tmp"
        chmod 600 "$tmp"                 # git records only the exec bit; re-harden
        mv -f "$tmp" "$live"             # atomic rename — noctalia's own save pattern
        if command -v noctalia >/dev/null 2>&1; then noctalia msg config-reload || true; fi
        echo "restored (atomic, 0600): $snap -> $live"
        ;;
      diff)
        [ -f "$snap" ] || { echo "no snapshot at $snap" >&2; exit 1; }
        [ -f "$live" ] || { echo "no live file at $live" >&2; exit 1; }
        if diff -u "$snap" "$live"; then echo "(in sync)"; fi
        ;;
      *)
        echo "usage: noctalia-config {capture|restore|diff}" >&2
        echo "  capture  live -> repo snapshot (config/noctalia/settings.toml)" >&2
        echo "  restore  repo snapshot -> live (atomic, 0600; quit noctalia first)" >&2
        echo "  diff     show snapshot vs live" >&2
        exit 2
        ;;
    esac
  '';
}
