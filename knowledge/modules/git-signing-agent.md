---
type: Dual Module
title: Git Signing Agent
description: 'A root daemon loads an SSH signing key into an ssh-agent running as the user, so git signs commits with no 1Password prompt; the key comes straight from a sops secret (k, nebula) or from 1Password through a service-account token (mini).'
resource: modules/darwin/git-signing-agent/default.nix
tags: [darwin-module, nixos-module, git, 1password, secrets]
status: stable
generated: { by: claude-code/fable-5.2, at: 2026-11-14T13:40:00-08:00 }
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
    title: 'ssh-agent.c: handle_socket_read() rejects a peer only if euid != 0 && euid != the agent uid; main() calls platform_disable_tracing()'
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix (darwinModules.sops, nixosModules.sops; per-secret owner/mode/restartUnits)
  - id: nix-darwin-manual
    resource: https://nix-darwin.github.io/nix-darwin/manual/
    title: nix-darwin manual (launchd.daemons, environment.etc)
  - id: systemd-service
    resource: https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html
    title: 'systemd.service(5) (ExecStartPost=, the "+" executable prefix, Type=exec, Restart=)'
  - id: systemd-exec
    resource: https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html
    title: systemd.exec(5) (User=, RuntimeDirectory=, sandboxing options)
---

Every host signs commits through 1Password's `op-ssh-sign` by default
([git](git.md), `home/git/.config/git/signing-*.inc`). That signer asks for
approval for each new process and stops working when the app locks, so a
session with nobody at the keyboard (Claude or Codex under [herdr](herdr.md),
[Hermes](hermes-agent.md)) can't sign. This module gives a host a signing
key that needs no approval. The agent design and mini's 1Password source:
[headless-git-signing-agent](../decisions/headless-git-signing-agent.md).
The shared key in sops:
[git-signing-key-in-sops](../decisions/git-signing-key-in-sops.md). Setup,
rotation and revocation:
[git-signing-agent-setup](../playbooks/git-signing-agent-setup.md).

Gated on `services.git-signing-agent.enable` in both classes (the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md),
a [cross-OS twin](../patterns/cross-os-module-twins.md). Three hosts enable
it, all with one key (`modules/hosts/git-signing.pub`):

| Host | The daemon gets the key from | sops secret |
|---|---|---|
| [mini](../hosts/mini.md) | 1Password (`opItem`), read with a service account | `op-sa-token` in `modules/hosts/mini/secrets.yaml` |
| [k](../hosts/k.md) | sops | `git-signing-key` in the shared `modules/hosts/git-signing.yaml` |
| [nebula](../hosts/nebula.md), through [nebula-git-signing-agent](nebula-git-signing-agent.md) | sops | the same file |

k and nebula set `enable = builtins.pathExists ../git-signing.yaml`. A
checkout without the key file still builds and keeps signing through
1Password, and deleting the file withdraws the key.

## What both twins give git

- **A root-only secret.** `sops.secrets.<name>` from `sopsFile`, left at
  sops-nix's default of root `0400`.[^sops-nix] It is the private key
  (`keySecret`, default `git-signing-key`), or on darwin with `opItem` the
  service-account token (`tokenSecret`). Machinery: [sops](sops.md).
- **An ssh-agent running as `user`**, which root loads. ssh-agent accepts
  root as well as its own uid,[^ssh-agent-source] so the user's processes
  can ask for signatures through the socket but never see the key. The
  loader unloads the key again unless `ssh-add -L` matches `publicKey`.
- **Signer `git-signing-keygen`** (on PATH): sets `SSH_AUTH_SOCK` to the
  socket and runs the OS's `ssh-keygen`. When the agent is empty,
  `-Y sign` fails with pointers to the status and log; verification calls
  pass straight through.
- **git wiring:** `/etc/git/host.inc` sets `gpg.ssh.program` and
  `user.signingkey = "key::<publicKey>"`. The shared git config includes it
  **last** (a missing include is a no-op, verified on git 2.56), so it
  overrides `op-ssh-sign` on this host and nowhere else. It follows the
  [store-path configs pattern](../patterns/store-path-configs.md): nix
  writes it because it embeds a store path.

