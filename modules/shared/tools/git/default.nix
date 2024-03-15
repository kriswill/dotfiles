{ config, lib, options, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.internal) mkBoolOpt;

  cfg = config.k.tools.git;
in
{
  options.k.tools.git = {
    enable = mkBoolOpt false "Whether or not to install and configure git.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      #   bfg-repo-cleaner
      git
      #   git-crypt
      #   git-filter-repo
      #   git-lfs
      #   gitflow
      #   gitleaks
      #   gitlint
    ];
  };
}
