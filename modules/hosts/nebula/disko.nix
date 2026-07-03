{
  configurations.nixos.nebula.module =
    # unencrypted disko with just a boot and root partition
    {
      disko.devices = {
        disk = {
          # disk label
          nixos = {
            # CHANGE PATH BEFORE FORMATTING (done by the installer)
            device = "/dev/disk/by-id/nvme-eui.002538a26141bda4";
            type = "disk";
            content = {
              # use a GPT disk for all systems
              type = "gpt";
              partitions = {
                # required for legacy bios / CSM mode to boot drives with GPT via grub
                bios-boot = {
                  name = "bios-boot";
                  type = "EF02";
                  size = "1M";
                };
                esp = {
                  name = "ESP";
                  type = "EF00";
                  size = "512M";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                    # prevent a security hole warning for /dev/urandom
                    mountOptions = [ "umask=0077" ];
                  };
                };
                root = {
                  name = "root";
                  size = "100%";
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/";
                  };
                };
              };
            };
          };
        };
      };
    }

  ;
}
