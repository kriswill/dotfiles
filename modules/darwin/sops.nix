# sops-nix on macOS — universal machinery, inert until a host defines secrets.
#
# The age identity is derived from the host's SSH host key (ssh-to-age), so no
# new key material is managed: each Mac's recipient comes from
#   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
# and is registered in .sops.yaml. A host that wants secrets adds
#   sops.defaultSopsFile = ./secrets.yaml;   # in modules/hosts/<host>/
#   sops.secrets.<name> = { };
# plus a matching creation rule in .sops.yaml (edit with
# `sops modules/hosts/<host>/secrets.yaml`; sops/age/ssh-to-age are in the dev
# shell). Mirrors nebula's setup (modules/hosts/nebula.nix), which gets the
# sops module via snowglobe-lib's mkNixosHost instead.
{
  flake.modules.darwin.sops =
    { inputs, ... }:
    {
      imports = [ inputs.sops-nix.darwinModules.sops ];

      sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
}
