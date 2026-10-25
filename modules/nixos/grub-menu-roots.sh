# shellcheck shell=bash
# grub-menu-roots: make every system the GRUB menu boots a GC root, so no
# garbage collection (the nightly nix-gc, a manual nix-collect-garbage -d,
# nh clean) can collect a closure the menu still lists. That was the
# 2026-06-16 emergency-mode boot. It runs from boot.loader.grub.extraInstallCommands,
# right after install-grub.pl writes the menu, as root, inside
# switch-to-configuration's own bootloader step. The set is rebuilt from the
# new menu each time and swapped in whole, so roots follow the menu: an entry
# the menu drops loses its root, and its closure becomes collectable.
# install-grub writes each entry with init=<resolved system>/init. Loaded by
# modules/nixos/generations.nix into writeShellApplication.
#
#   grub-menu-roots ROOTS_DIR GRUB_CFG…
set -euo pipefail

roots=$1
shift
mapfile -t paths < <(grep -ho 'init=/nix/store/[^ ]*' "$@" \
  | sed -E 's#^init=/nix/store/([^/]+).*#\1#' | sort -u || true)
if [ "${#paths[@]}" -eq 0 ]; then
  # A changed menu format must not fail the bootloader install, nor drop the
  # roots that still protect the last menu that could be read.
  echo "grub-menu-roots: no init= entries in $*; keeping the previous roots" >&2
  exit 0
fi
new="$(mktemp -d "$roots.new.XXXXXX")"
for p in "${paths[@]}"; do
  ln -s "/nix/store/$p" "$new/$p"
done
rm -rf "$roots.old"
if [ -e "$roots" ]; then mv "$roots" "$roots.old"; fi
mv "$new" "$roots"
rm -rf "$roots.old"
