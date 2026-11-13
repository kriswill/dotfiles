# Public identities and client policy for the managed machines. Private keys
# live only in each host's sops file and runtime secret path.
{
  publicKeyFiles = [
    ../modules/hosts/k/ssh-client.pub
    ../modules/hosts/mini/ssh-client.pub
    ../modules/hosts/nebula/ssh-client.pub
  ];

  # Exact names used by Herdr, plus the normal LAN/mDNS aliases.
  hosts = [
    "k"
    "k.home.lan"
    "k.local"
    "mini"
    "mini.home.lan"
    "mini.local"
    "k-mini"
    "nebula"
    "nebula.home.lan"
    "nebula.local"
    "SOC-Kris-Williams"
    "SOC-Kris-Williams.home.lan"
    "SOC-Kris-Williams.local"
  ];

  clientConfig =
    { identityFile, hosts }:
    ''
      # Nix-managed machine identity; included before the 1Password defaults.
      Host ${builtins.concatStringsSep " " hosts}
        IdentityAgent none
        IdentityFile ${identityFile}
        IdentitiesOnly yes
        ForwardAgent no
      # Do not restrict later config.d includes to the hosts above.
      Host *
    '';
}
