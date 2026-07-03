# Helium user tooling for `k`.
#
# helium-config — snapshot/restore Helium's user settings (Default/Bookmarks,
# Default/Preferences, Local State) into the dotfiles repo (config/helium/...)
# WITHOUT symlinking the live profile. Helium (Chromium) rewrites those files via
# atomic rename, which breaks a stow symlink on the first save; and `home/` is
# auto-restowed every rebuild, so a home/helium package would symlink the repo
# copy over the live profile and clobber the running config. So we sync
# explicitly: `helium-config capture` after settings edits, `restore` on a fresh
# machine (quit Helium first). Allowlist-only — secrets/state never enter the
# repo. Same pattern as noctalia-config. The system-level Helium config (browser
# enable + managed policies) lives in modules/nixos/helium/.
# See pkgs/helium-config.nix.
{
  configurations.nixos.nebula.module =
    { pkgs, ... }:
    {
      users.users.k.packages = [ pkgs.helium-config ];
    };
}
