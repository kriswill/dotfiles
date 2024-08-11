{ pkgs, lib, ... }:

{
  boot = {
    kernelModules = [ "kvm-intel" ];
    kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
    ];
  };

  programs.dconf.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    virt-manager
    qemu_kvm
    virtiofsd
  ];

  virtualisation = {
    libvirtd = {
      enable = true;

      qemu = {
        package = pkgs.qemu_kvm;
        ovmf = {
          enable = true;
          packages = [ pkgs.OVMFFull.fd ];
        };
        swtpm.enable = true;
      };
    };
  };
}
