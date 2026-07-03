---
type: NixOS Module
title: Sudo 1password
description: sudo authentication via the 1Password SSH agent — pam_ssh_agent_auth installed as auth-sufficient on the sudo stack only, with the trusted key materialized via tmpfiles to pass StrictModes and gcr-ssh-agent disabled so the 1Password socket wins.
resource: modules/hosts/nebula/sudo-1password.nix
tags: [nixos-module, host-specific]
timestamp: '2026-07-03T12:00:00-07:00'
---

sudo authentication via the 1Password SSH agent using `pam_ssh_agent_auth`
(`security.pam.sshAgentAuth.enable`). The trusted public key is the same
ed25519 key that signs git commits. Four load-bearing gotchas:

- **tmpfiles, not `environment.etc`:** the module runs a StrictModes check on
  the *real* path of the authorized-keys file and refuses if any parent dir
  is group/other-writable. An `environment.etc` entry is a symlink into
  /nix/store (group-writable, mode 1775), which fails that check — so the key
  is materialized as a real root-owned file at `/etc/sudo-ssh-keys/k` via
  `systemd.tmpfiles.rules`, whose realpath stays entirely under root-owned
  `/etc`.
- **Never locks you out:** `security.pam.services.sudo.sshAgentAuth = true`
  installs the step as `auth sufficient` on the *sudo* PAM stack only, so
  sudo falls back to password whenever no agent is reachable (TTY console,
  1Password GUI closed). NixOS also adds `Defaults env_keep+=SSH_AUTH_SOCK`
  to sudoers automatically.
- **Unbraced `$HOME`:** `environment.sessionVariables.SSH_AUTH_SOCK =
  "$HOME/.1password/agent.sock"` MUST use the unbraced form — NixOS writes
  sessionVariables into the pam environment via a plain
  `replaceStrings ["$HOME"] ["@{HOME}"]`; a braced `${HOME}` is not matched,
  lands verbatim, and pam_env resolves it as a nonexistent variable, silently
  breaking the socket path for every PAM session.
- **gcr-ssh-agent off:** gnome-keyring's `services.gnome.gcr-ssh-agent`
  otherwise claims SSH_AUTH_SOCK (`/run/user/$UID/gcr/ssh`) and shadows the
  1Password agent; only its ssh-agent is disabled — keyring secrets/pkcs11
  stay on.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/sudo-1password.nix`](../../modules/hosts/nebula/sudo-1password.nix)
