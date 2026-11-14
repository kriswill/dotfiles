# Shared pieces of the git-signing-agent twins
# (modules/darwin/git-signing-agent, modules/nixos/git-signing-agent.nix):
# how git is pointed at the agent. The daemon that fills the agent is per-OS
# (launchd loader script vs systemd unit) and stays in each twin. lib/ sits
# outside modules/ so import-tree doesn't treat this as a flake-parts module.
{
  # "type base64" of a public key given as a file or a literal. A comment adds
  # nothing, and both loaders compare exactly these two fields against
  # `ssh-add -L`.
  publicKey =
    lib: value:
    let
      raw = if builtins.isPath value then builtins.readFile value else value;
    in
    lib.concatStringsSep " " (lib.take 2 (lib.splitString " " (lib.trim raw)));

  # Body of git-signing-keygen, the gpg.ssh.program: the OS's ssh-keygen,
  # aimed at the signing agent. git also runs it to verify (-Y verify /
  # find-principals), which needs no agent, so only -Y sign gets the clear
  # error when the key is missing. `status` and `log` are the commands or
  # paths that error points at.
  keygenText =
    {
      socket,
      sshAdd,
      sshKeygen,
      status,
      log,
    }:
    ''
      export SSH_AUTH_SOCK=${socket}
      if [ "''${1-}" = -Y ] && [ "''${2-}" = sign ] && ! ${sshAdd} -l >/dev/null 2>&1; then
        echo "git-signing-keygen: no signing key in the agent at $SSH_AUTH_SOCK" >&2
        echo "  status: ${status}" >&2
        echo "  log:    ${log}" >&2
        exit 1
      fi
      exec ${sshKeygen} "$@"
    '';

  # /etc/git/host.inc. The shared git config (home/git) includes it last, so
  # these win over the op-ssh-sign settings above them. A missing include is a
  # no-op, which leaves every other host on 1Password.
  hostInc =
    {
      keygen,
      publicKey,
      module,
    }:
    ''
      # Written by services.git-signing-agent (${module}).
      [gpg "ssh"]
      	program = "${keygen}"
      [user]
      	signingkey = "key::${publicKey}"
    '';
}
