# Private ssh Host entries — darwin twin: modules/darwin/ssh-private-hosts.nix
# (rationale + edit command there; nebula's host key also decrypts the file).
# Universal within the class (single Linux host); gate when a second NixOS
# host appears without a recipient entry in .sops.yaml.
{
  flake.modules.nixos.ssh-private-hosts = {
    sops.secrets.ssh-private-hosts = {
      sopsFile = ../hosts/ssh-hosts.yaml;
      owner = "k";
      path = "/home/k/.ssh/config.d/private-hosts";
    };
    # sops-nix symlinks into ~/.ssh/config.d but won't create k-owned parents.
    systemd.tmpfiles.rules = [
      "d /home/k/.ssh 0700 k users -"
      "d /home/k/.ssh/config.d 0755 k users -"
    ];
  };
}
