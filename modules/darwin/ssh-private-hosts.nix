# Private ssh Host entries — other people's hostnames stay out of the public
# repo (knowledge/decisions/ssh-private-hosts.md). One sops file shared by
# every recipient host (modules/hosts/ssh-hosts.yaml), deployed to
# ~/.ssh/config.d/private-hosts, which the stow-managed ~/.ssh/config
# (home/ssh) Include-globs. owner k: ssh runs as the user and the default
# root:staff 0400 is unreadable there. Edit with:
#   SOPS_AGE_KEY=$(sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key) \
#     sops modules/hosts/ssh-hosts.yaml
# Gated: mini/SOC have no age recipients yet (.sops.yaml TODO) and would fail
# decryption at activation. nixos twin: modules/nixos/ssh-private-hosts.nix.
{
  flake.modules.darwin.ssh-private-hosts =
    { lib, config, ... }:
    {
      options.programs.ssh-private-hosts.enable = lib.mkEnableOption "sops-managed private ssh hosts";
      config = lib.mkIf config.programs.ssh-private-hosts.enable {
        sops.secrets.ssh-private-hosts = {
          sopsFile = ../hosts/ssh-hosts.yaml;
          owner = "k";
          path = "/Users/k/.ssh/config.d/private-hosts";
        };
      };
    };
}
