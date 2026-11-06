---
type: Decision
title: Sign Headless Commits With a Host-Only Key Loaded by a Root Daemon
description: 'On a headless Mac, git signs with a host-only SSH key that a root launchd daemon reads from 1Password with a vault-scoped service-account token and loads into an ssh-agent running as the user, so commits never wait on a 1Password prompt and the session can sign but cannot read the key or the token.'
tags: [git, 1password, secrets, darwin]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-05T12:45:00-08:00 }
sources:
  - id: ssh-agent-source
    resource: https://github.com/openssh/openssh-portable/blob/master/ssh-agent.c
    title: 'ssh-agent.c handle_socket_read(): only euid 0 or the agent''s own uid may connect'
  - id: github-signature-verification
    resource: https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification
    title: 'GitHub: about commit signature verification (persistent verification records)'
  - id: op-service-accounts
    resource: https://developer.1password.com/docs/service-accounts/
    title: 1Password service accounts
---

**Where:** [git-signing-agent](../modules/git-signing-agent.md), enabled on
[mini](../hosts/mini.md). Procedure:
[git-signing-agent-setup](../playbooks/git-signing-agent-setup.md).

## Context

mini is going headless: Claude Code sessions under [herdr](../modules/herdr.md)
core, with nobody at the screen. Commit signing on the Macs goes through
1Password's `op-ssh-sign` ([git](../modules/git.md)). It asks for approval
for each new process and gives up when the app locks, so a headless commit
waits on a dialog nobody will answer. (`commit.gpgsign = true` is global,
so unsigned commits are not a fallback.)

The precedent is Kris' apple-machine VM (sec-claude-container, on k). It
uses a disposable signing key in its own vault and a service account
scoped read-only to that vault.[^op-service-accounts] A boot unit reads the
key over HTTPS into an in-memory ssh-agent.

## Decision

Reuse that shape, with two changes for mini:

- **The token comes from sops** (`modules/hosts/mini/secrets.yaml`, mini's
  age key derived from its SSH host key), as nebula's `op-sa-token` does
  ([op-service-account-token](op-service-account-token.md)). Encrypting
  needs only the public recipient, so the file can be rewritten from any
  checkout.
- **The token is root-only, and root does the loading.** ssh-agent accepts
  connections from root as well as from its own uid,[^ssh-agent-source] so
  the agent runs as `k` and a root daemon pushes the key into it. `k`'s
  processes, including a hijacked Claude session, can ask for signatures
  through the socket but can't read the token (0400 root) or the key
  (memory of Apple's SIP-protected `/usr/bin/ssh-agent`). A hijacked
  session can sign only while it's on mini; it can't carry the key off.
  The boundary is real only because `k` has no passwordless sudo
  (`sudo -n true` fails on mini).

How it's wired into git: the shared stow config ends with
`[include] path = /etc/git/host.inc`. The module writes that file only on
hosts that enable it, so it overrides `gpg.ssh.program` and
`user.signingkey` there and nowhere else. A missing include is a no-op.
This beats a `hostname:` include condition, which git doesn't have, and
moving signing out of the shared config. It applies host-wide rather than
only to herdr sessions: a headless host has nobody to approve any 1Password
prompt, and "signed with mini's key" then just means "committed on mini".

Considered and not chosen:

- **The private key straight in sops.** That avoids the network and token
  expiry at boot. But rotating or revoking the key would need a repo
  commit, there'd be no read audit, and it breaks from the
  apple-machine/nebula pattern.
- **A Secure Enclave key** (macOS 26 `sc_auth create-ctk-identity` plus
  `/usr/lib/ssh-keychain.dylib`, both present on mini). The key couldn't
  be exported at all, but it's unverified whether GitHub accepts its
  `sk-ecdsa` signatures without a touch, and the key would live outside
  1Password.
- **Looser 1Password agent approval settings.** It still prompts for new
  processes and whenever the app locks.

## Consequences

- Commits on mini sign with no prompt and without the 1Password app,
  locked or unlocked. GitHub shows them as **Verified** once the key is
  added as a *Signing* key. Adding it only as an authentication key isn't
  enough, and is useless to a thief anyway, because the key is never used
  for ssh logins.
- Revoking it means deleting the service account, removing the GitHub
  signing key, and restarting the daemon. Commits GitHub has already
  verified stay verified after the key is removed.[^github-signature-verification]
- The token is read only at agent start, so expiry and rotation only bite
  at the next reboot or restart. The wrapper's error names the status
  command and the log.
- After any reboot, FileVault waits for an unlock before anything loads.
  Use `fdesetup authrestart` for planned reboots.
- Other 1Password prompts the headless host will still hit, and which
  are out of scope here: ssh pushes (`gh:` pushInsteadOf, ssh remotes), the
  Codeberg credential helper, and `hc` reaching k over ssh. All three go
  through the 1Password agent or `op read`. The same pattern (a vault per
  purpose, plus the service account) could cover them later.

[^ssh-agent-source]: openssh-portable `ssh-agent.c`: `if ((euid != 0) && (getuid() != euid))` → "uid mismatch".
[^github-signature-verification]: GitHub: "GitHub will not re-verify previously signed commits or retroactively adjust their verification status".
[^op-service-accounts]: 1Password service accounts: you control which vaults are accessible; the built-in Private vault can never be granted.
