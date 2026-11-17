# nebula answers Herdr on port 2122 like the Macs: a second, key-only sshd
# beside sshd.service (modules/nixos/agent-remote.nix).
{
  configurations.nixos.nebula.module = {
    services.agent-remote.enable = true;
  };
}
