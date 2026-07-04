{
  writeShellApplication,
  coreutils,
  diffutils,
}:
# Snapshot/restore gh's config.yml between the live file (~/.config/gh,
# app-owned) and the dotfiles repo, WITHOUT symlinking the live file.
#
# Why not stow-symlink it? `gh config set` / `gh alias set` rewrite config.yml
# via atomic rename, which replaces the stow symlink with a real file — the gh
# package then conflicts and gets skipped on every rebuild (bitten 2026-07-03).
# Same failure mode as Noctalia/Helium; same fix (see config/README.md).
#
# hosts.yml (auth/user state) is deliberately NOT captured: it's per-machine,
# gh-owned, and worthless in the repo.
#
#   gh-config capture   # live -> repo snapshot   (run after gh config/alias set)
#   gh-config restore   # snapshot -> live (atomic, 0600; e.g. a fresh machine)
#   gh-config diff      # show snapshot vs live
#
# No is-it-running guard: gh is a one-shot CLI, not a daemon — the only race
# is running `gh config set` concurrently with restore, which last-writer-wins.
writeShellApplication {
  name = "gh-config";
  runtimeInputs = [
    coreutils
    diffutils
  ];
  text = ''
    set -euo pipefail

    dir="''${GH_CONFIG_DIR:-$HOME/.config/gh}"
    live="$dir/config.yml"
    repo="''${DOTFILES:-$HOME/src/dotfiles}"
    snap="$repo/config/gh/config.yml"

    case "''${1:-}" in
      capture)
        [ -f "$live" ] || { echo "no live config.yml at $live" >&2; exit 1; }
        mkdir -p "$(dirname "$snap")"
        cp -f "$live" "$snap"
        chmod 644 "$snap"                 # repo copy; 0600 is restored on restore
        echo "captured: $live -> $snap"
        echo "review:   git -C $repo diff -- config/gh/config.yml"
        ;;
      restore)
        [ -f "$snap" ] || { echo "no snapshot at $snap" >&2; exit 1; }
        mkdir -p "$dir"
        [ -f "$live" ] && cp -f "$live" "$dir/.config.yml.bak"  # same-dir backup
        tmp="$dir/.config.yml.new.$$"
        cp -f "$snap" "$tmp"
        chmod 600 "$tmp"                 # gh keeps its config 0600; re-harden
        mv -f "$tmp" "$live"             # atomic rename — gh's own save pattern
        echo "restored (atomic, 0600): $snap -> $live"
        ;;
      diff)
        [ -f "$snap" ] || { echo "no snapshot at $snap" >&2; exit 1; }
        [ -f "$live" ] || { echo "no live file at $live" >&2; exit 1; }
        if diff -u "$snap" "$live"; then echo "(in sync)"; fi
        ;;
      *)
        echo "usage: gh-config {capture|restore|diff}" >&2
        echo "  capture  live -> repo snapshot (config/gh/config.yml)" >&2
        echo "  restore  repo snapshot -> live (atomic, 0600)" >&2
        echo "  diff     show snapshot vs live" >&2
        exit 2
        ;;
    esac
  '';
}
