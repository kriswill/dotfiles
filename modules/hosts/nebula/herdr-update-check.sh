# shellcheck shell=bash
# Body of herdr-update-check.service. Loaded verbatim by herdr-update-check.nix
# via builtins.readFile into writeShellApplication (which prepends the shebang and
# the runtimeInputs PATH, and runs shellcheck at build time). No Nix interpolation
# lives here — our fork's base version arrives as $HERDR_FORK_VERSION (the unit's
# environment, from pkgs.herdr.version), so this runs standalone too:
#
#   HERDR_FORK_VERSION=0.9.4 bash modules/hosts/nebula/herdr-update-check.sh
#
# Notifies when upstream's latest stable release (GitHub releases/latest skips
# the preview-* prereleases) is newer than the base of our vX.Y.Z-custom tag.
set -euo pipefail

ours="${HERDR_FORK_VERSION:?must be set to the base X.Y.Z of our vX.Y.Z-custom fork}"

tag=$(curl -fsSL --max-time 30 -H 'Accept: application/vnd.github+json' \
  https://api.github.com/repos/herdrdev/herdr/releases/latest |
  jq -r '.tag_name // empty') || true
# network/API hiccup or an unexpected tag shape — try again tomorrow
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 0
latest="${tag#v}"

newest=$(printf '%s\n' "$ours" "$latest" | sort -V | tail -1)
[ "$latest" != "$ours" ] && [ "$newest" = "$latest" ] || exit 0

# notify-send -A blocks until the notification is clicked or dismissed; the
# timeout ends an ignored one cleanly (it re-fires next day anyway).
action=$(timeout 12h notify-send -u critical -A open="Open $tag release" \
  "herdr $tag released upstream" \
  "Our fork is v$ours-custom — rebase custom onto $tag, tag $tag-custom, repoint the herdr input in flake.nix" ||
  true)
if [ "$action" = "open" ]; then
  xdg-open "https://github.com/herdrdev/herdr/releases/tag/$tag"
fi
