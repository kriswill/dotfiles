{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.kriswill.neovide.enable = lib.mkEnableOption "Kris' neovide";
  config = lib.mkIf config.kriswill.neovide.enable {
    home.packages = [ pkgs.neovide ];

    # Point neovide at home-manager's wrapped nvim so it inherits
    # programs.neovim.extraPackages on PATH (LSP servers, formatters, etc.).
    # pkgs.neovide alone would spawn a bare nvim without our extras.
    home.sessionVariables.NEOVIDE_NEOVIM_BIN = lib.getExe config.programs.neovim.finalPackage;
  };
}
