{
  flake.modules.nixos.dotfiles-stow =
    # Deploy the GNU Stow dotfiles tree (../../home, relative to the repo root) into
    # the user's home on every `nixos-rebuild switch`.
    #
    # Operates on the LIVE repo path, never `${./home}` — interpolating a Nix path
    # would copy the tree into a read-only /nix/store path, breaking link stability,
    # in-place editing, and the adopt workflow. The symlinks must point at the
    # stable, writable repo checkout.
    { pkgs, ... }:
    let
      user = "k";
      home = "/home/k";
      stowDir = "${home}/src/dotfiles/home";
    in
    {
      environment.systemPackages = [
        pkgs.stow
        pkgs.dots-adopt
      ];

      system.activationScripts.stowDotfiles = {
        deps = [ "users" ]; # run after user k exists
        text = ''
          # Activation snippets share one shell, so `exit`/`set -u` must be confined to
          # a subshell or they'd abort/alter the rest of boot-time activation.
          (
          set -u
          if [ ! -d "${stowDir}" ]; then
            echo "stow: ${stowDir} not present yet, skipping" >&2
            exit 0
          fi
          # Canonical (symlink-resolved) stow dir. stow resolves --dir before
          # computing link targets, so the links it OWNS go through this path. A
          # link reaching the same file via the ~/src/dotfiles convenience symlink
          # (e.g. a hand-made `ln -s ../../src/dotfiles/...`) does NOT match, so stow
          # disowns it and skips the whole package — silently dropping any new file
          # in that package (this is how the niri wallpaper went missing).
          canon="$(${pkgs.coreutils}/bin/realpath "${stowDir}")"
          # Auto-discover packages: every directory under home/ is one stow package,
          # so newly adopted apps are deployed on the next rebuild with no nix edit.
          for pkgdir in "${stowDir}"/*/; do
            [ -d "$pkgdir" ] || continue
            pkg="$(${pkgs.coreutils}/bin/basename "$pkgdir")"
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
            if ${pkgs.util-linux}/bin/runuser -u ${user} -- env HOME=${home} \
                 ${pkgs.stow}/bin/stow \
                   --dir="${stowDir}" --target="${home}" \
                   --no-folding --restow "$pkg"; then
              echo "stow: restowed $pkg" >&2
            else
              echo "stow: WARNING conflict/error on $pkg, skipped" >&2
            fi
          done
          )
        '';
      };
    }

  ;
}
