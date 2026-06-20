{ writeShellApplication, coreutils, jq, diffutils, procps }:
# Snapshot/restore Helium's user settings between the live profile
# (~/.config/net.imput.helium, app-owned) and the dotfiles repo, WITHOUT
# symlinking the live files.
#
# Why not stow? Helium (Chromium) saves Preferences/Bookmarks/Local State via a
# same-dir temp + atomic rename(), which replaces a per-file stow symlink with a
# real file on the first save — silently breaking tracking. And `home/` is
# auto-restowed every rebuild (modules/nixos/dotfiles-stow.nix), so a home/helium
# package would symlink the repo copy OVER the live profile and clobber the
# running config. Same problem (and same fix) as noctalia-config: keep live and a
# repo snapshot physically separate, synced explicitly. See packages/
# noctalia-config.nix and the helium docs.
#
# Only an ALLOWLIST of settings files is touched — secrets/state (Login Data,
# Cookies, History, Web Data, IndexedDB, …) are never copied into the repo. The
# JSON files are jq-filtered to drop high-churn / footgun keys (window geometry,
# exit_type=Crashed, timestamps, metrics) and key-sorted for stable diffs; real
# settings are kept.
#
#   helium-config capture   # live  -> repo snapshot   (run after settings edits)
#   helium-config restore   # snapshot -> live (atomic; quit Helium first)
#   helium-config diff      # show snapshot vs (filtered) live
writeShellApplication {
  name = "helium-config";
  runtimeInputs = [ coreutils jq diffutils procps ];
  text = builtins.readFile ./helium-config.sh;
}
