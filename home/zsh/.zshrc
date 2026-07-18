# NOT read by zsh: ZDOTDIR=$HOME/.config/zsh is exported in /etc/zshenv on
# both OSes (modules/{darwin,nixos}/zsh.nix), so the real rc is
# ~/.config/zsh/.zshrc and zsh never opens this file.
#
# It exists for GUI apps that can't see the nix PATH: macOS launchd gives
# Dock/Finder-launched apps the bare /usr/bin:/bin:/usr/sbin:/sbin, and the
# common workaround (Claude Code desktop, editors) is to read ~/.zshrc and
# extract PATH from it — a probe that knows nothing of ZDOTDIR. Give those
# probes the nix directories. Keep this file limited to PATH.
export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
