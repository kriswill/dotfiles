# Darwin codesigning — launchd agents, Login Items attribution, signing tooling

**Verified against:** macOS 26.5.1 (build 25F80) on host `k` (aarch64-darwin);
`rcodesign` 0.29.0 (dev-shell PATH via `modules/dev.nix`); Apple Developer
Program individual membership with **Developer ID Application: Kris Williams
(Y6VCVC728W)** in the login keychain. Worked example throughout: `nas-mount`
(`modules/darwin/nas-mount.nix` + `pkgs/nas-mount/`), whose Login Items entry
went from "nas-mount — Item from unidentified developer" to "NasMount" with a
custom icon and real developer attribution. Checked 2026-07-09; automated
activation-time signing added 2026-07-10 (see that section below).

## The signing identity

- **Cert types matter.** "Developer ID Application" is the distribution-grade
  identity Gatekeeper/BTM attribution chains through. "Apple Development"
  (Xcode's local-testing cert), "Apple Distribution", "Mac Developer ID
  Installer" etc. are different animals — signing with an Apple Development
  cert produces a *real, valid* signature (`TeamIdentifier` and all) that
  still counts as unidentified, because it chains through Apple WWDR instead
  of the Developer ID Certification Authority.
- **Fresh web-portal certs are missing their intermediate.** A cert created
  via developer.apple.com (rather than Xcode) imports without the
  "Developer ID Certification Authority" intermediate, and every `codesign`
  attempt fails `CSSMERR_TP_NOT_TRUSTED` (surfacing as a bare
  `Permission denied`). Diagnose by matching the leaf's Authority Key
  Identifier against the candidates' Subject Key Identifiers
  (`openssl x509 -noout -text | grep -A1 'Key Identifier'`); Apple publishes
  both generations at
  [apple.com/certificateauthority](https://www.apple.com/certificateauthority/)
  (`DeveloperIDCA.cer` = G1, `DeveloperIDG2CA.cer` = G2). Install with
  `security add-certificates -k ~/Library/Keychains/login.keychain-db <cer>`;
  `security verify-cert -p codeSign -c <leaf.pem>` confirms the chain.
- **First use of the private key needs an interactive ACL grant** — macOS
  pops "codesign wants to access key …"; click **Always Allow** (entering the
  login password) or every future use prompts again. `security
  set-key-partition-list -S apple-tool:,apple:,codesign: -s` is the CI-style
  bulk equivalent, but unscoped it touches *every* signing-capable key in the
  keychain — prefer the per-key GUI grant.

## Two signing tools, two trust paths

| | `codesign` (Apple) | `rcodesign` (apple-codesign, in dev shell) |
|---|---|---|
| Key source | Keychain (session ACL) | `.p12`/PEM file you supply |
| Works from root/activation scripts | ❌ (see boundaries) | ✅ (no Keychain at all) |
| Works in the nix build sandbox | ❌ | ✅ (keyless ad-hoc, or with key material) |
| CI-viable | ❌ | ✅ technically — but by decision CI holds **no** signing key (see `knowledge/decisions/ci-github-actions.md`); the automated path runs at *activation* on the host instead |
| Signs | anything ("signed generic" for non-code) | **Mach-O / bundle / DMG / pkg only** — errors `specified path is not of a recognized type` on scripts |

This repo standardizes on **rcodesign** (decision:
`knowledge/decisions/nas-mount-codesigning.md`) — the CI path is the point.
Consequence: anything we want signed must be a real Mach-O or bundle, which
is why `pkgs/nas-mount` is a compiled Rust binary, not a shell script.

## Hard boundaries (all verified, don't re-attempt)

- **Root cannot reach the login keychain's private keys. Period.** Not from
  `system.activationScripts` via `sudo -u k`, not via `launchctl asuser <uid>`
  to reattach the GUI session — the key material is walled off from root
  even inside the right session. Only a process genuinely running as the
  user in their real login session can use it. This is why OS `codesign`
  can never be wired into `nrs` — the automated activation path (below)
  works only because rcodesign signs from a key *file*, no keychain
  involved.
- **The nix build sandbox has no keychain either** — but keyless
  `rcodesign sign` (ad-hoc) works fine there, which is load-bearing (below).
- **`security export` cannot export a single identity** — `-t identities`
  sweeps up *everything*, no per-item filter exists (documented CLI
  limitation). With multiple identities in one `.p12`, `rcodesign` silently
  picks one — it chose the wrong ("Apple Development") cert here despite its
  docs claiming it errors on ambiguity. **Always export the one wanted
  identity via Keychain Access.app** (My Certificates → right-click →
  Export Items… → `.p12`; the `.p12` option is greyed out unless the item
  includes its private key — use the My Certificates category, not
  Certificates).
- **The personal Keychain identity is never exported or committed.** The
  original blanket "no key in sops" rejection was narrowed 2026-07-10: what
  stays forbidden is exporting the Keychain-held Developer ID identity; a
  **dedicated, purpose-minted cert whose key was born outside Keychain**
  (openssl CSR → portal) IS sops-committed for the automated path below —
  accepted-risk trade recorded in
  `knowledge/decisions/nas-mount-codesigning.md` (2026-07-10 update).

## Signing launchd agents: `sign-launchd-agents`

`scripts/sign-launchd-agents.ts` (bun; on PATH in the dev shell via `bin/`)
is the batch tool. It scans `~/Library/LaunchAgents`, resolves each plist's
executable, and shows an fzf picker — status icon (✅ Developer ID /
🍎 Apple-signed-no-team / 🔏 ad-hoc / ❌ unsigned / ❓ unresolved), Authority,
Signed Time, live `codesign -dv` preview. Multi-select, then supply the path
to your Keychain-Access-exported `.p12` + passphrase once for the whole
batch. When an executable lives inside a `.app`, it signs the **bundle**
(the code object Login Items attributes), not the bare inner Mach-O.
Executables under `/nix/store/` are flagged read-only and skipped — they
need a stable-path copy module first (`nas-mount.nix` is the template).

Run it yourself, interactively — never through an agent session: the
passphrase must not enter a transcript, and only your session could use the
Keychain anyway. Delete the `.p12` when done.

## Login Items attribution: the .app bundle recipe

**A correct Developer ID signature on a bare launchd executable changes
nothing** — BTM recorded `Developer Name: (null)` for a validly signed
binary. Apple attributes launchd items through an **associated app bundle**
([DTS answer](https://developer.apple.com/forums/thread/721918)), wired by
the plist's `AssociatedBundleIdentifiers`. The full working recipe:

1. **Ship a real `.app`** — `pkgs/nas-mount` builds
   `$out/Applications/NasMount.app` (Info.plist:
   `CFBundleIdentifier = net.kris.nas-mount`, `LSUIElement = true` for
   no-Dock background apps, `CFBundleIconFile` → an icns) alongside
   `bin/nas-mount`. Icon rendered once from an SF Symbol by the checked-in
   `pkgs/nas-mount/make-icon.swift` (`swift make-icon.swift out.iconset &&
   iconutil -c icns out.iconset` — run with `env -u SDKROOT`, the dev
   shell's nix apple-sdk poisons the system Swift toolchain).
2. **Ad-hoc sign the bundle at build time** — `rcodesign sign` in
   **`postFixup`**. Not optional: rustc's linker signs the standalone
   Mach-O, but that seals no Info.plist/Resources, so the enclosing bundle
   is an *invalid code object* — launchd refuses to spawn it with
   `last exit code = 78: EX_CONFIG` and an **empty job log** (`codesign -v`
   on the bundle: "code has no resources but signature indicates they must
   be present"). postFixup, not postInstall: fixupPhase's `strip` runs after
   install and invalidates earlier signatures.
3. **Plist**: `ProgramArguments[0]` inside the deployed app +
   `AssociatedBundleIdentifiers = [ <bundle id> ]`. nix-darwin's
   `launchd.user.agents` serviceConfig is a **closed submodule without that
   key** — write the plist yourself into `environment.userLaunchAgents`
   (which is the only thing `launchd.user.agents` feeds anyway).
4. **Deploy outside the store + `lsregister -f`** — the module copies the
   app to `~/Applications` (stamp-file guard: re-copy only when the store
   path changed, so a manual Developer ID signature survives unrelated
   `nrs` runs; `chmod -R u+w` after — `cp` preserves the store's read-only
   bits and signing must write into the bundle). Then
   `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f <app>`:
   a cp-installed bundle is invisible to LaunchServices, and Login Items
   resolves the association through LS — without it the entry shows a blank
   icon and the bare developer name.
5. **Bust the BTM cache** — BTM keys its record on the plist *path* and
   never re-reads on content change (survives `launchctl bootout` +
   `bootstrap`). Refresh: `launchctl bootout gui/$UID/<label>`, `rm` the
   plist, wait ~60–75 s for btmd to drop the record, restore the plist,
   `launchctl bootstrap gui/$UID <plist>`, then **⌘Q and reopen System
   Settings** (the pane caches too). `sfltool resetbtm` also works but
   nukes/re-prompts every login item on the machine.
6. **Sign the deployed bundle** (Developer ID, on top of the build-time
   ad-hoc signature) whenever the app was re-copied. For nas-mount this is
   automated at activation (next section); for other agents it's the manual
   `sign-launchd-agents` run.

End state, verified live: Login Items shows **NasMount**, custom icon,
`Developer Name: Kris Williams`, `Team Identifier: Y6VCVC728W`.
**Notarization is NOT required** — `spctl -a` still reports "Unnotarized
Developer ID", which is irrelevant for locally-installed agents (no
quarantine bit).

## Automated activation-time signing (nas-mount)

Since 2026-07-10 `modules/darwin/nas-mount.nix` signs the deployed bundle
itself during `postActivation`, replacing the manual `sign-launchd-agents`
chore *for this one agent*. The pieces:

- **A dedicated identity, minted outside Keychain.** The key is generated
  with openssl and never enters Keychain; the personal Keychain identity is
  never exported. Minting:

  ```sh
  cd "$(mktemp -d)"
  # PKCS#8 framing ("BEGIN PRIVATE KEY") is REQUIRED — rcodesign's
  # --pem-file parser ignores legacy PKCS#1 "BEGIN RSA PRIVATE KEY".
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out nas-signing.key
  openssl req -new -key nas-signing.key -out nas-signing.certSigningRequest \
    -subj "/emailAddress=kris@kris.net/CN=Kris Williams/C=US"
  # developer.apple.com → Certificates → "+" → Developer ID Application
  # (NOT Apple Development/Distribution) → upload CSR → download .cer.
  openssl x509 -inform DER -in developerID_application.cer -out leaf.pem
  curl -sO https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer
  openssl x509 -inform DER -in DeveloperIDG2CA.cer -out devid-ca.pem
  openssl verify -partial_chain -CAfile devid-ca.pem leaf.pem   # sanity
  cat nas-signing.key leaf.pem devid-ca.pem > nas-signing.pem
  ```

- **PEM ordering is load-bearing.** rcodesign's `--pem-file` help: there
  must be 0 or 1 signing keys present, and *the first encountered
  certificate is paired with the key* — all remaining certs become the
  embedded CA chain. So: key, then leaf, then intermediate. (rcodesign
  auto-registers Apple's chain for Apple-issued certs, but embedding the
  G2 intermediate keeps the signature self-contained.)
- **Storage: sops.** The PEM lives as `nas-signing-pem` in
  `modules/hosts/k/secrets.yaml`
  (`sops set modules/hosts/k/secrets.yaml '["nas-signing-pem"]' "$(jq -Rs . nas-signing.pem)"`),
  declared with `owner = "k"` in `modules/hosts/k/default.nix` — the
  signing step runs `sudo -u k` and the default `root:staff 0400` is
  unreadable there. sops-nix installs `/run/secrets/*` at postActivation
  order 1500 (`mkAfter`); the nas-mount block runs at 1600 in the *same*
  `darwin-rebuild switch`. **sops-nix validates at build time that every
  declared secret exists in the sops file** — declare the secret only
  after the key is in secrets.yaml or the build fails.
- **The trigger** is a fresh stamp-guarded copy OR `codesign -dvv` lacking
  `Authority=Developer ID Application` (never gate on `TeamIdentifier=` —
  a wrong-type cert matches it). Failures warn without failing activation
  and re-arm the next run.
- **Rotation** = mint a new key/CSR/cert (steps above), replace the sops
  value, `nrs`. **Revocation** (leak response, not routine) = revoke just
  the dedicated cert with Apple — the Keychain identity is untouched.
  Public-repo caveat: the encrypted blob is permanent in git history and
  encrypted only to host k's ssh-host-key-derived age key; rotation IS the
  recovery story.

## Learned behaviours & workarounds

- **(2026-07-10) sops-nix fails the whole system build when a declared
  secret's key is missing from the sops file** — `sops-install-secrets:
  manifest is not valid: … the key 'x' cannot be found` from the
  `manifest.json` derivation. Add the key to secrets.yaml *before*
  declaring `sops.secrets.x`.
- **(2026-07-10) rcodesign `--pem-file` pairs the FIRST certificate with
  the signing key** and requires PKCS#8 (`BEGIN PRIVATE KEY`) framing;
  leaf-before-intermediate ordering in a concatenated PEM is mandatory.
- **(2026-07-09) Developer ID signing a bare launchd executable does not
  fix "unidentified developer"** — only an associated .app bundle does (see
  recipe above). Don't spend time on notarization for this either; it was
  not needed.
- **(2026-07-09) An unsigned bundle wrapping a linker-signed binary is an
  invalid code object** — launchd `EX_CONFIG` with an empty job log looks
  like a config error but is a signature problem; `codesign -v <app>` names
  it. Keyless `rcodesign sign` in postFixup fixes it permanently.
- **(2026-07-09) BTM caches by plist path; content changes never refresh
  it.** After changing a plist's exec path or signing its app: bootout →
  rm plist → ~75 s → restore → bootstrap → reopen Settings.
- **(2026-07-09) `sfltool dumpbtm` fires an admin auth prompt per
  invocation** — fine once for diagnosis, hostile in loops. The Settings
  pane (after ⌘Q) is the readout.
- **(2026-07-09) A "wrong" identity still signs successfully.** An Apple
  Development cert yields a valid timestamped signature with the right
  TeamIdentifier — check `Authority=Developer ID Application: …`
  specifically, not just that a signature exists.
- **(2026-07-09) `CSSMERR_TP_NOT_TRUSTED` / `Permission denied` from
  codesign with a valid-looking cert** = missing Apple intermediate (G1 vs
  G2 — match AKI↔SKI), or the key's ACL not yet granted, or you're not in a
  real user session. In that order.
- **(2026-07-09) The dev shell breaks the system Swift toolchain** — nix's
  apple-sdk sets `SDKROOT`, and `swift` then fails with `no such module
  'SwiftShims'`. `env -u SDKROOT PATH=/usr/bin:/bin xcrun swift …` for
  one-off AppKit scripts like the icon generator.
- **(2026-07-09) `pkgs.writeShellScript` leaks the store hash into Login
  Items** — it puts the file at the store path's top level, so the
  executable's own basename is `<hash>-name`. Anything `bin/`-nested
  (`writeShellScriptBin`, a real package) displays clean.

## Sources

- Live verification on host `k` 2026-07-09: `codesign -dv`, `spctl -a`,
  `sfltool dumpbtm`, `launchctl print`, `lsregister`, System Settings pane;
  full narrative in `knowledge/decisions/nas-mount-codesigning.md`.
- [Apple DTS on AssociatedBundleIdentifiers](https://developer.apple.com/forums/thread/721918)
- [Apple PKI intermediates](https://www.apple.com/certificateauthority/)
- [rcodesign / apple-codesign](https://github.com/indygreg/apple-platform-rs)
- Worked example: `modules/darwin/nas-mount.nix`, `pkgs/nas-mount/`,
  `scripts/sign-launchd-agents.ts`, PR #32.
