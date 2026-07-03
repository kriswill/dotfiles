# Pure builder for the stow restow/self-heal activation script, shared by
# modules/darwin/dotfiles-stow.nix and modules/nixos/dotfiles-stow.nix (lib/
# sits outside modules/ so import-tree doesn't treat this as a flake-parts
# module). The two OSes differ only in paths, the run-as-user command, and
# which stow packages they skip — everything else (canonicalization, per-file
# self-heal, conflict-tolerant restow) must stay byte-identical, and one shared
# generator is what keeps a future fix from landing on only one OS.
#
# Args:
#   pkgs        — for coreutils/findutils/stow store paths
#   home        — the user's home dir (/Users/k | /home/k)
#   stowDir     — the live repo's home/ tree (never a ${./home} store copy)
#   skip        — stow packages belonging to the other OS (list of names)
#   skipReason  — label in the skip log line ("linux-only" | "darwin-only")
#   runAsUser   — command prefix that runs the stow invocation as the user
#                 (darwin: sudo -u <user> --set-home; nixos: runuser + env HOME)
{
  pkgs,
  home,
  stowDir,
  skip,
  skipReason,
  runAsUser,
}:
let
  skipPattern = builtins.concatStringsSep "|" skip;
in
''
  # Activation snippets share one shell, so `exit`/`set -u` must be confined to
  # a subshell or they'd abort/alter the rest of activation.
  (
  set -u
  if [ ! -d "${stowDir}" ]; then
    echo "stow: ${stowDir} not present yet, skipping" >&2
    exit 0
  fi
  # Canonical (symlink-resolved) stow dir. stow resolves --dir before
  # computing link targets, so the links it OWNS go through this path. A
  # link reaching the same file via a ~/src/dotfiles convenience symlink
  # (e.g. a hand-made `ln -s ../../src/dotfiles/...`) does NOT match, so stow
  # disowns it and skips the whole package — silently dropping any new file
  # in that package.
  canon="$(${pkgs.coreutils}/bin/realpath "${stowDir}")"
  # Auto-discover packages: every directory under home/ is one stow package,
  # so newly adopted apps are deployed on the next rebuild with no nix edit.
  for pkgdir in "${stowDir}"/*/; do
    [ -d "$pkgdir" ] || continue
    pkg="$(${pkgs.coreutils}/bin/basename "$pkgdir")"
    # Per-OS scoping: skip packages that belong to the other OS.
    case "$pkg" in
      ${skipPattern})
        echo "stow: skipping $pkg (${skipReason})" >&2
        continue
        ;;
    esac
    # Self-heal: drop any target symlink that IS one of this package's files
    # but reaches it through a symlinked (non-canonical) path, so the restow
    # below recreates it canonically instead of conflict-skipping the whole
    # package. A link is "stale" when it resolves (follow symlinks) into the
    # repo yet its textual target (NO symlink-follow) does not — i.e. it only
    # lands in-repo via the convenience symlink. Already-canonical links fail
    # the first test and are left untouched, so healthy packages see no churn.
    ( cd "$pkgdir" && ${pkgs.findutils}/bin/find . \( -type f -o -type l \) -printf '%P\n' ) |
    while IFS= read -r rel; do
      link="${home}/$rel"
      [ -L "$link" ] || continue
      raw="$(${pkgs.coreutils}/bin/readlink "$link")"
      # Resolve the target's TEXT (no symlink-follow). An absolute target is
      # used as-is; a relative one is joined to the link's own directory.
      case "$raw" in
        /*) textual="$(${pkgs.coreutils}/bin/realpath -m --no-symlinks "$raw")" ;;
        *)  textual="$(${pkgs.coreutils}/bin/realpath -m --no-symlinks \
                         "$(${pkgs.coreutils}/bin/dirname "$link")/$raw")" ;;
      esac
      case "$textual" in "$canon"/*) continue ;; esac   # already canonical
      real="$(${pkgs.coreutils}/bin/readlink -f "$link" 2>/dev/null || true)"
      case "$real" in
        "$canon"/*)                                      # our file, wrong path
          rm -f "$link"
          echo "stow: healed stale link $link" >&2 ;;
      esac
    done
    # --no-folding keeps ~/.config/<app> a real dir (only files symlinked),
    # so app-generated siblings don't leak into the repo. Tolerate per-package
    # conflicts (log + continue) so one bad package never fails the rebuild.
    if ${runAsUser} \
         ${pkgs.stow}/bin/stow \
           --dir="${stowDir}" --target="${home}" \
           --no-folding --restow "$pkg"; then
      echo "stow: restowed $pkg" >&2
    else
      echo "stow: WARNING conflict/error on $pkg, skipped" >&2
    fi
  done
  )
''