The signer and `host.inc` text come from one builder,
[`lib/git-signing.nix`](../../lib/git-signing.nix); each twin passes only
its socket, its ssh binaries and where its logs are.

## darwin twin

Daemon `org.nixos.git-signing-agent` (`./loader.sh`, root, `KeepAlive`).
Apple's `/bin/sh` first waits for the loader with `/bin/wait4path`, so
launchd can start the job before the Nix volume is mounted. Then the
loader:

1. Starts `/usr/bin/ssh-agent -D -a /var/run/git-signing/agent.sock` as
   `user` through `sudo -u`.[^ssh-agent-man]
2. Pipes the key straight into a root `ssh-add -`: the contents of the
   secret (`GSA_KEY_FILE`), or
   `op read "op://<opItem>/private key?ssh-format=openssh"` with the
   token.[^op-secret-reference-syntax] With `opItem` the key never touches
   the disk at all.
3. Unloads the key again unless it is `publicKey`.
4. Retries with exponential backoff, capped at 5 min, until the sops
   secret exists and the load succeeds. Afterwards it waits on the agent,
   and exits when the agent dies so launchd starts a fresh one. Logs go to
   `/var/log/git-signing-agent.log`, which newsyslog rotates.

## nixos twin

systemd does by declaration what the loader does by hand, in
`git-signing-agent.service`:

- `ExecStart` is `ssh-agent -D -a /run/git-signing/agent.sock` under
  `User=`, in a `RuntimeDirectory` (mode `0700`, owned by the user, removed
  when the unit stops).[^systemd-exec]
- `ExecStartPost=+…` runs `git-signing-load-key` as root: the `+` prefix
  drops `User=` for that one command.[^systemd-service] It `ssh-add`s the
  secret and checks the public key. A failed load fails the start, and
  `Restart=always` tries again: after 5 s, then backing off to 5 min
  (`RestartSteps`, `RestartMaxDelaySec`), as the darwin loader does.
- There is no wait-and-retry loop: sops-nix decrypts during activation,
  before any unit starts. `restartUnits` on the secret reloads a rotated
  key.[^sops-nix]
- The agent is sandboxed to what it needs (`ProtectSystem=strict`,
  `ProtectHome`, `PrivateNetwork`, `RestrictAddressFamilies=AF_UNIX`,
  `MemorySwapMax=0`). A pathname socket still works across the network
  namespace.
- The key comes from sops only. `opItem` isn't ported: no NixOS host uses it.

## Verification

