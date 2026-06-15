{
  configurations.nixos.nebula.module =
    { config, ... }:
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
        ];
      };
    }

  ;
}
