{
  pkgs,
  self,
  # inputs,
  lib,
  ...
}: {
  networking.hostName = "yoda";

  imports = [
    ./hardware-configuration.nix
  ];

  # age.secrets.spotify = {
  #   file = "${self}/secrets/spotify.age";
  #   owner = "k";
  #   group = "users";
  # };

  # gaming kernel
  # boot.kernelPackages = lib.mkForce pkgs.linuxPackages_cachyos;
  environment.systemPackages = [pkgs.scx];

  hardware = {
    nvidia = {
      open = false;
      powerManagement.enable = true;
    };
  };
  boot.kernelParams = [ "nvidia.NVreg_PreserveVideoMemoryAllocations=1" ];

  # security.tpm2.enable = true;

  services = {
    # for SSD/NVME
    fstrim.enable = true;

    # howdy = {
    #   enable = true;
    #   package = inputs.nixpkgs-howdy.legacyPackages.${pkgs.system}.howdy;
    #   settings = {
    #     core = {
    #       no_confirmation = true;
    #       abort_if_ssh = true;
    #     };
    #     video.dark_threshold = 90;
    #   };
    # };

    # linux-enable-ir-emitter = {
    #   enable = true;
    #   package = inputs.nixpkgs-howdy.legacyPackages.${pkgs.system}.linux-enable-ir-emitter;
    # };

    # kanata.keyboards.yoda = {
    #   config = builtins.readFile "${self}/system/services/kanata/main.kbd";
    #   devices = ["/dev/input/by-path/platform-i8042-serio-0-event-kbd"];
    # };
  };
}
