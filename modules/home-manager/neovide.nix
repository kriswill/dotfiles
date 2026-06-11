{
  flake.modules.homeManager.neovide =
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
        # No NEOVIDE_NEOVIM_BIN override needed anymore: nvim and all its
        # LSP/formatter tools are on the global PATH (modules/darwin/neovim.nix).
      };
    };
}
