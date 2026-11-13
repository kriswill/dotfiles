---
type: Darwin Module
title: Hermes Agent (mini)
description: 'Hermes gateway and CLI on mini share private state and a Seatbelt sandbox with checkout access, plus explicit delegation through the existing Herdr Core socket into user k''s host authority.'
resource: modules/hosts/mini/hermes-agent.nix
tags: [darwin-module, host-specific, ai-agent, sandbox, secrets]
generated: { by: codex/gpt-6, at: 2026-11-13T14:43:17-08:00 }
sources:
  - id: cua-launch-grants
    resource: https://github.com/trycua/cua/pull/5690
    title: CuaDriver per-application launch authorization
  - id: subflake-readme
    resource: ../../flakes/hermes-agent/README.md
    title: 'flakes/hermes-agent/README.md (the nix-darwin module and its sandbox)'
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix
---

Turns on [hermes-agent](hermes-agent.md) for [mini](../hosts/mini.md),
merged into the host per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md). nebula's
counterpart is [nebula-hermes-agent](nebula-hermes-agent.md).

Mini overrides the gateway's launchd `ProcessType` to `Standard`; the
sub-flake's `Background` default is unchanged. Generation 26 started its
process at about boot +20 s, but the existing `logs/gateway.log` completion
marker (`Press Ctrl+C to stop`, after startup wiring in pinned Hermes
0.23.0) arrived at +72.6 s. Use that marker alongside runtime state and a
functional check for the next comparison; it does not prove model-provider
or desktop-driver readiness. The related [headless login policy](headless-login.md)
reduces automatic GUI launches. See the
[startup manual](../../docs/shell-startup-performance.md).
Generation 27's warm restart with this scheduling override
started PID 5206 at about 14:06:18 and reached the initialization marker at
14:06:21.316. Generation 28's cold reboot reached the same marker at
boot +28.413 s, versus +72.647 s in generation 26. Runtime state reports
`running`; provider and desktop-driver readiness remain unverified. These
are separate warm and cold measurements, with multiple changes between boots.

- **Sandboxed, with `~/src` granted.** The gateway and the CLI read
  the system and write `~/.hermes-agent`, a private `TMPDIR` and
  `/Users/k/src` (`sandbox.readWritePaths`, added 2026-11-11 so the agent
  can work on the checkouts there). Direct sandbox access excludes the rest
  of the real home, keychain, launchd, arbitrary applications, and tmux,
  1Password and [git-signing](git-signing-agent.md) sockets. Mini explicitly
  allows the existing Herdr Core socket and the bounded desktop-driver
  endpoint; these grant the authority of those servers, not just access to
  their filesystem paths
  ([decision](../decisions/hermes-agent-macos-seatbelt-sandbox.md)).[^subflake-readme]
- **`~/src` is trusted the moment its code runs outside the sandbox.** The
  agent can edit any checkout's hooks, `.envrc` and build scripts, and this
  repo is one of them: `nrs` builds and activates it as root. Review the
  agent's changes here before rebuilding. It can also read everything under
  `~/src` (untracked `.env` files included) and the network is open.
- **Direct Git and delegated Git have different authority.** `HOME` is
  `~/.hermes-agent`, so direct commands do not inherit the user's Git config
  or signing socket. Commands explicitly delegated through Core run outside
  Seatbelt as k and can use the host Git signer and
  [machine SSH identity](mini-ssh-client.md). This does not give Hermes the
  root signing token or the private signing key.
- **`hermes` run from outside `~/src` starts in the workspace** (`~/.hermes-agent/workspace`), with a note
  on stderr: a working directory the sandbox can't read breaks every child.
- **The provider is OpenAI through the Codex login**, the same as nebula
  (checked there on 2026-11-09: `openai-codex`, OAuth by device code, model
  set with `/model … --global`). Run `hermes auth add openai-codex` once on
  mini and finish the device-code login in a browser. It is an OAuth session
  with a rotating refresh token, so it stays in `$HERMES_HOME/auth.json` and
  is not in sops; a rebuild leaves it alone. Don't copy nebula's `auth.json`:
  two machines sharing one refresh token log each other out.
- **The model was seeded by hand.** A fresh `HERMES_HOME` has no model, so no
  session starts (`storage_unavailable`) and `/model` has no session to run
  in. On 2026-11-09 nebula's `model:` block (`gpt-6.1-sol`, `openai-codex`,
  its `base_url` and `api_mode`) was appended to `config.yaml` and the
  gateway restarted. `/model … --global` owns it from there.
- **API keys, if wanted, come from sops.** The `hermes-env` secret holds
  `KEY=value` lines (none exists yet). sops-nix decrypts it
  root-only to `/run/secrets/hermes-env`,[^sops-nix] which the sandbox can't
  read; activation copies it into `$HERMES_HOME/.env` (0600, k).
