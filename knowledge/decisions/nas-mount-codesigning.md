---
type: Decision
title: nas-mount Codesigning — Manual, Transient, Never Committed
description: 'Login Items shows "Unidentified Developer" for every nix-built launchd agent. Rejected both doing OS codesigning inside nix-darwin activation (fails — root cannot reach the login keychain''s private-key ACL) and committing the exported private key via sops (real, permanent exposure of an Apple Developer ID for a cosmetic label). Landed on rcodesign + a transient, never-persisted .p12 export the machine owner runs by hand — kept over plain codesign specifically so the same approach can later run non-interactively in CI. rcodesign only signs Mach-O/bundle/DMG/pkg, so nas-mount became a compiled Rust binary (pkgs/nas-mount/) instead of a shell script.'
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

**Update (2026-07-09):** generalized into
`scripts/sign-launchd-agents.ts` (bun, `rcodesign` added to the dev shell in
`modules/dev.nix`) — an fzf picker over every plist in
`~/Library/LaunchAgents`, showing each one's current signature status
(Developer ID / Apple-signed-no-team / ad-hoc / unsigned / unresolved),
Authority, and `Signed Time`, with multi-select so a whole batch signs off
one passphrase entry instead of repeating the export per agent. Same
transient-`.p12`-only posture; anything under `/nix/store/` is flagged and
skipped (needs a stable-path module like `nas-mount.nix` first). Confirmed
its signature-status parsing against live data on this machine — correctly
distinguished `nas-mount` (unsigned), `/bin/launchctl` (Apple-signed, no
team), and `cbm-daemon`/`gpg-connect-agent` (ad-hoc, `flags=0x20002(adhoc,
linker-signed)` — Go/Rust linker auto-signing).

**Bug found and fixed (2026-07-09):** the stable-path file ended up
`r-xr-xr-x` (no write bit) — `cp` copies the nix store source's read-only
mode, and `chmod +x` only ever adds execute bits, never touches read/write,
so the missing write bit was permanent from the very first activation.
`rcodesign sign-launchd-agents` correctly reported it as read-only and
skipped it. Fixed by changing `chmod +x` to `chmod u+w,+x`, and — since
permission bits don't affect a code signature — moved it **outside** the
`cmp -s` content-diff guard so it re-asserts on every activation regardless
of whether the mount logic changed, making it self-healing rather than a
one-time fix.

