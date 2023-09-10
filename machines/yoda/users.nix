{ pkgs, username, ... }: 

{
  users = {
    users.${username} = {
      isNormalUser = true;
      uid = 1000;
      description = "${username}";
      group = "${username}";
      extraGroups = [ "networkmanager" "wheel" "libvirtd" ];

      packages = with pkgs; [
        firefox
        dconf2nix
        # vscode.fhs
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy"
      ];
    };
    groups.${username}.gid = 1000;
  };
  
  # home-manager.users.${username} = import ./home.nix;
}
