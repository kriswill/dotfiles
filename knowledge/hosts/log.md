# Log

## 2026-11-19

- **Update**: [SOC-Kris-Williams](SOC-Kris-Williams.md) enables
  [pam-tid-gate](../modules/pam-tid-gate.md).

## 2026-11-14

- **Update**: [mini](mini.md) records Kris's generation-30 idle-sleep policy: running/boot default agree and AC `sleep 0` is verified; display sleep remains unchanged. No reboot or activation was performed during integration.

- **Update**: [k](k.md) activated
  [git-signing-agent](../modules/git-signing-agent.md) in generation 291;
  a test commit and tag verify as `G` with the shared key.
- **Update**: [k](k.md) and [nebula](nebula.md) declare
  [git-signing-agent](../modules/git-signing-agent.md) with the key
  [mini](mini.md) signs with, loaded from a shared sops file and on only
  while that file is tracked. nebula activated it in generation 236 and
  signs with it; k has not activated it yet.
- **Update**: [k](k.md) booted generation 290 after codebase-memory removal. Job/executable/process absence is verified; desktop readiness and remote command timings are mixed, with user interaction and connection recovery confounders. The external observer covered reboot and was stopped after collecting samples.

## 2026-11-13

- **Update**: [k](k.md), [SOC-Kris-Williams](SOC-Kris-Williams.md) and [nebula](nebula.md) disable codebase-memory. Mini retains its disabled service default and loses the shared CLI installation. Existing boot-comparison evidence remains historical.

- **Update**: [k](k.md) tests `Standard` launchd scheduling for ai-usage only,
  with generation 289 measuring 0.492 seconds from xpcproxy to launchd spawn
  versus generation 288's 62.303 seconds. The unchanged Background
  codebase-memory job also improved (66.660 → 40.656 seconds), so the paired
  boot supports the setting without isolating every cause. Scheduled
  provider refreshes succeeded. Desktop restoration and 1Password remain
  intact; the temporary external observer's results were saved and it was stopped.

- **Update**: [mini](mini.md) activates generation 29 with launcher
  correction, credential timing and improved local token wait. Fresh signing
  and SSH pass. k and SOC-Kris-Williams configurations evaluate unchanged in
  their interactive desktop/1Password policies; k's separate session owns
  its live activation and reboot testing.

- **Update**: [mini](mini.md) records the verified generation-28 cold
  startup, explicit Hermes delegation through Core and the corrected
  requirement to let 1Password launch normally. General agent vault access
  remains separate from the root signing loader's credential.

- **Update**: [k](k.md) and [nebula](nebula.md) reconcile main with unrelated work preserved and gain per-host client keys for unattended Herdr connections; [mini](mini.md) trusts both identities.

- **Update**: [mini](mini.md) uses its [sops-managed machine SSH key](../modules/mini-ssh-client.md) for unattended outgoing access; all managed hosts declare trust, with the offline work Mac awaiting deployment.

## 2026-11-09

- **Update**: [mini](mini.md) runs
  [hermes-agent](../modules/mini-hermes-agent.md) inside its sandbox.

## 2026-11-05

- **Update**: [mini](mini.md) declares
  [git-signing-agent](../modules/git-signing-agent.md) (off until setup)
  and becomes a sops recipient (`&mini` in `.sops.yaml`).

## 2026-10-25

- **Update**: [nebula](nebula.md) launches Discord with
  `--disable-accelerated-video-decode` (`programs.discord.package =
  pkgs.discord.override { commandLineArgs = …; }`). Discord's Chromium GPU
  process was picking up nvidia-vaapi-driver 0.0.18 on its own, without
  `LIBVA_DRIVER_NAME` set, and decoding streams on NVDEC. On the RTX 5080
  that made every stream's video jump back and forth while the audio stayed
  fine. Decoding on the CPU fixes it, confirmed in an A/B test. Vesktop,
  also Chromium-based, gets the same flag through a `symlinkJoin` +
  `wrapProgram` wrapper, because nixpkgs' vesktop has no `commandLineArgs`.
- **Update**: [nebula](nebula.md) turns off VLC (snowglobe's desktop layer)
  and Tor Browser (its hacker-mode profile; the tor daemon stays). They were
  the only things pulling in ffmpeg 7.1.5 (41 nixploit findings, see
  [nebula-nixploit](../modules/nebula-nixploit.md)). The closure drops by
  about 550 MiB.
- **Update**: [nebula](nebula.md) turns off Lutris
  (`programs.lutris.enable = false`, overriding snowglobe's gaming profile).
  Its FHS runtime was the only thing pulling in ffmpeg 6.1.6 (39 nixploit
  findings, see
  [nebula-nixploit](../modules/nebula-nixploit.md)). The closure drops by
  about 900 MiB.

## 2026-10-14

- **Update** — [k](k.md): installs P4V, P4Admin and P4Merge 2026.3 through
  `environment.systemPackages` (`/Applications/Nix Apps`, Spotlight-indexed),
  replacing the drag-installed DMG copies
  ([decision](../decisions/p4v-nix-apps-dont-strip.md)).

## 2026-08-02

- **Addition** — [nebula](nebula.md):
  `modules/hosts/nebula/herdr-update-check.nix`, a daily systemd user timer
  that fetches herdr's version from nixos-unstable (one raw-GitHub fetch) and
  pops a dismissable notification (action → upstream releases page) once it
  exceeds the pinned 0.7.5 — the prompt to drop the herdr preview-flake pin
  ([herdr module](../modules/herdr.md)). Deliberately temporary: the file is
  deleted together with the pin.

## 2026-07-03

- **Update** — [nebula](nebula.md) gained a "Firmware quirks" section:
  the warm-reboot DRAM-training hang (debug code 44 + yellow DRAM LED on BIOS
  `2.A02`; userspace shutdown was clean, the firmware stalled re-training DDR5
  — cold cycle clears it; fix = BIOS update past `2.A02` or Memory Context
  Restore), plus the standing `Wake Up Event By = OS` suspend fact with the
  reminder that a BIOS flash resets it.
