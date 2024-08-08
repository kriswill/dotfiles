{ inputs, lib, pkgs, ... }:
let nvim = inputs.nixvim.packages.${pkgs.system}.default;
in {
  home.packages = [ nvim ];
  programs.zsh.shellAliases = {
    "vim" = "${lib.getExe nvim}";
    "vi" = "${lib.getExe nvim}";
  };
  # imports = [ inputs.nixvim'.homeManagerModules.nixvim ];

  # programs.nixvim = {
  #   enable = true;
  #   package = nvim;
  #   plugins.cmp-ai.enable = false;
  # };
}
