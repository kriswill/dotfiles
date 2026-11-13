# mini uses its own SSH authentication key for unattended outgoing access.
# sops-nix decrypts the private half using mini's host identity; peers trust
# only ssh-client.pub. The unrelated Git signing key keeps its own agent.
{
  configurations.darwin.mini.module =
    { pkgs, ... }:
    let
      home = "/Users/k";
      clientConfig = pkgs.writeText "mini-ssh-client.conf" ''
        # Managed by modules/hosts/mini/ssh-client.nix.
        # Included before the shared 1Password defaults: first value wins.
        Host *
          IdentityAgent none
          IdentityFile ${home}/.ssh/id_ed25519_mini
          IdentitiesOnly yes
          ForwardAgent no
      '';
    in
    {
      sops.secrets.ssh-client-key = {
        sopsFile = ./ssh-client.yaml;
        owner = "k";
        mode = "0400";
        path = "${home}/.ssh/id_ed25519_mini";
      };

      # The shared stow config already includes config.d/* before 1Password.
      # Keep this host-only override out of the shared home/ tree.
      system.activationScripts.postActivation.text = ''
        install -d -m 0700 -o k ${home}/.ssh ${home}/.ssh/config.d
        if [ -e ${home}/.ssh/config.d/00-machine-key ] && [ ! -L ${home}/.ssh/config.d/00-machine-key ]; then
          mv ${home}/.ssh/config.d/00-machine-key "${home}/.ssh/machine-key.before-nix-$(date +%s)"
        fi
        ln -sfn ${clientConfig} ${home}/.ssh/config.d/00-machine-key
      '';
    };
}
