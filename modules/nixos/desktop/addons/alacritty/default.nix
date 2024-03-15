{ config, lib, options, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.internal) mkBoolOpt;

  cfg = config.k.desktop.addons.alacritty;
in
{
  options.k.desktop.addons.alacritty = {
    enable = mkBoolOpt false "Whether to enable alacritty.";
  };

  config = mkIf cfg.enable {
    k.desktop.addons.term = {
      enable = true;
      pkg = pkgs.alacritty;
    };
  };
}
