{ pkgs, ... }:

{
  fonts = {
    # enableDefaultPackages = true;
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [
          "JetBrainsMono Nerd Font Mono"
          "Noto Mono"
        ];
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
      };
    };
    fontDir.enable = true;
    # enableGhostscriptFonts = true;
    packages = with pkgs; [
      vegur
      noto-fonts
      nerd-fonts.jetbrains-mono
      nerd-fonts.dejavu-sans-mono
      nerd-fonts.sauce-code-pro
    ];
  };
}
