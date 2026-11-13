# zsh/tmux startup performance (SOC-Kris-Williams, macOS)

**Latest verification: 2026-11-13 on mini, macOS 27.2.1 (26B131), Apple
zsh 5.9.** The OS upgrade replaced nix-darwin's `/etc/zshrc` and
`/etc/zprofile` links with regular files. The completion failure and recovery
are covered below; the performance measurements remain the historical
SOC-Kris-Williams baseline from 2026-07-16.

Investigation into "why is opening a new tmux pane with zsh slow." Findings
are machine-verified on `SOC-Kris-Williams` (aarch64-darwin); the zsh config
being profiled (`home/zsh/.config/zsh/`) is shared across all hosts/both OSes,
so the structural findings (starship's double-invocation, uncached `eval`s)
apply everywhere — only the specific numbers and the stray `.cache` directory
were local to this machine. Maintained for Claude's use: keep it accurate,
re-measure rather than trust stale numbers, and record new findings in
**Learned behaviours** at the bottom.

## Completion errors after a macOS upgrade

On mini, new interactive shells reported `command not found: compdef` from
`aliases.zsh` and `.determinate-nixd-completion.zsh`. `/etc/zshenv` still
pointed at nix-darwin's configuration, so it found the stowed user rc, but
the replacement `/etc/zshrc` never ran `compinit`. Autosuggestions and syntax
highlighting were also missing, and Apple's history setting redirected
history to `$ZDOTDIR/.zsh_history` instead of `~/.local/state/zsh/history`.
The replacement `/etc/zprofile` ran Apple's `path_helper` again.

Inspect the live links and the generated files:

```sh
ls -l /etc/zshenv /etc/zprofile /etc/zshrc /etc/static/zprofile /etc/static/zshrc
```

The managed files should link to `/etc/static/<name>`. On this machine the
generated files were intact; loading `/etc/static/zshrc` before the personal
rc restored `compdef`, both plugins, and the intended history path.

Recovery uses the normal [`nrs` workflow](nrs-pipeline.md):

1. Back up the replaced files and any existing `*.before-nix-darwin` copies.
   Activation renames recognized replacement files to that backup suffix,
   potentially replacing an older backup.
2. Run `nrs` as the normal user in a terminal where sudo can authenticate.
   The installed nix-darwin recognizes both replacement files' hashes and
   restores their managed links. If a later OS update produces unrecognized
   content, inspect and preserve the files named by activation's diagnostic
   before moving them aside and retrying.
3. Open a new shell or run `exec zsh -l`. Check the startup state:

   ```zsh
   print -r -- "compdef=${+functions[compdef]} system_rc=${__ETC_ZSHRC_SOURCED:-missing} history=$HISTFILE"
   ```

   Expect `compdef=1 system_rc=1 history=/Users/k/.local/state/zsh/history`.

`nrs --status` reported a consistent generation even while the files were
overwritten: it checks the running system against the boot default, not
whether OS updates have replaced managed files in `/etc`.

Recovery was verified after `nrs` activated mini generation 24: fresh login
and non-login shells loaded completions, autosuggestions, syntax highlighting,
and the intended history settings without startup errors. All 24 managed
`/etc` links resolved correctly, and all 25 macOS Stow packages were fully
deployed without conflicts.

## mini reboot timeline (2026-11-13, generation 25)

Verified from `kern.boottime`, macOS unified logs, process ancestry, runtime
file birth times, and `/var/log/git-signing-agent.log`. Times below are PST;
boot was **13:22:04.807**. The previous signing daemon stopped at 13:21:40,
so the observed shutdown-to-hc interval was about **72 seconds**, including
about 25 seconds before the new kernel boot.

| Time | Since boot | Event |
| --- | ---: | --- |
| 13:22:15.816 | 11.0 s | Encrypted Nix Store volume finishes mounting. |
| 13:22:20.274–21.204 | 15.5–16.4 s | Two incoming SSH sessions start and end; hc does not start. |
| 13:22:28.944 | 24.1 s | Boot activation creates `/run/current-system`. |
| 13:22:33.024 | 28.2 s | App Management denies boot activation's `touch` of `/Applications/Nix Apps/Herdr.app/.DS_Store`; activation exits 1. |
| 13:22:33.884 | 29.1 s | sops runtime secrets become available. |
| 13:22:51.156–51.230 | 46.3–46.4 s | Fresh SSH sessions accept nebula's and k's dedicated machine keys. |
| 13:22:51.911 | 47.1 s | hc core PID 992 is active; its terminal holder starts in the following second. |
| 13:23:08.762 | 64.0 s | Git signing agent creates its socket. |
| 13:23:13 | 68.2 s | Signing daemon logs the expected key loaded. |

**hc delay: an early PATH gap followed by reconnect backoff.** hc was
started by the incoming `herdr-core connect` command over SSH (PID 983),
not by a persistent local launchd job. The first SSH sessions ended about
30 seconds before the successful retry. Upstream 0.1.20
[reconnect logic](https://github.com/herdrdev/herdr-core/blob/v0.1.20/crates/herdr-core/src/remote.rs)
backs off to 30 seconds. Its
[remote command](https://github.com/herdrdev/herdr-core/blob/v0.1.20/crates/herdr-core/src/machines.rs)
finds `herdr-core` on PATH, then tries `~/.local/bin/herdr-core`.

At the first attempt `/nix` was mounted but `/run/current-system` did not
exist yet. At generation 25, the persistent-system-profile fallback in the
stowed `.zshrc` only helped interactive shells; SSH commands read
`/etc/zshenv` instead.
Reproducing that PATH without its `/run/current-system/sw/bin` entry makes
`herdr-core` undiscoverable; adding `/nix/var/nix/profiles/system/sw/bin`
finds it immediately. This is strong evidence for the early failed command,
though its stderr was not retained. The successful SSH-to-core interval
was under a second. The fix below moves the fallback into noninteractive
startup as well.

**Generation 25's boot activation failed partway through.** `org.nixos.activate-system`
created the runtime symlink, then its `ensureAppManagement` check failed in
the background launchd context. Kernel/TCC logs identify the denied write
to `Herdr.app/.DS_Store`, matching the generated boot script's app-update
permission probe. `nrs --status` still reported a consistent generation;
it does not check this launchd job's last exit. The existing `/etc` links
survived, so this did not undo the repaired Zsh configuration. The fix below
separates boot checks from full rebuild checks.

**Git signing recovered automatically.** The native `wait4path` bootstrap
survived the mount ordering and the service ran once, without `EX_CONFIG`.
A fresh temporary commit signed and verified with `G` after the reboot.
The key load itself took about four seconds after the agent-listening log.
The longer interval before the loader ran overlaps macOS security checks
and heavy startup load: its script was allowed by AppleSystemPolicy at
13:22:53.293. The logs do not account for that whole interval precisely;
do not attribute it all to FileVault or to 1Password.

Other observations: 38 Hermes `__pycache__` write-denial records occurred
at 13:23:17–33, after hc was already up. The core/holder logs had no entries
from this reboot (the old 45-second connection warnings predated it).
Neither is evidence for this hc delay. Unified logs are required here.

## Early-boot fixes (2026-11-13)

The [Darwin Zsh module](../modules/darwin/zsh.nix) now appends
`/nix/var/nix/profiles/system/sw/bin` in `programs.zsh.shellInit`, which
nix-darwin emits into `/etc/zshenv`. Noninteractive SSH commands and
interactive shells both receive it, including child shells that inherit
nix-darwin's environment-initialized marker. The builtin array check avoids
duplicates and preserves inherited PATH priorities. The old interactive-only
fallback was removed from `.zshrc`. This covers the interval after `/nix`
mounts but before `/run/current-system` exists; it cannot make tools available
before their filesystem mounts.

The [boot activation module](../modules/darwin/boot-activation.nix) marks
the boot script and wraps `system.checks.text` so rebuild probes run only
during normal activation. The boot job restores `/etc` and keyboard settings;
it does not update apps, Homebrew, users, or Nix. Upstream's `/etc` hash and
conflict checks remain outside the wrapper, so unknown files still stop boot
activation before it overwrites anything. `nrs` and `nrs --test` retain the
full checks, including App Management. The rationale and upstream ordering
dependency are recorded in
[the decision](../knowledge/decisions/darwin-early-boot.md).

Boot output now goes to `/var/log/nix-darwin-boot.log`, with a UTC start time,
exit status, and whole-second elapsed time. This timer starts when the Nix
Bash script executes, after the native mount wait; it does not measure total
time since kernel boot. After activation/reboot, inspect:

```sh
launchctl print system/org.nixos.activate-system
tail -20 /var/log/nix-darwin-boot.log
```

Validation before activation: `nrs --dry` built mini successfully; all three
Darwin hosts evaluated; Nix lint and Zsh syntax checks passed. Temporary
fixtures exercised noninteractive hc discovery with `/run` absent from PATH,
inherited project PATH priority, repeated/nested startup without duplicates,
normal/check-only rejection of denied app writes, successful boot repair,
and boot rejection of an unfamiliar `/etc` file with the original preserved.
The generated boot checks also passed read-only against live `/etc`.
Warm noninteractive shell medians over 31 trials were 3.52 ms before and
3.53 ms after the builtin fallback.

`nrs` then activated mini generation 26. The boot job ran during the switch
at **13:42:55 PST**, logged `status=0 elapsed=0s` (whole-second precision),
and launchd reported one run with exit code 0. All 24 managed `/etc` links
matched the active generation. Fresh noninteractive shells found hc with
`/run/current-system` omitted from PATH, retained inherited project priority,
and kept exactly one fallback through repeated/nested startup. Login shells
still loaded completions, both plugins, and the intended history path.
The following cold reboot verifies the boot job and the improvement in hc
availability. This is one before/after pair, not a controlled benchmark;
`/run/current-system` was already available before the first SSH request in
this boot, so the persistent-PATH branch is covered by the earlier fixtures.

## mini reboot verification (2026-11-13, generation 26)

Kernel boot was **13:45:15.361 PST**. The signing daemon's preceding shutdown
marker was **13:44:53**, giving about **39 seconds from that marker to hc**,
versus about 72 seconds in the generation-25 observation. Unified logs,
process ancestry, file birth times and service logs agree:

| Time | Since boot | Event |
| --- | ---: | --- |
| 13:45:23.755 | 8.4 s | Nix Store mount completes (previously 11.0 s). |
| 13:45:24.628 | 9.3 s | `/run/current-system` exists (previously 24.1 s). |
| 13:45:25.597 | 10.2 s | Boot activation finishes successfully; log says `status=0 elapsed=1s`. |
| 13:45:26.640 | 11.3 s | sops runtime secrets available (previously 29.1 s). |
| 13:45:30.839 | 15.5 s | SSH accepts nebula's machine key. |
| 13:45:31.744 | 16.4 s | hc core PID 751 active (previously 47.1 s). |
| 13:45:34.669 | 19.3 s | SSH accepts k's machine key. |
| 13:45:35 | about 20 s | Hermes gateway process starts; this is not a readiness measurement. |
| 13:46:13.010 | 57.6 s | Signing-agent socket appears (previously 64.0 s). |
| 13:46:16 | about 61 s | Expected signing key loaded (previously 68.2 s). |
| 13:46:23.745 | 68.4 s | Hermes logs its existing `No messaging platforms enabled` warning. |
| 13:46:28.008 | 72.6 s | Hermes's own `logs/gateway.log` records `Press Ctrl+C to stop` after startup wiring. |

`nrs --status` reports generation 26 as running and boot default. Both boot
activation and sops ran once and exited 0; all 24 managed `/etc` entries
resolve to the active generation. The signing daemon and Hermes remain
running with one launch each. Mini's client key is sops-managed, owned by
k, mode `0400`; fresh non-multiplexed logins to both peers succeed using it
with `IdentityAgent none`. Both saved hc peers are connected.

The former approximately 30-second hc retry gap is absent: the first
observed inbound SSH session succeeds, and the core follows in about
0.9 seconds. Core availability improved by **30.7 seconds** in this pair.
Signing remains the late dependency: the socket-to-loaded interval is
about three seconds, with no load failure or backoff logged. AppleSystemPolicy
allowed the loader at 13:45:59.143, and root's `sudo -u k` work appears at
13:46:10–13. The logs do not assign the entire preceding delay to one cause.

Hermes still produces sandbox denials. In the first 75 seconds there were
36 `__pycache__` write-denial records, 113 disk-space-check denial records,
two `.CFUserTextEncoding` read records, and two network-outbound records
(counts include aggregate duplicate-report records). These occur after hc
is available. They merit separate investigation; this boot check does not
establish desktop-driver readiness or change sandbox policy.

### Boot optimization candidates (investigated 2026-11-13)

The late work is service initialization, after SSH and hc already work.
The first two recommendations are now implemented in the checkout (see the
record below). Scheduling was activated in generation 27 and GUI-startup
policy in generation 28. The completed cold-boot comparison is recorded
below; these were the candidates identified from generation 26:

- **Test normal scheduling for Hermes and signing.** In generation 26 both
  jobs used `ProcessType = "Background"`. The installed
  `launchd.plist(5)` manual describes this as resource-limited work intended
  not to disrupt foreground apps. A mini-only `Standard` override is the
  first controlled experiment; it still has light resource limits. Add
  timestamps at loader entry, socket creation and key load, and a genuine
  Hermes readiness marker. Background scheduling is a plausible contributor,
  not a proven explanation for the full delay. The signing socket-to-key
  interval is only about three seconds; sops is already ready at +11.3 s.
- **Open optional GUI apps on demand.** Process start times show Helium and
  Ghostty at 13:45:25 (about +10 s), and 1Password at 13:45:36 (+21 s).
  Helium and Ghostty were candidates for removing session restoration.
  The clarified requirement keeps 1Password launching normally; app launch
  alone is not evidence of an authentication problem. Machine-key SSH and the root service-account signing loader
  do not depend on the 1Password desktop app. The process list does not
  distinguish login-item launches from restored windows; `sfltool dumpbtm`
  required administrator authorization and returned no inventory. Preserve
  the logged-in desktop required by GUI automation.
- **Keep the early prerequisites early.** In generation 26 store mounting
  took about 8.4 s and boot activation itself took one second. The boot job restores the
  runtime profile and `/etc`; it does not run a complete `nrs` activation.
  Deferring it or sops would postpone dependencies of remote work. Nix
  module ordering does not impose runtime launchd ordering. Use actual
  readiness checks for dependencies; socket activation requires cooperation
  from the daemon and cannot be added arbitrarily to `ssh-agent` or Hermes.
- **Remove unused services for a specific reason.** The stale Podman helper
  is loaded but has `runs = 0`. Herdr's scheduled update check and Git's
  config watcher also have zero runs; GnuPG's activation ran once and exited
  successfully. Removing these offers little demonstrated boot benefit.
  `dnsmasq` is running for local `localhost`/`p4c` resolution and is a
  candidate only if mini does not need that mapping. Preserve ZeroTier
  until its remote-access role is established.
- **Investigate Hermes's repeated sandbox denials separately.** Avoiding
  attempted bytecode writes to the immutable store may reduce noise, but
  neither those denials nor disk-space denials are a measured explanation
  for the initialization gap. Do not broaden sandbox access as a boot fix.

Repeat a cold boot after each experiment, using SSH, hc, signing and actual
Hermes readiness as separate milestones. The preceding shutdown marker to
new kernel interval was about 22 seconds; it includes shutdown and pre-kernel
startup and cannot be attributed to this boot's launchd jobs.

Primary references: Apple's [launchd startup and demand-launch design](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html),
[launchd.plist manual source](https://github.com/apple-oss-distributions/launchd/blob/main/man/launchd.plist.5),
and [login-item controls](https://support.apple.com/guide/mac-help/open-items-automatically-when-you-log-in-mh15189/mac).

### Startup tuning (2026-11-13)

Mini alone overrides signing and Hermes to `ProcessType = "Standard"`.
The signing bootstrap logs before/after the Nix Store wait; the loader logs
entry, agent spawn, socket availability, key-load attempts and completion,
with elapsed seconds. No signing secret permissions change.

Hermes already logs a useful initialization boundary in
`~/.hermes-agent/.hermes/logs/gateway.log`: `Press Ctrl+C to stop`, at
13:46:28.008 in generation 26 (+72.6 s). Pinned Hermes 0.23.0 emits it
after startup wiring and background-watcher creation. Its runtime state is
`running`; this boundary does not prove provider or GUI-driver readiness.
No additional Hermes wrapper, polling job or verbose logging is needed.

More specific loginwindow logs confirm Helium/Ghostty were launched by
`PersistentAppsSupport persistentAppPreLaunch`, not ordinary login items.
The new [headless login module](../modules/hosts/mini/headless-login.nix)
sets `TALBlockSavingAndLaunch = true` and `TALLogoutSavesState = false`
through user defaults. The first key and its corresponding save/launch
branches exist in mini's macOS 27.2.1 loginwindow, but the preference is
undocumented and requires a cold-login check. The second preference was
already false in this boot's log, so it alone would not establish a fix.
This blocks restoration of the previous GUI session as a whole, without
quitting current apps or removing their saved browser/application data.

1Password's `com.1password.1password-launcher` was a distinct enabled job
with one completed run. The initial post-activation implementation disabled
that exact GUI-domain job without editing the app's own checkbox. This was
an incorrect interpretation of the requirement: 1Password should launch
normally, while boot and autonomous agent work avoid desktop authentication.
The disable action still needs removal in a separate configuration change.
Desktop auto-login and Hermes remain enabled. History and version caveats:
[headless login](../knowledge/modules/headless-login.md).

The scheduling-only and combined `nrs --dry` builds pass, with format,
ShellCheck, statix and deadnix checks. All three Darwin configurations
evaluate; only mini has the scheduling/restoration overrides.

Generation 27 was activated as running and boot default, with both live plists
set to `Standard`. Its warm signing restart at 14:06:17 loaded the expected
key at 14:06:19 (`loader elapsed=2s`); a temporary Git commit signed and
verified with the expected key. Hermes PID 5206 started at about 14:06:18,
logged startup completion at 14:06:21.316 and reports `running`. These warm
results verify functionality, not cold-boot gains.

`nrs` then activated generation 28 with exit 0: build 7.38 s, native sudo
authentication 171.54 s, profile update 0.11 s, activation 5.86 s. Live
defaults have `TALBlockSavingAndLaunch = true` and `TALLogoutSavesState = false`;
launchd lists the 1Password login launcher as disabled and its browser
helper as enabled. Both agent plists remain `Standard`, Hermes PID 5206
remains running and the expected signing key is present. Existing Helium,
Ghostty and 1Password processes stayed open. Fresh machine-key SSH checks
to k and nebula passed after the scheduling activation.

At that pre-reboot checkpoint no cold-boot improvement had been measured.
The subsequent reboot below tests the combined changes; the scheduling-only build is
`/nix/store/rv9yz5i5nx407rffcfd6zp8zd4fmi2q1-darwin-system-26.11.ff0e21a`.

Backups and narrowed diagnostic logs are in
`~/.local/state/boot-diagnostics/startup-tuning-20261113T140340/`.

## mini cold boot and credential readiness (2026-11-13, generation 28)

All timestamps in this section are **UTC on 2026-11-13**. The origin is
`kern.boottime = 1794608356.080108`, or **22:19:16.080108 UTC**
(14:19:16.080108 PST). Generation 28 is both running and boot default;
boot activation and SOPS each ran once and exited 0. Signing and Hermes
are running with one launch each and `ProcessType = Standard`.

| Event and evidence | UTC | Seconds after kernel boot |
| --- | --- | ---: |
| Nix Store mount complete, APFS log | 22:19:26.796189 | 10.716081 |
| Desktop auto-login complete, `sessionDidLogin` UID 501 | 22:19:27.042274 | 10.962166 |
| Runtime system profile, symlink birth | 22:19:29.048528 | 12.968420 |
| Hermes process spawned | 22:19:30.131967 | 14.051859 |
| SSH accepted nebula's key | 22:19:30.490140 | 14.410032 |
| 1Password desktop app spawned | 22:19:31.614001 | 15.533893 |
| Core Unix socket, birth time | 22:19:31.902958 | 15.822850 |
| Signing-agent socket, birth time | 22:19:33.402763 | 17.322655 |
| SSH accepted k's key | 22:19:35.391196 | 19.311088 |
| SOPS runtime secrets, symlink birth | 22:19:40.907725 | 24.827617 |
| SOPS job exited successfully | 22:19:40.929178 | 24.849070 |
| Boot activation finished successfully | 22:19:41.393848 | 25.313740 |
| Hermes `Starting Hermes Gateway` | 22:19:43.490 | 27.409892 |
| Hermes startup-completion marker | 22:19:44.493 | 28.412892 |
| Expected signing key loaded, whole-second log | 22:19:46 | about 30 |
| Independently observed successful remote `hc exec` | 22:20:10.730788 | 54.650680 |

Core's process ancestry runs through the first inbound SSH session, not the
GUI app. Its socket birth establishes local IPC startup, not the exact
first successful end-to-end remote command. The original terminal's shell
started around +19 s. Untimestamped Core reconnect warnings cannot be
assigned to this boot.

The other computer recorded connection refusal at **22:18:54.681 UTC**:
21.399108 s before the new kernel origin. Refusal to the known successful
command spans **76.049788 s**, but reconnection and terminal recovery
happened between checks. This is an **upper bound on the observed outage**,
not a measured boot duration or evidence of a speed improvement.

### Cold comparison and remaining delays

Generation 26's kernel origin was **21:45:15.361175 UTC**. Its cold Hermes
marker was +72.646825 s, so generation 28 reached that marker **44.233933 s
earlier**. Signing moved from about +61 s to about +30 s. Incoming SSH
changed from +15.478 s to +14.410 s; local Core activity remained around
+16 s (the older measurement is process activity, not socket birth).
Generation 27's signing in 2 s and Hermes in roughly 3 s were **warm
restarts**, not cold boots. One cold before/after pair with scheduling and
restoration changes cannot isolate their contributions or boot variance.

Some prerequisites were later this time: store mounting +10.716 s versus
+8.394 s, SOPS +24.828 s versus +11.279 s, and activation completion
+25.314 s versus +10.236 s. The boot activation log reports **13 s** elapsed
versus **1 s** previously. It restores the runtime profile and checks/links
`/etc`; it does not run full NRS, Homebrew or app activation. The profile
exists and incoming SSH/Core work before that job and SOPS finish.
Available logs do not identify the internal phase responsible for the extra
activation time. Delaying the entire activation or SOPS would not help
credential readiness.

Signing's whole-second logs show bootstrap at 22:19:25, loader entry at
:26, agent start at :27, socket observation at :35, missing-token retry at
:38, key-load attempt at :43 and success at :46. Actual socket birth was
:33.402763. SOPS publication gates the fetch; the five-second retry leaves
roughly two to three seconds after publication before the next attempt.
The next useful measurement is phase timing inside boot activation/SOPS
and timestamped external TCP, SSH and `hc exec` probes during the next
planned reboot. A readiness-triggered token wait could then reduce retry
latency. No further reboot or service changes were made for this analysis.

### Desktop behavior and authentication evidence

Loginwindow acknowledged `_blockTALSavingAndLaunch = 1` with an empty
persistent-app launch list at 22:19:27.049806–27.050263. Helium and Ghostty
were not restored; the logged-in desktop remains available to Hermes.

At 22:19:29.812822, ServiceManagement (`smd`) re-enabled the 1Password login
launcher; it ran and launched the app. This override did not survive that
re-registration, but **normal 1Password launch is expected**. The pending
correction is to remove the module's launcher-disable action, not suppress
1Password or remove desktop login. Ordinary manual-use authentication is
also expected; it must not be a dependency of boot or agent workflows.

No visible password dialog is established by these logs. 1Password's
`canEvaluatePolicy` checks report unavailable Apple Watch/biometric methods;
those checks do not establish that an unlock UI appeared. TCC disclosure
checks and restoration log wording likewise do not prove a password prompt.
Determinate's Nix mount path sets a LocalAuthentication reason of
`Unlock the Nix Store volume.` and the volume subsequently mounts. That is
an encrypted APFS unlock request/context, not proof of a visible dialog.
It is separate from store ownership and output immutability: normal agents
must not alter store outputs or relax permissions. Auto-login and keybag
unlock succeeded; no desktop-authentication blockage was demonstrated on
the tested boot, signing or SSH paths. The original reported startup prompt
cannot be conclusively attributed from this evidence.

### Credential chain and post-boot checks

- **SOPS bootstrap:** Darwin derives the age identity from the root SSH
  host key. The evaluated Mini secrets are `op-sa-token` (root:staff 0400)
  and `ssh-client-key` (k:staff 0400). The latter resolves from
  `~/.ssh/id_ed25519_mini` into the SOPS runtime directory. Both become
  available at +24.828 s. Incoming SSH uses persisted authorized public
  keys and therefore works before this outgoing client credential exists.
- **Signing:** the root loader passes its token only to the noninteractive
  `op` invocation for `mini-automation/mini git signing key`, then pipes the
  key into the user-owned native agent at `/var/run/git-signing/agent.sock`.
  The key stays in memory. The configured Git signer selects this socket
  explicitly. A post-boot challenge signed and verified through pipes
  against the existing allowed-signers file, with no commit or secret output.
  The expected fingerprint was
  `SHA256:jT1EvkkbjWfjMQHKdiytb0pET1Xvs2g9DuPHIER+Hvs`.
- **SSH:** effective configuration selects the separate machine key with
  `IdentityAgent none`, `IdentitiesOnly yes` and `ForwardAgent no`. Fresh
  non-multiplexed, batch-mode `hostname` checks to **k and nebula** succeeded,
  preserving strict host verification and disabling known-host updates.
  This does not verify every external SSH destination.
- **Core/Codex:** their observed environments do not carry the signing
  token or `SSH_AUTH_SOCK`. SSH uses the client file and Git's signer sets
  its own socket, so those absent variables do not block these operations.
- **Hermes:** direct sandbox commands use a separate HOME and cannot read
  the real home credentials, root token or signing socket. The host
  explicitly grants the existing Core socket and sets `HC_SOCKET`. A
  read-only check using the actual sandbox launcher successfully delegated
  through Core to read the host Git signer configuration. Core runs those
  commands outside Seatbelt as k, with access to the user's host resources
  and configured peers. This is broad delegated user authority, not direct
  access to the root token or private signing key. It does not test an
  LLM-driven commit, provider refresh or GUI automation.

The signing loader's successful item fetch proves its designated vault
access. The provisioning playbook intends a service account with
`mini-automation:read_items`; live server-side grant breadth was not
enumerated. This root-only credential is **not general per-agent vault
access**. No separate agent vault credential or optional `hermes-env` secret
is configured; Hermes's `.env` has only `HC_SOCKET` and
`HERMES_CUA_DRIVER_CMD`. Its provider auth file exists, but provider and
desktop-driver readiness remain unverified. Assigned vault access needs
separately scoped SOPS-provisioned credentials or a broker; do not expose
the root signing token or relax secret/store permissions. Ordinary user
`op` access was not exercised because it could fall back to interactive
desktop integration. That is an unverified dependency, not an observed
cause of the reported prompt. NRS's explicit sudo authentication is a
maintenance step, separate from these root launchd boot jobs.

### Herdr Core app-data notice during the investigation

At **13:47:18**, the diagnostic Python process (PID 2303) tried to enumerate
1Password's protected container while locating logs. TCC attributed the
operation to holder PID 817, bundle `dev.herdr.core`, denied the Full Disk
Access check and the specific `SystemPolicyAppDataDetailed` request, and
posted the notification opened at 13:48:19. The request explicitly names
`/Users/k/Library/Group Containers/2BUA8C4S2C.com.1password`.

This notification was caused by the diagnostic search, after boot and SSH
were working. No broader access was requested or granted; subsequent
investigation used unified logs. A separate Developer Tools preflight at
13:45:36 is recorded, but is not evidence of an Accessibility or Screen
Recording failure. Protected 1Password app logs were unavailable to this
session, so the absence of an in-app prompt is not inferred from them.

Evidence is retained locally under
`~/.local/state/boot-diagnostics/20261113T134515/`; raw records are not
committed. Relevant service logs are `/var/log/nix-darwin-boot.log` and
`/var/log/git-signing-agent.log`.


## Baseline (before fixes, 2026-07-16)

- `zsh -i -c exit`, warm: **~150-190ms**
- End-to-end tmux `new-session` → pane accepts input, warm server, cwd =
  this repo: **~510-560ms** (measured via a sentinel file written by
  `send-keys`, not `new-session`'s return — `new-session -d` returns as soon
  as the pty is forked, well before rc files finish, so it under-measures).
- First invocation after a cold cache (fresh boot, or right after this
  session's tool calls warmed nothing yet) can spike to **1-6s** — this is
  dyld/`/nix/store` first-touch overhead, not representative of the steady
  state, and not what was fixed here.

## Where the ~510-560ms warm cost goes

Found via `PS4='+%D{%s.%6.} %N:%i> ' zsh -ix` (timestamped xtrace) run both
directly and inside a real tmux pane, cross-checked against standalone
timing of each subprocess and `STARSHIP_LOG=trace starship prompt`.

1. **Starship renders the prompt twice per line, recomputing git state each
   time (~130-150ms).** `starship init zsh` sets `PROMPT` and `RPROMPT` to
   two separate `$(starship prompt ...)` / `$(starship prompt --right ...)`
   command substitutions — two full process spawns per prompt draw. Trace
   breakdown of a single call:
   - `git_status`: ~49ms
   - `git_branch`: ~10ms
   - `git_state`: ~11ms
   - everything else combined: <2ms

   This is upstream starship+zsh architecture, not a misconfiguration — the
   repo's `starship.toml` only disables `aws`/`gcloud`. It recurs on *every*
   prompt draw in a git repo, not just pane startup. Not changed here (would
   mean losing git info from the prompt, a UX tradeoff left to the user).

2. **A stray root-owned `.cache/` was sitting in this repo root**, mode
   `700`, owned by `root:staff`, dated Jul 15 12:44 (likely a `sudo`'d tool
   run from this cwd — `sudo yazi` appears near that point in
   `~/.zsh_history`, though the cwd at that moment isn't recoverable to
   confirm it). It was untracked and un-gitignored, so every `git status` in
   this repo (and thus every starship `git_status` call) tried to read it and
   printed `warning: could not open directory '.cache/': Permission denied`.
   **Fixed:** removed (`sudo rm -rf .cache`) and added `/.cache` to
   `.gitignore` so a recurrence doesn't silently re-eat this cost. Net effect
   on `git status --porcelain=v2 --branch` in this repo was smaller than
   expected (~28ms → ~25ms) — most of that call's cost is inherent tree-walk
   over the repo's other directories, not this one bad entry.

3. **Five external tools get `eval`'d fresh every shell start, uncached
   (~55-90ms).** `brew shellenv` (~29ms), `direnv hook zsh` (~7ms), `zoxide
   init` (~5ms), `fzf --zsh` (~5ms), `starship init zsh` (~9ms — the one-time
   hook setup, not the per-prompt render cost above). None were cached, even
   though `darwin.zsh` already documents and fixes the identical problem for
   `determinate-nixd completion zsh` ("takes ~300ms per shell... cache it and
   refresh only when the binary changes"). **Fixed:** `brew shellenv` now
   uses the same cache-and-refresh-on-mtime-change pattern, writing to
   `$ZDOTDIR/.brew-shellenv.zsh`. Measured saving: warm `zsh -i -c exit`
   dropped from ~150-190ms to a consistent **~120ms**. `direnv`/`zoxide`/`fzf`
   were left uncached — each is small enough (~5-7ms) that the caching
   machinery's own upkeep cost isn't obviously worth it, but the pattern is
   there in `darwin.zsh` if one of them regresses later.

4. **compinit's `compaudit` security scan** stats every completion dir/file
   on `$fpath` every start (~20-40ms real; xtrace-inflated numbers looked much
   higher but that's tracing overhead on zsh's own loop, not real wall time).
   **Not a bug** — confirmed `.zcompdump`'s mtime is unchanged across repeated
   `zsh -i -c exit` runs, so the expensive full dump rebuild only happens when
   the cache is genuinely stale (a nix profile change adding/removing
   completions), as intended. Left alone.

5. Remainder (~150-250ms): process/pty fork overhead, and zsh parsing
   `/etc/zshenv` → `/etc/zshrc` → `.zshrc` → `aliases.zsh`/`yazi.sh`/
   `functions.zsh`/`darwin.zsh`/`integrations.zsh` in sequence. Not
   independently itemized further.

## Net result of fixes applied (2026-07-16)

- `zsh -i -c exit` warm: ~150-190ms → **~120ms**.
- End-to-end tmux pane-ready: ~510-560ms → still **~500-520ms**. The two
  fixes here (brew caching, `.cache` removal) only ever accounted for a
  modest slice of the total — the dominant cost (starship's double
  git-aware render, #1 above) was intentionally left alone. If the ~500ms
  floor needs to come down further, the lever is tuning/disabling starship's
  `git_status`/`git_branch`/`git_state` modules (a prompt-content decision,
  not a bug fix) or switching prompt tools.

## How this was tested

```sh
# Timestamped xtrace of a full interactive shell start (direct):
PS4='+%D{%s.%6.} %N:%i> ' zsh -ix -c exit 2>trace.log
# then diff consecutive %D timestamps per line to find the slowest gaps.

# Same, but inside a real tmux pane (to catch pty-specific effects):
tmux new-session -d -s trc "PS4='+%D{%s.%6.} %N:%i> ' zsh -ix 2>trace.log"

# End-to-end "pane is actually ready for input" timing — new-session -d
# returns before rc finishes, so use a sentinel file via send-keys instead:
tmux new-session -d -s perf -x 200 -y 50
tmux send-keys -t perf "date +%s%N > ready.txt" Enter
# poll for ready.txt, diff against the new-session start time

# Per-subprocess cost of the `eval "$(...)"` calls in integrations.zsh/darwin.zsh:
time ( for i in 1 2 3 4 5; do brew shellenv >/dev/null; done )   # etc.

# Starship's own module-level breakdown:
STARSHIP_LOG=trace starship prompt --terminal-width=200 2>&1 >/dev/null \
  | grep -oE 'Took [0-9.]+(µs|ms|ns) to compute module "[a-z_]+"'
```

Never touched the user's real tmux server — all timing used disposable
`perf<N>`/`trc`/`warmup` sessions on the default socket, killed after each
trial (`tmux kill-session`/`kill-server`), and `tmux ls` was checked first
each time to confirm nothing of the user's was running before any
`kill-server`.

## Learned behaviours & workarounds

- **Early SSH commands need PATH initialization in `/etc/zshenv`.** An
  interactive `.zshrc` fallback cannot help `herdr-core connect` over SSH.
  Use the persistent system profile while boot activation is still creating
  `/run/current-system`. Boot activation also needs its own probe scope:
  preserve `/etc` conflict checks, but leave app-update checks on full
  rebuilds. The boot log now records its result and duration. (2026-11-13)
- **macOS upgrades can replace managed Zsh startup links.** Missing `compdef`
  together with the wrong history path points to a replaced `/etc/zshrc`;
  inspect `/etc/zprofile` too. Restore the managed files with `nrs` so the
  completion system, plugins, and history settings all return. (2026-11-13)
- **xtrace timestamps lie about absolute cost, not relative order.** `-x`
  adds overhead proportional to the *number of interpreted lines* a step
  executes, not to real subprocess wall time. `compdump`'s internal loops
  looked wildly expensive under trace (~120ms) but the dump file's mtime
  proved it wasn't even rebuilding — the inflation was tracing overhead on
  zsh's own bytecode loop. Subprocess `fork`/`exec` costs (starship, brew,
  compaudit's `stat()`s) are *not* inflated the same way and can be trusted
  directly against standalone timing. Cross-check any surprising xtrace
  number against a standalone timing of that exact step before believing it.
  (2026-07-16)
- **`tmux new-session -d` returns before the shell is usable.** It only
  blocks until the pty is forked, not until rc files finish. Any latency
  measurement that stops the clock there under-counts by the full rc-load
  time. Use a `send-keys` sentinel file instead. (2026-07-16)
- **`stat -f` means two different things** depending on which `stat` is
  first on `$PATH`: BSD `stat -f '<format>'` vs GNU coreutils' `stat -f`
  (filesystem info, `df`-like) — if `nix`'s coreutils shadows `/usr/bin/stat`,
  a BSD-style format string silently gets ignored and you get `df` output
  instead. Use `/usr/bin/stat` explicitly when you need BSD semantics.
  (2026-07-16)

## Sources

- Repo: `home/zsh/.config/zsh/.zshrc`, `darwin.zsh`, `integrations.zsh`;
  `home/starship/.config/starship.toml`.
- [starship's zsh init script](https://starship.rs) (`starship init zsh`) —
  confirms the `PROMPT`/`RPROMPT` dual-invocation design.
- Machine-verified on `SOC-Kris-Williams`, 2026-07-16: all commands under
  "How this was tested" above, run live against this repo and a disposable
  tmux server.
