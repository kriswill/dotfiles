{ writeShellApplication, stow, git, coreutils }:
writeShellApplication {
  name = "dots-adopt";
  runtimeInputs = [ stow git coreutils ];
  text = ''
    # Capture a NEW config file into the dotfiles repo and replace the original
    # with a stow symlink.
    #
    #   usage: dots-adopt <pkg> <relpath-under-$HOME>
    #   e.g.   dots-adopt waybar .config/waybar/config
    #
    # This is for FIRST-TIME capture only (mv + stow). To pull live edits of an
    # ALREADY-tracked file back into the repo, use stow's own adopt instead:
    #   stow -d ~/src/dotfiles/home -t ~ --no-folding --adopt <pkg>
    # (that OVERWRITES the repo copy with the current filesystem copy).
    set -euo pipefail

    if [ "$#" -ne 2 ]; then
      echo "usage: dots-adopt <pkg> <relpath-under-\$HOME>" >&2
      echo "  e.g. dots-adopt waybar .config/waybar/config" >&2
      exit 2
    fi

    repo="$HOME/src/dotfiles"
    pkg="$1"
    rel="$2"
    src="$HOME/$rel"
    dst="$repo/home/$pkg/$rel"

    [ -e "$src" ] || { echo "no such file: $src" >&2; exit 1; }
    [ -L "$src" ] && { echo "$src is already a symlink (already adopted?)" >&2; exit 1; }

    mkdir -p "$(dirname "$dst")"
    mv "$src" "$dst"
    stow --dir="$repo/home" --target="$HOME" --no-folding "$pkg"
    git -C "$repo" add "home/$pkg"
    git -C "$repo" --no-pager diff --cached --stat
    echo "adopted $rel -> home/$pkg/$rel  (review: git -C $repo diff --cached)"
  '';
}
