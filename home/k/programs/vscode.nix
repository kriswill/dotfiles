{ pkgs, ... }:

{
  # Version: 1.91.0
  programs.vscode = {
    enable = true;
    package = pkgs.trunk.vscode;
    #package = (pkgs.vscode.override { isInsiders = true; }).overrideAttrs (oldAttrs: rec {
    #  src = (builtins.fetchTarball {
    #    url = "https://update.code.visualstudio.com/latest/linux-x64/insider";
    #    sha256 = "1lqran4qxczi1vdbchkdgzhh6iq9c7srci30qvr4gwhfxckfw0hk";
    #  });
    #  version = "latest";
    #});
  };
}
