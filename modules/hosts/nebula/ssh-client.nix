# The server host key identifies sshd and stays root-only. Herdr authenticates
# as k with this separate sops-managed client key for managed destinations.
{
  configurations.nixos.nebula.module =
    { pkgs, ... }:
    let
      machines = import ../../../lib/ssh-machines.nix;
      clientConfig = pkgs.writeText "nebula-ssh-client.conf" (
        machines.clientConfig {
          inherit (machines) hosts;
          identityFile = "/home/k/.ssh/id_ed25519_nebula";
        }
      );
    in
    {
      sops.secrets.ssh-client-key = {
        sopsFile = ./ssh-client.yaml;
        owner = "k";
        mode = "0400";
        path = "/home/k/.ssh/id_ed25519_nebula";
      };

      # ssh-private-hosts creates k-owned ~/.ssh and config.d on this host.
      systemd.tmpfiles.rules = [
        "L+ /home/k/.ssh/config.d/00-machine-key - - - - ${clientConfig}"
      ];
    };
}
