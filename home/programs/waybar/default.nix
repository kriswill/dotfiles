{
  programs.waybar = {
    enable = true;
    settings = import ./config.nix;
    style = builtins.readFile ./style.css;
  };
}
