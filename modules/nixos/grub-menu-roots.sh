# shellcheck shell=bash
# grub-menu-roots: make every system the GRUB menu boots a GC root, so no
# garbage collection (the nightly nix-gc, a manual nix-collect-garbage -d,
# nh clean) can collect a closure the menu still lists. That was the
# 2026-06-16 emergency-mode boot. It runs from boot.loader.grub.extraInstallCommands,
# right after install-grub.pl writes the menu, as root, inside
# switch-to-configuration's own bootloader step. Roots follow the menu: an
# entry the menu drops loses its root, and its closure becomes collectable.
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

# Access: root:root 0755, like Nix's own gcroots, gcroots/auto and the per-user
# dirs (which Nix chmods to 0755 itself). Root-only write is the point: whoever
# can delete a root can let GC take a menu entry. World-read hides nothing,
# since the daemon reports gcroots-dir roots uncensored to any user and the
# profile links show the same paths. It also never depends on the collector
# being root: Nix skips a directory it cannot read ("cannot read potential
# root") and so treats its roots as gone. The chmod corrects a directory made
# 0700 by the first version (mktemp -d).
mkdir -p "$roots"
chmod 0755 "$roots"
# Any directory under gcroots roots its links forever, so the temp sets of
# earlier versions (grub-menu.new.XXXXXX, .new, .old) must not linger.
rm -rf "$roots".new* "$roots.old"

# Updated in place, adding before removing, so the set never holds fewer roots
# than the old or the new menu needs. nix-store --add-root registers each root
# with a garbage collection already running (addTempRoot, through its socket)
# before linking it, which a plain ln -s does not; that closes the window in
# which a nightly prune could drop a generation the menu was just written with.
# It also records a pointer in gcroots/auto. A path that is no longer valid
# can't be protected anyway; it is reported, not fatal.
declare -A want=()
for p in "${paths[@]}"; do
  want[$p]=1
  if nix-store --check-validity "/nix/store/$p" 2>/dev/null; then
    nix-store --add-root "$roots/$p" --realise "/nix/store/$p" >/dev/null
  else
    echo "grub-menu-roots: the menu lists /nix/store/$p, which is no longer valid" >&2
  fi
done
for link in "$roots"/*; do
  [ -L "$link" ] || continue
  if [ -z "${want[${link##*/}]:-}" ]; then rm -f "$link"; fi
done
