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
      # Auto-discover packages: every directory under home/ is one stow package,
      # so newly adopted apps are deployed on the next rebuild with no nix edit.
      for pkgdir in "${stowDir}"/*/; do
        [ -d "$pkgdir" ] || continue
        pkg="$(${pkgs.coreutils}/bin/basename "$pkgdir")"
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