Verified on mini, 2026-11-13: `nrs` activated generation 25 with the native
bootstrap, the daemon loaded the expected public key, and a temporary Git
commit signed and verified with status `G` through the configured signer
and allowed-signers file. The build, Nix lint checks, and bootstrap checks
with an absent/already-available loader passed. A subsequent reboot at
13:22:04.807 PST confirmed automatic startup: the socket appeared at boot
+64 seconds and the expected key loaded at +68 seconds, followed by another
successfully verified temporary commit. Detailed timing and the separate
boot-activation failure are in the
[startup manual](../../docs/shell-startup-performance.md#mini-reboot-timeline-2026-11-13-generation-25).
Generation 26
[reboot verification](../../docs/shell-startup-performance.md#mini-reboot-verification-2026-11-13-generation-26)
measured the socket at +57.6 seconds and the expected key at about +61
seconds, with one daemon launch and no key-load retries. The remaining delay
mostly precedes the key load; its full cause is not established.

Mini declares a host-only `ProcessType = "Standard"` override.
The native bootstrap logs before and after its
store wait; the loader logs entry, agent startup, socket creation, key-load
attempt and successful load, with Bash elapsed seconds. This separates
launch/store/interpreter delay from work inside the loader. These changes
preserve the root-only token and in-memory key boundary. Generation 27's
warm restart entered at 14:06:17, loaded the expected key at
14:06:19 (`loader elapsed=2s`), and a temporary signed Git commit verified
successfully. This is a warm-restart result, not a cold-boot comparison.

Generation 28's cold reboot on 2026-11-13 created the socket at kernel
+17.323 s and loaded the expected key at about +30 s, versus about +61 s
in generation 26. SOPS published the token at +24.828 s; a five-second
retry left roughly two to three seconds before the next load attempt.
The loader's successful fetch establishes access to its designated signing
item, not general vault access for user agents or the full scope of the
service account's server-side grants. A post-boot challenge signed through
the configured Git signer and verified against the existing allowed-signers
file, entirely through pipes without creating a commit or exposing the key.
See the [cold-boot and credential record](../../docs/shell-startup-performance.md#mini-cold-boot-and-credential-readiness-2026-11-13-generation-28).

The sops key source and the nixos twin were tested on nebula on
2026-11-14, with throwaway keys and before any host activated them:

- **Loader, both sources** (run unprivileged on Linux, 21 checks): the key
  loads from a secret file and from a stand-in `op`; git signs and verifies
  (`%G?` = `G`) through the generated signer and `host.inc`; a wrong key is
  unloaded; an `op` failure is logged and retried; a secret that appears
  late is picked up; no log holds private key text.
- **nixos twin** in a NixOS VM test with real sops-nix and nebula's own
  package set (OpenSSH 10.6p1, 12 subtests): the unit is active at boot
  with the key loaded; the secret is root `0400` and unreadable by the
  user; another user can't reach the socket; `/proc/<agent>/mem` belongs to
  root; a commit made through the repo's real shared git config signs with
  `G` and both overridden settings resolve to `/etc/git/host.inc`; a
  killed agent returns with the key; a stopped one fails the commit with
  the signer's pointer; a rotated key is live after
  `switch-to-configuration`; a mismatched secret is refused, and retried
  with a growing delay (3 attempts in 30 s, not 7).
- **Builds:** nebula's full system builds with the agent enabled; its
  closure gains only the unit, the two scripts, `host.inc` and the key
  file. k evaluates with the daemon in key-file mode. mini's closure
  changes only in the loader script, so its daemon reloads once.

The real key went into `modules/hosts/git-signing.yaml` on 2026-11-14,
read from 1Password and checked against `git-signing.pub` before it was
encrypted. With that file tracked, `nrb` on nebula builds and adds exactly
the five paths above, k evaluates in key-file mode with the secret root
`0400`, and mini's derivation is the same as without the file.

Verified live on nebula, 2026-11-14, after `nrs` activated generation 236:
the unit started at 15:11:45 with no restarts and logged the expected
fingerprint (`SHA256:jT1Evkk…`); `/run/git-signing` is `k` `0700`; the
secret is root `0400` and unreadable by `k`, as is the agent's
`/proc/<pid>/mem`; `gpg.ssh.program` and `user.signingkey` both resolve to
`/etc/git/host.inc`. A commit and a signed tag made in a throwaway
repository, with no terminal attached, verified as `G` against the
existing `allowed_signers`.

Verified live on k the same day, after `nrs` activated generation 291: the
daemon is running on its first launch; the loader log shows the agent
started as `k` and the expected fingerprint loaded within the same second,
with no private key text; `/var/run/git-signing` is `k` `0700`; the secret
is root `0400` and unreadable by `k`; both overridden settings resolve to
`/etc/git/host.inc`. A commit and a signed tag in a throwaway repository
verified as `G`. The build added six paths (the daemon script and plist,
the signer, `host.inc`, the log-rotation rule and the key file).

## Gotchas

- **Boot before `/nix` is mounted (darwin):** on mini after the 2026-11-13
  OS upgrade, launchd rejected the direct store executable with `ENOENT`
  and left the job at `EX_CONFIG` (78), with an empty log and no agent
  socket. `KeepAlive` did not retry it after the executable became
  available, and [nrs](nrs.md) did not reload an unchanged plist. The
  native-shell wait above fixes that ordering; activating the changed plist
  reloads the job. For an already-installed older plist, `sudo launchctl
  kickstart -k system/org.nixos.git-signing-agent` retries startup once
  `/nix` is ready. `wait4path` rechecks on mount-table changes, not
  ordinary file creation; a test that merely creates a missing file does
  not simulate volume mount.
- **The boundary relies on there being no passwordless sudo.** The
  session's user can sign through the socket, but can't read the secret or
  the key. Adding `NOPASSWD` for that user removes the boundary. On nebula
  sudo asks the 1Password agent ([sudo-1password](sudo-1password.md)),
  which is an approval, not a bypass.
- **On Linux the agent's own uid can't read its memory** only because
  ssh-agent marks itself undumpable at startup.[^ssh-agent-source] The VM
  test checks the effect (`/proc/<pid>/mem` owned by root).
- **It is host-wide.** Every commit the user makes on an enabled host signs
  with this key, at the keyboard or not: git can't tell an agent's commit
  from a person's. On k and nebula the personal 1Password key no longer
  signs commits.
- **Only `user` can sign.** Another uid (a service user, root's own git) is
  refused by the agent and has no `host.inc`-including git config anyway.
- **A missing key file is silent** on k and nebula: `enable` goes false and
  commits sign through `op-ssh-sign` again. `git config --show-origin
  gpg.ssh.program` tells which signer is live. Flakes only see tracked
  files, so an unstaged `git-signing.yaml` counts as missing.
- **A unit that can't load the key fails the switch (nixos).** [nrs](nrs.md)
  then reports a failed unit and leaves the profile on the old generation.
  `journalctl -u git-signing-agent` names the cause; fix the secret and run
  `nrs` again.
- **With `opItem`, the token is read only at agent start** (boot, agent
  death, `launchctl kickstart`). An expired or rotated token only shows up
  at the next restart, as a failing commit with the signer's pointers.
- **Changing the secret doesn't restart the darwin daemon** because the
  plist is unchanged. Run
  `sudo launchctl kickstart -k system/org.nixos.git-signing-agent` after a
  token rotation. A key rotation changes `GSA_PUBLIC_KEY` in the plist, so
  `nrs` reloads it on its own. The nixos unit restarts either way.
- **FileVault (darwin):** nothing loads until the disk is unlocked after a
  reboot. For planned reboots of a headless host, use
  `sudo fdesetup authrestart`.
- mini's service-account vault should hold only this key. Its contents are
  everything a stolen token can reach (as in
  [op-service-account-token](../decisions/op-service-account-token.md)).

## Source

- darwin module: [`modules/darwin/git-signing-agent/default.nix`](../../modules/darwin/git-signing-agent/default.nix)
- darwin loader: [`modules/darwin/git-signing-agent/loader.sh`](../../modules/darwin/git-signing-agent/loader.sh)
- NixOS module: [`modules/nixos/git-signing-agent.nix`](../../modules/nixos/git-signing-agent.nix)
- Shared builder: [`lib/git-signing.nix`](../../lib/git-signing.nix)
- Options under `services.git-signing-agent`: `enable`, `publicKey`,
  `sopsFile`, `keySecret`, `user` in both twins; `opItem`, `tokenSecret`,
  `op` on darwin only. The darwin twin builds on `launchd.daemons` and
  `environment.etc`.[^nix-darwin-manual]
- Service account CLI used in mini's setup:[^op-service-account-cli] see the playbook.

[^op-secret-reference-syntax]: 1Password secret reference syntax: `?ssh-format=openssh` returns the private key in OpenSSH format, which `ssh-add` reads; the default PKCS#8 is rejected.
[^op-service-account-cli]: `op service-account create` with `--vault <vault>:read_items`, `--expires-in`, `--raw`.
[^ssh-agent-man]: ssh-agent(1): `-D` foreground (no fork), `-a` bind address.
[^ssh-agent-source]: openssh-portable `ssh-agent.c`: `handle_socket_read()` has `if ((euid != 0) && (getuid() != euid))` → "uid mismatch", and `main()` calls `platform_disable_tracing(0)`, which on Linux is `prctl(PR_SET_DUMPABLE, 0)`.
[^sops-nix]: sops-nix: darwin and NixOS modules, per-secret `owner`/`group`/`mode`, and `restartUnits` on NixOS.
[^nix-darwin-manual]: nix-darwin manual: `launchd.daemons.<name>.serviceConfig`, `environment.etc`.
[^systemd-service]: systemd.service(5): `ExecStartPost=` runs after the main process is started; a `+` prefix executes the command with full privileges, ignoring `User=`.
[^systemd-exec]: systemd.exec(5): `RuntimeDirectory=` is created under `/run`, owned by `User=`, and removed when the unit stops.
