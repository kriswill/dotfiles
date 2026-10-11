# Everyday CLI toolbox on nebula — the NixOS twin of modules/darwin/user-packages.nix.
#
# Until 2026-10 snowglobe-factory enabled all of these by default
# (`slib.setDefault true` in nixosModules/snowglobe-factory/default.nix) and the
# dotfiles leaned on that: `cat`→bat and `lg`→lazygit aliases (home/zsh),
# `rg` in the git config, snacks' lazygit keymap (home/nvim), the yazi `y`
# wrapper (home/zsh/yazi.sh — nebula gets yazi's config from snowglobe's
# module because home/yazi is skip-listed on nixos), jq in the Hyprland
# screenshot bind, brightnessctl in the XF86 brightness binds, and `, foo` /
# command-not-found from nix-index-database. snowglobe's "significant debloat
# effort" (1f9de238) flipped them all off and dropped the nix-index-database
# input, so the host re-enables them here. Tools that other modules already
# install (eza/fzf/fd/btop/… in zsh.nix, git.nix, nvim) are not repeated.
{ inputs, ... }:
{
  flake.modules.nixos.user-packages =
    { config, ... }:
    {
      imports = [ inputs.nix-index-database.nixosModules.default ];

      programs = {
        # nixpkgs modules (snowglobe has no module of its own for these)
        bat.enable = true;
        lazygit.enable = config.programs.git.enable;

        # snowglobe-factory program modules (nixosModules/nixos/programs/*)
        brightnessctl.enable = true;
        jq.enable = true;
        ripgrep.enable = true;
        yazi.enable = true;
        zip.enable = true;

        # Prebuilt nix-index db: zsh command-not-found + comma-with-db (`, prog`).
        # modules/nixos/determinate.nix overlays `comma` to use the system nix.
        nix-index-database.comma.enable = true;
      };
    };
}
