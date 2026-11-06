---
type: Darwin Module
title: Git Signing Agent
description: 'A root launchd daemon that reads a host-only SSH signing key from 1Password through a service-account token and loads it into an ssh-agent, so git signs commits with no 1Password prompt; enabled on headless mini.'
resource: modules/darwin/git-signing-agent/default.nix
tags: [darwin-module, git, 1password, secrets]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-05T12:45:00-08:00 }
sources:
  - id: op-secret-reference-syntax
    resource: https://developer.1password.com/docs/cli/secret-reference-syntax/
    title: 1Password secret reference syntax (ssh-format=openssh query parameter)
  - id: op-service-account-cli
    resource: https://developer.1password.com/docs/cli/reference/management-commands/service-account/
    title: op service-account (create --vault, --expires-in, --raw)
  - id: ssh-agent-man
    resource: https://man.openbsd.org/ssh-agent
    title: ssh-agent(1) (-D foreground, -a bind_address)
  - id: ssh-agent-source
    resource: https://github.com/openssh/openssh-portable/blob/master/ssh-agent.c
    title: 'ssh-agent.c handle_socket_read(): rejects a peer only if euid != 0 && euid != the agent uid'
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix (darwinModules.sops; per-secret owner/mode)
  - id: nix-darwin-manual
    resource: https://nix-darwin.github.io/nix-darwin/manual/
    title: nix-darwin manual (launchd.daemons, environment.etc)
---

Every other Mac signs commits through 1Password's `op-ssh-sign`
([git](git.md), `home/git/.config/git/signing-macos.inc`). That signer asks
for approval for each new process and stops working when the app locks, so
a Mac with nobody at the keyboard (Claude under [herdr](herdr.md) core)
can't sign. This module gives such a host its own signing key that needs no
approval. Design and trade-offs:
[headless-git-signing-agent](../decisions/headless-git-signing-agent.md).
Setup, rotation and revocation:
[git-signing-agent-setup](../playbooks/git-signing-agent-setup.md).

Gated on `services.git-signing-agent.enable` (the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).
[mini](../hosts/mini.md) declares it with `enable = false` until its
1Password items exist.

## Pieces

- **Token:** `sops.secrets.<tokenSecret>` from `sopsFile`, left at
  sops-nix's darwin default of `root:staff 0400`, so only root can read
  it.[^sops-nix] Machinery: [sops](sops.md).
- **Daemon** `org.nixos.git-signing-agent` (`./loader.sh`, root, `KeepAlive`):
  1. Starts `/usr/bin/ssh-agent -D -a /var/run/git-signing/agent.sock` as
     `user` through `sudo -u`.[^ssh-agent-man]
  2. Pipes `op read "op://<opItem>/private key?ssh-format=openssh"`
     straight into a root `ssh-add -`.[^op-secret-reference-syntax] This
     works because ssh-agent accepts root as well as its own
     uid.[^ssh-agent-source]
  3. Unloads the key again unless `ssh-add -L` matches `publicKey`.
  4. Retries with exponential backoff, capped at 5 min, until the sops
     file exists and `op` succeeds. Afterwards it waits on the agent, and
     exits when the agent dies so launchd starts a fresh one. Logs go to
     `/var/log/git-signing-agent.log`, which newsyslog rotates.
- **Signer** `git-signing-keygen` (on PATH): sets `SSH_AUTH_SOCK` to the
  socket and runs Apple's `/usr/bin/ssh-keygen`. When the agent is empty,
  `-Y sign` fails with pointers to the status and log; verification calls
  pass straight through.
- **git wiring:** `/etc/git/host.inc` sets `gpg.ssh.program` and
  `user.signingkey = "key::<publicKey>"`. The shared git config includes it
  **last** (a missing include is a no-op, verified on git 2.56), so it
  overrides `op-ssh-sign` on this host and nowhere else. It follows the
  [store-path configs pattern](../patterns/store-path-configs.md): nix
  writes it because it embeds a store path.

## Gotchas

- **The boundary relies on there being no passwordless sudo.** The
  session's user can sign through the socket, but can't read the token or
  the key. Adding `NOPASSWD` for that user removes the boundary.
- **The token is read only at agent start** (boot, agent death,
  `launchctl kickstart`). An expired or rotated token only shows up at the
  next restart, as a failing commit with the wrapper's pointers.
- **Changing the token in sops doesn't restart the daemon** because the
  plist is unchanged. Run
  `sudo launchctl kickstart -k system/org.nixos.git-signing-agent` after a
  token rotation. A key rotation changes `GSA_PUBLIC_KEY` in the plist, so
  `nrs` reloads it on its own.
- **FileVault:** nothing loads until the disk is unlocked after a reboot.
  For planned reboots of a headless host, use `sudo fdesetup authrestart`.
- The service account's vault should hold only this key. Its contents are
  everything a stolen token can reach (as in
  [op-service-account-token](../decisions/op-service-account-token.md)).

## Source

- Module: [`modules/darwin/git-signing-agent/default.nix`](../../modules/darwin/git-signing-agent/default.nix)
- Loader: [`modules/darwin/git-signing-agent/loader.sh`](../../modules/darwin/git-signing-agent/loader.sh)
- Options under: `services.git-signing-agent` (`enable`, `publicKey`, `opItem`,
  `sopsFile`, `tokenSecret`, `user`, `op`)[^nix-darwin-manual]
- Service account CLI used in setup:[^op-service-account-cli] see the playbook.

[^op-secret-reference-syntax]: 1Password secret reference syntax: `?ssh-format=openssh` returns the private key in OpenSSH format, which `ssh-add` reads; the default PKCS#8 is rejected.
[^op-service-account-cli]: `op service-account create` with `--vault <vault>:read_items`, `--expires-in`, `--raw`.
[^ssh-agent-man]: ssh-agent(1): `-D` foreground (no fork), `-a` bind address.
[^ssh-agent-source]: openssh-portable `ssh-agent.c`, `handle_socket_read()`: `if ((euid != 0) && (getuid() != euid))` → "uid mismatch".
[^sops-nix]: sops-nix: darwin module and per-secret `owner`/`group`/`mode`.
[^nix-darwin-manual]: nix-darwin manual: `launchd.daemons.<name>.serviceConfig`, `environment.etc`.
