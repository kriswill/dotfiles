# Kris' neovide (system-level port of the old home-manager module).
#
# The neovide package is declared per-host in users.users.k.packages (see
# modules/hosts/*.nix); this module only carries the enable toggle, exactly as
# the old home-manager neovide module did. No NEOVIDE_NEOVIM_BIN override is
# needed: nvim and all its LSP/formatter tools are on the global PATH
# (modules/darwin/neovim.nix).
{
  flake.modules.darwin.neovide =
    {
      lib,
      config,
      ...
    }:
    {
      options.kriswill.neovide.enable = lib.mkEnableOption "Kris' neovide";
      config = lib.mkIf config.kriswill.neovide.enable { };
    };
}
