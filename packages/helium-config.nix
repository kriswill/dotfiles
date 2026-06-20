{ writeShellApplication, coreutils, jq, diffutils, procps, age }:
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
# Only an ALLOWLIST of files is touched. The JSON settings files are jq-filtered to
# drop high-churn / footgun keys (window geometry, exit_type=Crashed, timestamps,
# metrics) and key-sorted for stable diffs; real settings are kept.
#
# Snapshot files are ENCRYPTED at rest: each captured file is armored-age-encrypted
# to config/helium/<rel>.age, so the repo (PUBLIC on GitHub) holds only opaque
# ciphertext — no browsing PII (visited domains, the Google account identity in
# Local State, cookies, saved logins) leaks. The age recipient is age1gduheq5…
# (== keyring.age.nebula / .sops.yaml); encrypting needs only that PUBLIC key, so
# `capture` runs unattended. Decryption (restore/diff) pulls the age identity from
# 1Password via `op read` into memory — never off the unencrypted disk.
#
#   helium-config capture   # live  -> repo snapshot   (run after settings edits)
#   helium-config restore   # snapshot -> live (decrypt, atomic; quit Helium first)
#   helium-config diff      # show snapshot (decrypted) vs (filtered) live
#
# `op` (1Password CLI) is NOT pinned here — like packages/cbissue.sh it resolves
# from the ambient PATH (/run/wrappers/bin/op), unlocked via the desktop app.
writeShellApplication {
  name = "helium-config";
  runtimeInputs = [ coreutils jq diffutils procps age ];
  text = builtins.readFile ./helium-config.sh;
}
