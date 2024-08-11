{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        tilingshell = pkgs.callPackage ./tilingshell { };
        distro-grub-themes-nixos = pkgs.callPackage ./distro-grub-themes { };
        bibata-hyprcursor = pkgs.callPackage ./bibata-hyprcursor { };
      };
    };
}
