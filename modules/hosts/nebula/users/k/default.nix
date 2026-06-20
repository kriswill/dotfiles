{
  configurations.nixos.nebula.module =
    { config, pkgs, ... }:
    {
      sops.secrets.k_password.neededForUsers = true;

      users.users.k = {
        hashedPasswordFile = config.sops.secrets.k_password.path;
        isNormalUser = true;
        openssh.authorizedKeys.keys = with config.keyring.ssh; [
          k
        ];
        extraGroups = [
          "wheel"
          "networkmanager"
          "libvirtd"
        ];
        # flatpak CLI defaulted to --user; shadows the system flatpak via the
        # per-user profile being ahead on PATH. See packages/flatpak-user.nix.
        packages = [ pkgs.flatpak-user ];
      };
    }

  ;
}
