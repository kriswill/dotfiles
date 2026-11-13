# Unattended Herdr connections use k's own client key. Other destinations
# keep the shared personal/1Password SSH configuration.
{
  configurations.darwin.k.module =
    { pkgs, ... }:
    let
      home = "/Users/k";
      machines = import ../../../lib/ssh-machines.nix;
      clientConfig = pkgs.writeText "k-ssh-client.conf" (
        machines.clientConfig {
          inherit (machines) hosts;
          identityFile = "${home}/.ssh/id_ed25519_k";
        }
      );
    in
    {
      sops.secrets.ssh-client-key = {
        sopsFile = ./ssh-client.yaml;
        owner = "k";
        mode = "0400";
        path = "${home}/.ssh/id_ed25519_k";
      };

      system.activationScripts.postActivation.text = ''
        install -d -m 0700 -o k ${home}/.ssh ${home}/.ssh/config.d
        if [ -e ${home}/.ssh/config.d/00-machine-key ] && [ ! -L ${home}/.ssh/config.d/00-machine-key ]; then
          mv ${home}/.ssh/config.d/00-machine-key "${home}/.ssh/machine-key.before-nix-$(date +%s)"
        fi
        ln -sfn ${clientConfig} ${home}/.ssh/config.d/00-machine-key
      '';
    };
}