- **The secret has its own file**, `modules/hosts/mini/hermes-secrets.yaml`,
  with its own `.sops.yaml` rule. `secrets.yaml` opens only with mini's host
  key (root), so adding a key there means decrypting as root. A separate
  file is written whole from 1Password with only mini's public recipient,
  from any checkout.
- **The secret is declared only once that file is tracked**
  (`builtins.pathExists`), so the host builds before the key exists; Hermes
  then relies on the Codex login alone. Mini's nonempty `environment`
  also supplies `HC_SOCKET` and `HERMES_CUA_DRIVER_CMD`, so activation
  rewrites `.env` even without that secret. Removing the secret declaration
  drops its copied values at the next activation; already-running processes
  retain their environment until restarted.
- **Herdr integration and delegation are enabled.** Status hooks support
  OSC reporting to the pane. Separately, the host allows
  `/Users/k/.local/state/herdr-core/default/default.sock` and sets `HC_SOCKET`
  for both CLI and gateway. `hc` can therefore reach the existing Core
  from inside the sandbox. Core can execute unsandboxed commands as k,
  interact with other terminals and reach configured remote machines:
  this is intentionally not an end-to-end confinement boundary. A read-only
  post-boot check through the actual sandbox launcher and Core successfully
  read the host's `gpg.ssh.program`. This verifies that delegation path,
  not an LLM-driven Git workflow or every status-reporting transport.
- **General vault access is not provisioned by the signing service.** The
  post-boot `.env` contained only the two nonsecret settings above; no
  `hermes-env` file or agent service-account token was configured. The
  root-only signing token can fetch its designated key, but is not exported
  to Hermes, Core or Codex. Additional assigned vaults need separately scoped
  noninteractive credentials or a broker. An existing OAuth `auth.json`
  does not establish working provider authentication after this reboot.
- **Model selection is runtime-owned and the update check is off**, for the
  reasons in nebula's doc.
- **Restart the gateway with launchd**, not `hermes gateway restart`: the
  CLI's sandbox can't signal the agent's.
  `launchctl kickstart -k gui/$(id -u)/org.nixos.hermes-agent`. A `hermes`
  started while the agent is down fails with `Gateway could not start`.
- **Verify.** `launchctl print gui/$(id -u)/org.nixos.hermes-agent`,
  `tail ~/Library/Logs/hermes-agent.err.log`, `hermes gateway status`,
  `hermes -z hi`.

## Bounded desktop driver package

The local signed-driver package at
[`cua-driver.nix`](../../flakes/hermes-agent/nix/cua-driver.nix) pins **0.47.24**, replacing 0.21.0.
The older version allowed `launch_app` by tool name without checking the
per-application launch grant; upstream PR #5690 adds that admission check.[^cua-launch-grants]
The official ARM64 bundle is redistributed without binary modifications,
and the package verifies bundle identity `com.trycua.driver` and Team ID
`YCK386LBJ7`.

Build verification passed for the driver, unchanged Calculator manifest,
and control wrapper. The signed app matches the release archive byte-for-byte;
14 non-GUI control tests pass. The new CLI retains the adapter's
`mcp --embedded --socket` and reviewed `serve` flags. This is **not** live
GUI or end-to-end adapter verification: activation/start and allowed/denied
resource tests remain separate checkpoints. The earlier Calculator
observation identity failure is not yet established as resolved.

## Writing or rotating API keys

This is a manual provisioning procedure, not a boot or agent-runtime
dependency. From the repo root, with the 1Password app unlocked (the CLI
asks for approval). One `KEY=value` per line; add lines for more providers. The file
is replaced only after `sops` succeeds.

```sh
key=$(op read "op://Private/<item>/credential") && [ -n "$key" ] &&
  jq -n --arg env "ANTHROPIC_API_KEY=$key" '{"hermes-env": $env}' |
  sops encrypt --filename-override modules/hosts/mini/hermes-secrets.yaml \
    --input-type json --output-type yaml /dev/stdin > hermes-secrets.tmp &&
  mv hermes-secrets.tmp modules/hosts/mini/hermes-secrets.yaml
unset key
git add modules/hosts/mini/hermes-secrets.yaml   # nix only sees tracked files
```

Then `nrs`. The gateway reads `.env` at start, so restart it:
`launchctl kickstart -k gui/$(id -u)/org.nixos.hermes-agent`. Check with
`sudo sops decrypt modules/hosts/mini/hermes-secrets.yaml` (needs the host
key) or `hermes -z hi`.

## Source

- Module: [`modules/hosts/mini/hermes-agent.nix`](../../modules/hosts/mini/hermes-agent.nix)

[^subflake-readme]: flakes/hermes-agent/README.md
[^sops-nix]: sops-nix

[^cua-launch-grants]: CuaDriver enforces a matching per-app launch grant before dispatching launch_app.
