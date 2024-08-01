{
  programs.waybar = {
    enable = true;
    settings = import ./config.nix;
    style = builtins.readfile ./style.css;
  }
}
