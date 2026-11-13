---
type: Darwin Module
title: Headless Login
description: 'Mini login policy retains the desktop for Hermes and suppresses restored applications; its initial 1Password launcher-disable action awaits correction to allow normal launch.'
resource: modules/hosts/mini/headless-login.nix
tags: [darwin-module, host-specific]
generated: { by: codex/gpt-6, at: 2026-11-13T14:43:17-08:00 }
sources:
  - id: startup-manual
    resource: ../../docs/shell-startup-performance.md
    title: Measured boot timings and startup controls
  - id: nix-darwin-manual
    resource: https://nix-darwin.github.io/nix-darwin/manual/
    title: nix-darwin CustomUserPreferences and activation options
---

[mini](../hosts/mini.md) retains its logged-in desktop for
[Hermes](mini-hermes-agent.md). The generation-26 logs show loginwindow's
persistent-app restoration launching Helium and Ghostty at about +10 s.
1Password's separate `com.1password.1password-launcher` job ran once, and
the desktop app launched at +21 s. These are distinct startup paths, not
ordinary Nix daemon dependencies.[^startup-manual]

Rationale: [mini headless startup](../decisions/mini-headless-startup.md).

## Policy and limits

The host's `CustomUserPreferences` sets `TALBlockSavingAndLaunch = true`
and `TALLogoutSavesState = false` in `com.apple.loginwindow`.[^nix-darwin-manual]
This suppresses restoration of the previous GUI app session as a whole;
explicit login items and manually opening apps are separate. It does not
delete saved browser sessions, quit current applications, or disable login.

`TALBlockSavingAndLaunch` is an undocumented macOS preference. Its key,
matching `_blockTALSavingAndLaunch` field and log branches are present in
mini's installed macOS 27.2.1 (26B131) loginwindow. The older
`LoginwindowLaunchesRelaunchApps` key is absent there (only the distinct
`LoginwindowLaunchesRelaunchAppsStopped` exists). Do not substitute the old
key from generic defaults lists. Generation 28 verified the cold-login
effect; recheck after macOS updates. Merely writing
`TALLogoutSavesState = false` is insufficient evidence: it was already false
in the generation-26 boot's diagnostic log while apps were restored.

The initial implementation also makes [nrs](nrs.md) post-activation disable
1Password's login-launcher job. **This conflicts with the clarified
requirement:** 1Password should launch normally; boot and autonomous agent
work should not depend on desktop authentication. Remove only that disable
action in a future configuration change, retaining the restoration policy.
The documentation follow-up did not change the active implementation.
The [SSH client](mini-ssh-client.md) and root service-account
[signing loader](git-signing-agent.md) already avoid desktop authentication.

## Verification and rollback

Activated 2026-11-13 through `nrs`, generation 28, exit 0. Before reboot,
the restoration-block preference was true, the save-state preference false,
and the launcher disable override was present. After the cold reboot,
loginwindow acknowledged `_blockTALSavingAndLaunch = 1` with an empty
restoration list; Helium and Ghostty were not running. Desktop auto-login
completed at kernel +10.962 s. This verifies the restoration suppression.

ServiceManagement (`smd`) re-enabled the 1Password launcher at
22:19:29.812822 UTC; the app spawned at 22:19:31.614001 (+15.534 s).
The override was therefore not durable against re-registration in this
boot. Normal 1Password launch is expected and is not a failure. Neither
app startup nor authentication capability-check logs establish whether an
interactive prompt appeared. Post-boot signing verification and fresh SSH
checks to k and nebula succeeded without desktop authentication.
Detailed timestamps and evidence limits are in the startup manual.

Inspect the live preference with
`defaults read com.apple.loginwindow TALBlockSavingAndLaunch` and launchd
overrides with `launchctl print-disabled gui/$(id -u)`. These state checks
do not by themselves prove a prompt-free startup.

To roll back the entire policy (distinct from the pending launcher-only
correction), remove this host policy and run `nrs`, delete
`TALBlockSavingAndLaunch` with `defaults delete com.apple.loginwindow
TALBlockSavingAndLaunch`, then run `launchctl enable
gui/$(id -u)/com.1password.1password-launcher` as the user. Removing a Nix
declaration alone does not erase persistent defaults or launchd overrides.
The prior `TALLogoutSavesState` value was already false.

## Source

- Module: [`modules/hosts/mini/headless-login.nix`](../../modules/hosts/mini/headless-login.nix)

[^startup-manual]: Boot log evidence, candidate controls and measured limitations.
[^nix-darwin-manual]: `system.defaults.CustomUserPreferences` writes preferences for the primary user during activation.
