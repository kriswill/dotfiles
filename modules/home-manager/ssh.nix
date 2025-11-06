{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.kriswill.ssh.enable = lib.mkEnableOption "kris' ssh";
  config = lib.mkIf config.kriswill.ssh.enable (
    let
      inherit (pkgs.stdenv) isDarwin;
      linux-extra-config = ''
        IdentityAgent ~/.1password/agent.sock
      '';
      darwin-extra-config = ''
        IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
      '';
    in
    {
      programs.ssh = {
        enable = true;
        includes = [ "${config.home.homeDirectory}/.ssh/config.d/*" ];
        matchBlocks."*".forwardAgent = true;
        extraConfig = if isDarwin then darwin-extra-config else linux-extra-config;
        enableDefaultConfig = false;
      };
      #sops.secrets.hosts = {
      #  sopsFile = ../../secrets/ssh.yaml;
      #  path = "${config.home.homeDirectory}/.ssh/config.d/ssh-hosts-internal";
      #};
    }
  );
}
