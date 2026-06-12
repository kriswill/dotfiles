{
  flake.modules.homeManager.neovide =
    { lib, ... }:

    {
      # The neovide package moved to the nix-darwin per-user profile (gated on
      # this toggle) — see modules/darwin/user-packages.nix. The enable option
      # stays here so the home-manager default + the darwin gating both resolve.
      # No NEOVIDE_NEOVIM_BIN override needed: nvim and all its LSP/formatter
      # tools are on the global PATH (modules/darwin/neovim.nix).
      options.kriswill.neovide.enable = lib.mkEnableOption "Kris' neovide";
    };
}
