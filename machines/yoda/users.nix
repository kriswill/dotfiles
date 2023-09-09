{ pkgs, home-manager, ... }: 

let
  user = "k";
in
{
  users = {
    users.${user} = {
      isNormalUser = true;
      uid = 1000;
      description = "${user}";
      group = "${user}";
      extraGroups = [ "networkmanager" "wheel" "libvirtd" ];

      packages = with pkgs; [
        firefox
        dconf2nix
        vscode.fhs
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy"
      ];
    };
    groups.${user}.gid = 1000;
  };
  
  home-manager.users.${user} = import ./home.nix;
}
