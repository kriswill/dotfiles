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
  imports = [ inputs.gBar.homeManagerModules.aarch64-linux.default ];

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
    inputs.gBar.defaultPackage.aarch64-linux
    pkgs.unstable.pamixer
  ];

  xdg.configFile."gBar/style.scss".source = ln "/home/k/src/dotfiles/home/programs/gBar/style.scss";
}
