{
  config,
  inputs,
  pkgs,
  ...
}:
let
  ln = config.lib.file.mkOutOfStoreSymlink;
in
{
  imports = [ inputs.gBar.homeManagerModules.x86_64-linux.default ];

  programs.gBar = {
    enable = true;
    config = {
      Location = "B";
      EnableSNI = true;
      DateTimeStyle = "%a %D %H:%M:%S";
      #SNIIconSize = { };
    };
  };

  home.packages = [
    inputs.gBar.defaultPackage.x86_64-linux
    pkgs.pamixer
  ];

  xdg.configFile."gBar/style.scss".source = ln "/home/k/src/dotfiles/home/programs/gBar/style.scss";
}
