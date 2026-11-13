---
type: Darwin Module
title: Hermes Agent (mini)
description: 'Enables services.hermes-agent on mini: the gateway as a launchd user agent running as k, the wrapped hermes CLI sharing its HERMES_HOME under ~/.hermes-agent, the Herdr integration, OpenAI through the Codex OAuth login (as on nebula) with an optional sops secret for API keys, and everything inside the module''s Seatbelt sandbox, which is also granted ~/src so the agent can work on the checkouts there.'
resource: modules/hosts/mini/hermes-agent.nix
tags: [darwin-module, host-specific, ai-agent, sandbox, secrets]
generated: { by: claude-code/fable-5-2, at: 2026-11-09T13:15:00-08:00 }
sources:
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

- **Sandboxed, with `~/src` granted.** The gateway and the CLI read
  the system and write `~/.hermes-agent`, a private `TMPDIR` and
  `/Users/k/src` (`sandbox.readWritePaths`, added 2026-11-11 so the agent
  can work on the checkouts there). They can't read the rest of `/Users/k`,
  or reach the keychain, launchd, other applications, or the tmux, herdr,
  1Password and [git-signing](git-signing-agent.md) sockets
  ([decision](../decisions/hermes-agent-macos-seatbelt-sandbox.md)).[^subflake-readme]
- **`~/src` is trusted the moment its code runs outside the sandbox.** The
  agent can edit any checkout's hooks, `.envrc` and build scripts, and this
  repo is one of them: `nrs` builds and activates it as root. Review the
  agent's changes here before rebuilding. It can also read everything under
  `~/src` (untracked `.env` files included) and the network is open.
- **Git inside the sandbox has no identity or signing.** `HOME` is
  `~/.hermes-agent`, so `~/.gitconfig` and the signing agent are out of
  reach; commits the agent makes are unsigned unless it is given a config
  of its own.
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
  then relies on the Codex login alone. Removing the file later stops declaring the secret
  but leaves the last `.env` in place: activation rewrites `.env` only when
  there is something to write, so delete `~/.hermes-agent/.hermes/.env` by
  hand.
- **Herdr integration on.** Status reaches the Herdr app by OSC 7501 written
  to the pane's pty, which the sandbox allows. The herdr TUI path
  (`herdr pane report-agent-session`) needs herdr's socket and would not
  work from inside.
- **Model selection is runtime-owned and the update check is off**, for the
  reasons in nebula's doc.
- **Restart the gateway with launchd**, not `hermes gateway restart`: the
  CLI's sandbox can't signal the agent's.
  `launchctl kickstart -k gui/$(id -u)/org.nixos.hermes-agent`. A `hermes`
  started while the agent is down fails with `Gateway could not start`.
- **Verify.** `launchctl print gui/$(id -u)/org.nixos.hermes-agent`,
  `tail ~/Library/Logs/hermes-agent.err.log`, `hermes gateway status`,
  `hermes -z hi`.

## Writing or rotating API keys

From the repo root, with the 1Password app unlocked (the CLI asks for
approval). One `KEY=value` per line; add lines for more providers. The file
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
