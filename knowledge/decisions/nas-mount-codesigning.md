---
type: Decision
title: nas-mount Codesigning — Manual, Transient, Never Committed
description: 'Login Items shows "Unidentified Developer" for every nix-built launchd agent. Rejected both doing OS codesigning inside nix-darwin activation (fails — root cannot reach the login keychain''s private-key ACL) and committing the exported private key via sops (real, permanent exposure of an Apple Developer ID for a cosmetic label). Landed on rcodesign + a transient, never-persisted .p12 export the machine owner runs by hand.'
tags: [darwin-module, codesigning, security, nas-mount]
timestamp: '2026-07-09T19:35:00Z'
---

**Status:** active. **Where:** [nas-mount](../modules/nas-mount.md)
(`modules/darwin/nas-mount.nix`), `docs/unifi-dream-machine.md` ("Manually
codesigning nas-mount").

## Context

macOS's System Settings > Login Items pane labels every nix-darwin-managed
launchd item "Item from unidentified developer" — confirmed via
`sfltool dumpbtm` that this is driven by whether the *executable at
`Executable Path`* carries a real Apple Developer ID Team Identifier in its
code signature, not by anything about how the plist was installed (even
1Password's own hand-dropped LaunchAgent shows the same label; Determinate
Systems' `determinate-nixd`, genuinely signed with Team ID `X3JQ4VPJZ6`,
does not). Kris enrolled in the Apple Developer Program and obtained a real
Developer ID Application certificate specifically to fix this for `nas-mount`.

## Options considered

1. **Do nothing.** Free, but the label stays. (Ultimately not chosen alone —
   see below.)
2. **Sign inside `system.activationScripts.postActivation`** using the OS
   `codesign` tool against the identity now in Kris's login keychain.
   **Ruled out — provably doesn't work.** `codesign` needs the private key,
   which lives behind the login keychain's interactive ACL. Root-run
   activation scripts (even via `launchctl asuser <uid>` to reattach to the
   target user's GUI/Aqua session, not just a bare `sudo -u k` UID switch)
   still hit `CSSMERR_TP_NOT_TRUSTED` / `Permission denied` — confirmed this
   is a genuine macOS security boundary (the login keychain's private-key
   material is walled off from root, even root attached to the right
   session), not a fixable quoting/plumbing bug. Verified the identity and
   trust chain themselves were fine throughout (`security verify-cert -p
   codeSign` succeeded; the missing "Developer ID - G1" intermediate
   certificate was identified by matching Authority/Subject Key Identifiers
   and installed) — the failure was specifically about *who* can use the
   key, not whether the cert chain was trusted.
3. **Export the private key once, sops-encrypt it, commit it, decrypt +
   sign automatically on every `nrs`.** Technically viable (`rcodesign`
   signs directly from a `.p12`/PEM key pair, bypassing the Keychain/ACL
   problem in option 2 entirely) — but **rejected**. This would move a real,
   Apple-verified signing identity from Keychain's protected, effectively
   non-exportable storage into a git-tracked encrypted blob that persists in
   history *forever*, decrypted to a runtime path on every single
   activation. The blast radius of that key ever leaking is someone signing
   arbitrary software as "Kris Williams," trusted by Gatekeeper on other
   people's Macs — a real, if Apple-revocable, reputational risk — for a
   benefit that is purely cosmetic (a nicer label in a settings pane almost
   nobody opens).
4. **Export the private key transiently, sign manually, delete
   immediately — never committed, never automated.** **Chosen.** `rcodesign`
   sidesteps the keychain ACL problem the same way option 3 would, but the
   key material only ever exists in a `mktemp -d` directory for the seconds
   it takes to run the sign command, and only when Kris deliberately chooses
   to run it himself. Nothing new is ever written to disk persistently or to
   git.

## Decision

Keep `nas-mount.nix` simple: `system.activationScripts.postActivation` only
copies the latest nix-built (unsigned) script to a stable external path
(`~/.local/state/nas-mount/nas-mount` — needed regardless, since the nix
store is read-only and its build sandbox has no keychain access either) —
guarded by `cmp -s` so an existing manual signature survives any `nrs` that
doesn't actually change the mount logic. Signing that stable path is a
separate, manual, undocumented-in-nix procedure the machine owner runs
himself in his own terminal — see `docs/unifi-dream-machine.md` for the exact
script. This is deliberately **not** wired into the flake at all: the whole
point is that it must stay something a human chooses to do, not something
that runs unattended.

## Consequences

- The real private key never leaves Keychain except for the brief window of
  a manual re-sign; nothing new is ever committed.
- Re-signing is a manual chore, needed again whenever `nas-mount.nix`'s
  mount logic changes (the `cmp -s` guard means routine `nrs` runs that
  don't touch it leave an existing signature alone).
- If the identified-developer label is ever wanted for another custom
  launchd module, this same manual procedure generalizes directly — no new
  design needed, just point `rcodesign` at the new stable path.
