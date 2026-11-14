# Prompt-free commit signing, so the AI harnesses on nebula (Claude Code and
# Codex under herdr, Hermes) can commit without a 1Password approval nobody is
# there to give. The key is the one mini already signs with, held in a shared
# sops file and loaded into a root-loaded ssh-agent
# (modules/nixos/git-signing-agent.nix).
#
# It applies to every commit k makes on this host, at the keyboard or not:
# git can't tell the two apart, and /etc/git/host.inc overrides the
# op-ssh-sign signer for all of them. Setup, rotation and revocation:
# knowledge/playbooks/git-signing-agent-setup.md.
{
  configurations.nixos.nebula.module = {
    services.git-signing-agent = {
      # On only while the key is in the tree (tracked: flakes see nothing
      # else). Without it the host still builds and signs through 1Password,
      # so deleting the file is also how the key is withdrawn.
      enable = builtins.pathExists ../git-signing.yaml;
      user = "k";
      publicKey = ../git-signing.pub;
      sopsFile = ../git-signing.yaml;
    };
  };
}
