{ inputs, ... }: {
  imports = [
    ./disko.nix
    inputs.nix-index-database.nixosModules.nix-index
  ];
  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "sr_mod"
    "virtio_blk"
  ];
  hardware.graphics.enable32Bit = false;
  time.timeZone = "America/Los_Angeles";
  services.openssh.settings.PasswordAuthentication = true;
  modules = {
    onepassword.enable = true;
  };
  home-manager.profilesDir = ../../home;
}