**Second bug found and fixed (2026-07-09):** signing then failed differently
— `rcodesign` errored `specified path is not of a recognized type`.
`rcodesign sign` only handles Mach-O binaries, bundles, DMGs, or `.pkg`
installers — not a plain shell script, which `nas-mount` was (via
`pkgs.writeShellScriptBin`). Considered switching the signer to plain OS
`codesign` instead (which signs any file via its "signed generic" mode, and
would work fine since this tool is always run in Kris's own interactive
session) — **rejected**: the whole reason `rcodesign` was chosen over
`codesign` in the first place is that it never touches the Keychain/session
ACL at all, which is what will let this same signing approach eventually run
non-interactively in GitHub CI (certs stored there securely — not
implemented yet, noted for later). Plain `codesign` could never do that.
Fixed the actual mismatch instead: rewrote `nas-mount` as a genuinely
compiled Mach-O binary — `pkgs/nas-mount/` (`main.rs`, pure `std`, no
external crates, built via a bare `rustc -O` in a plain `stdenv.mkDerivation`
rather than `rustPlatform.buildRustPackage`'s Cargo.lock machinery),
registered as a proper package (`modules/packages.nix`,
`overlays/nas-mount.nix`) and referenced from `nas-mount.nix` as
`pkgs.nas-mount` instead of `writeShellScriptBin`. `mountPoint`/`share` are
now passed as CLI arguments (via launchd's `ProgramArguments`) rather than
baked into the script text, so the binary itself stays generic. Bonus:
rustc/the linker auto-ad-hoc-signs the output at build time
(`flags=0x20002(adhoc,linker-signed)`, same as the Go-built `cbm-daemon`) —
Login Items shows 🔏 ad-hoc instead of ❌ unsigned even before any manual
`rcodesign` run.

**Third bug found and fixed (2026-07-09):** signing succeeded (real,
non-ad-hoc signature, `flags=0x0(none)`) but Login Items *still* showed
"unidentified developer." `codesign -dv` on the result showed
`Authority=Apple Development: Kris Williams (X8B24Z8GP2)` — a different cert
than the "Developer ID Application: Kris Williams (Y6VCVC728W)" one set up
for this — even though `TeamIdentifier=Y6VCVC728W` (same team) matched.
Root cause: `security export -k ... -t identities -f pkcs12` exports **every
identity in the keychain**, no exceptions — there is no `security export`
flag that filters to one specific item (confirmed via web search: this is a
documented, known limitation, not something scriptable around). Kris's
keychain also holds an "Apple Development" cert (Xcode's local-testing
identity, a different purpose/chain than distribution-grade "Developer ID
Application"), and `rcodesign` — despite its own docs saying it errors when
more than one signing key is present in a `.p12` — silently picked that one
instead. "Apple Development" certs chain through Apple Worldwide Developer
Relations, not the Developer ID Certification Authority chain Gatekeeper/BTM
check for identified-developer attribution, so the label persisted despite
a genuinely real signature.

**Fix:** stopped calling `security export` programmatically at all. Both
`sign-launchd-agents.ts` and the manual procedure in
`docs/unifi-dream-machine.md` now require exporting the *one* wanted
identity yourself via Keychain Access.app's GUI (which does support
selecting a single item — right-click → Export Items…) and just prompt for
that `.p12` file's path plus its passphrase. Considered instead temporarily
removing the "Apple Development" identity from the keychain before
export — rejected as needlessly invasive to an unrelated Xcode-managed item
for a session-scoped ambiguity that a one-time GUI export solves cleanly.

**Final act (2026-07-09): the correct signature changed nothing — the label
needs an app bundle, not a signature.** With the right Developer ID
signature finally on the binary, BTM still recorded
`Developer Name: (null)`. Apple's design (DTS,
developer.apple.com/forums/thread/721918): Login Items attributes launchd
items through an *associated app bundle* via the plist's
`AssociatedBundleIdentifiers`, never through a bare executable's signature.
Implemented: `pkgs/nas-mount` now also builds
`$out/Applications/NasMount.app` (Info.plist, `net.kris.nas-mount`,
`LSUIElement`, icns rendered from an SF Symbol by the checked-in
`make-icon.swift`) — which conveniently also delivers the custom icon
originally wished for. Four more load-bearing discoveries:

1. **An unsigned bundle wrapping a linker-signed binary is an invalid code
   object** — launchd refuses to spawn it (`EX_CONFIG`, empty job log,
   `codesign -v`: "code has no resources but signature indicates they must
   be present"). Fixed by `rcodesign sign` (keyless = ad-hoc) in
   `postFixup` — pure Rust, sandbox-safe; postFixup because fixupPhase's
   `strip` would invalidate an install-time signature.
2. **nix-darwin's `launchd.user.agents` cannot express
   `AssociatedBundleIdentifiers`** — its serviceConfig submodule is closed.
   The module writes the plist itself into `environment.userLaunchAgents`
   (which is all `launchd.user.agents` funnels into anyway).
3. **A `cp`-installed app is invisible to LaunchServices**, and Login Items
   resolves the association through LS — `lsregister -f` after the copy
   (now in the module's postActivation) or the group shows a blank icon and
   the bare developer name.
4. **BTM caches by plist path and never re-reads on content change** — the
   refresh is `launchctl bootout` + `rm` the plist, wait ~60–75s for btmd to
   drop the record, restore, `bootstrap`, reopen System Settings. Also:
   `sfltool dumpbtm` fires an admin auth prompt per invocation — don't poll
   it; the Settings pane is the readout.

End state verified live: Login Items shows **NasMount** with the custom
icon; BTM: `Name: NasMount`, `Developer Name: Kris Williams`,
`Team Identifier: Y6VCVC728W`. Notarization was **not** required
(`spctl -a` still says "Unnotarized Developer ID" — irrelevant without a
quarantine bit).
