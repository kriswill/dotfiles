---
type: Playbook
title: Set Up, Rotate, and Revoke Prompt-Free Git Signing
description: 'How the automation signing key was created for mini (1Password vault and service account), how it is put in sops for the hosts that load it from there (k, nebula), and how to verify, rotate, and revoke it.'
tags: [git, 1password, secrets, sops]
generated: { by: claude-code/fable-5.2, at: 2026-11-14T13:40:00-08:00 }
sources:
  - id: op-service-account-cli
    resource: https://developer.1password.com/docs/cli/reference/management-commands/service-account/
    title: op service-account create (--vault, --expires-in, --raw)
  - id: op-secret-reference-syntax
    resource: https://developer.1password.com/docs/cli/secret-reference-syntax/
    title: 1Password secret reference syntax
  - id: github-signing-key
    resource: https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key
    title: 'GitHub: telling Git about your signing key'
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix (creation rules, updatekeys, build-time validation of declared keys)
---

Background: [headless-git-signing-agent](../decisions/headless-git-signing-agent.md)
(the agent, mini's 1Password source) and
[git-signing-key-in-sops](../decisions/git-signing-key-in-sops.md) (the same
key in sops for k and nebula). Module:
[git-signing-agent](../modules/git-signing-agent.md). Hosts:
[mini](../hosts/mini.md), [k](../hosts/k.md), [nebula](../hosts/nebula.md).

There is one key. Its private half lives in the 1Password item
`mini-automation/mini git signing key`, and its public half in
`modules/hosts/git-signing.pub`. mini reads it from 1Password at agent
start; k and nebula read a copy from `modules/hosts/git-signing.yaml`.

## Setup: the key, the service account, and mini

Done once, on 2026-11-05. Run steps 1–4 on a machine with the 1Password
desktop app unlocked, CLI integration on, and a checkout of this repo that
includes the module (k works). Run them from the repo root inside the dev
shell, which provides `sops` and `jq`.

1. **Vault and key.** Make a new vault holding only this key. A service
   account can't be granted the Private vault.

   ```sh
   op vault create mini-automation --description "mini headless automation: git signing key only"
   op item create --vault mini-automation --category "SSH Key" \
     --title "mini git signing key" --ssh-generate-key ed25519 >/dev/null
   ```

2. **Service account**, read-only on that vault. Its token is printed only
   once, so capture it in a variable and bank it in Private straight
   away.[^op-service-account-cli] No expiry is the default. With
   `--expires-in 90d` you take on a rotation chore, and signing breaks at
   the first reboot after the token expires.

   ```sh
   tok=$(op service-account create mini-automation --vault mini-automation:read_items --raw)
   printf '%s' "$tok" | jq -Rs '{title: "mini-automation token", category: "API_CREDENTIAL",
     fields: [{id: "credential", label: "credential", type: "CONCEALED", value: .}]}' \
     | op item create --vault Private - >/dev/null
   OP_SERVICE_ACCOUNT_TOKEN="$tok" op vault list   # exactly one row: mini-automation
   unset tok
   ```

   If `op item create` fails, `$tok` still holds the token. Copy it with
   `printf '%s' "$tok" | pbcopy` and save it in the app as an API
   Credential called "mini-automation token" in Private.

3. **Repo files.** Write the public key and the allowed_signers line, then
   encrypt the token to mini.[^op-secret-reference-syntax] This needs only
   mini's public age recipient and its creation rule in `.sops.yaml`, so
   pull first: without the rule, `sops` fails with `no matching creation
   rules found`. The block checks for the rule and changes nothing if it's
   missing. It's safe to re-run: it rewrites the public key, adds the
   allowed_signers line only once, and replaces `secrets.yaml` only after
   `sops` succeeds (a bare `> secrets.yaml` redirect empties the file
   before `sops` runs, and a failed token read would encrypt an empty
   token).

   ```sh
   if ! grep -q 'path_regex: modules/hosts/mini/secrets.yaml' .sops.yaml; then
     echo "stop: .sops.yaml has no mini rule yet; git pull first"
   elif ! key=$(op read "op://mini-automation/mini git signing key/public key"); then
     echo "stop: could not read the public key from 1Password"
   else
     pub=modules/hosts/git-signing.pub
     printf '%s\n' "$key" > "$pub"
     grep -qF "$(cut -d' ' -f2 "$pub")" home/git/.config/git/allowed_signers || {
       echo "# automation: the git-signing-agent key of mini, k and nebula ($pub)"
       printf '115474+kriswill@users.noreply.github.com %s\n' "$(cut -d' ' -f1,2 "$pub")"
     } >> home/git/.config/git/allowed_signers
     tmp=$(mktemp)
     if tok=$(op read 'op://Private/mini-automation token/credential') && [ -n "$tok" ] &&
        printf 'op-sa-token: "%s"\n' "$tok" | sops encrypt --filename-override modules/hosts/mini/secrets.yaml \
          --input-type yaml --output-type yaml /dev/stdin > "$tmp"; then
       mv "$tmp" modules/hosts/mini/secrets.yaml && echo "ok: secrets.yaml encrypted to mini"
     else
       echo "stop: encrypting the token failed; secrets.yaml left as it was"
     fi
     unset tok key tmp
   fi
   ```

   Then set `services.git-signing-agent.enable = true;` in
   `modules/hosts/mini/default.nix` and commit the new files (flakes only
   see tracked files). Naming the paths keeps the rest of the working tree
   out of the commit:

   ```sh
   git add modules/hosts/git-signing.pub modules/hosts/mini/secrets.yaml
   git commit -m "mini: enable git-signing-agent" -- modules/hosts/mini/default.nix \
     modules/hosts/git-signing.pub modules/hosts/mini/secrets.yaml \
     home/git/.config/git/allowed_signers && git push
   ```

4. **GitHub signing key.** Add `git-signing.pub` as a **Signing Key**: in
   the web UI, Settings → SSH and GPG keys → New SSH key → Key type:
   Signing Key.[^github-signing-key] An authentication key never makes
   commits Verified. Or with gh:

   ```sh
   gh auth refresh -h github.com -s admin:ssh_signing_key
   gh ssh-key add modules/hosts/git-signing.pub --type signing --title "mini (git-signing-agent)"
   ```

5. **Deploy on mini:** `git pull`, then `nrs`. sudo asks for a password
   over ssh.

## Put the key in sops (k and nebula)

k and nebula load the key from `modules/hosts/git-signing.yaml`, and turn
the agent on only while that file is tracked. Run this from the repo root
in the dev shell, on a machine with the 1Password desktop app unlocked.
1Password asks for approval once. The key goes from `op` to `sops`
through a pipe and is never written to disk unencrypted.

The block changes nothing unless every step succeeds. It first checks that
the 1Password item is the key the repo already trusts, and it replaces the
file only after `sops` has written the new one. Encrypting needs only the
recipients' public keys, so any checkout with the `.sops.yaml` rule can
run it.[^sops-nix]

```sh
out=modules/hosts/git-signing.yaml
item='op://mini-automation/mini git signing key'
tmp=$(mktemp)
if ! grep -q "path_regex: $out" .sops.yaml; then
  echo "stop: .sops.yaml has no rule for $out; git pull first"
elif [ "$(op read "$item/public key" | cut -d' ' -f1,2)" != "$(cut -d' ' -f1,2 modules/hosts/git-signing.pub)" ]; then
  echo "stop: could not read the 1Password item, or it is not modules/hosts/git-signing.pub"
elif key=$(op read "$item/private key?ssh-format=openssh") && [ -n "$key" ] &&
     printf '%s\n' "$key" | jq -Rs '{"git-signing-key": .}' |
       sops encrypt --filename-override "$out" --input-type json --output-type yaml /dev/stdin > "$tmp"; then
  mv "$tmp" "$out" && git add "$out" && echo "ok: $out encrypted"
else
  echo "stop: nothing written; $out left as it was"
fi
unset key; rm -f "$tmp"
```

Then check the build, commit, and switch each host:

```sh
nrb                       # on nebula: builds and diffs, no activation
git commit -m "git-signing: the key in sops for k and nebula" -- modules/hosts/git-signing.yaml
nrs                       # on nebula; then git push, and on k: git pull && nrs
```

**Another host:** add its age anchor to the `git-signing.yaml` rule in
`.sops.yaml`, re-run the block above (or `sops updatekeys
modules/hosts/git-signing.yaml` with an age identity that can already
decrypt it), and enable `services.git-signing-agent` in the host's file
with `publicKey` and `sopsFile` pointing at the shared files.

## Verify

On mini and k (darwin). On k there is no `op-sa-token`; the secret is
`/run/secrets/git-signing-key`.

```sh
sudo launchctl print system/org.nixos.git-signing-agent | grep -E '^\s+(state|pid) ='
tail -3 /var/log/git-signing-agent.log        # … signing key loaded: 256 SHA256:… (ED25519)
cat /run/secrets/op-sa-token                  # must fail: Permission denied
git config --show-origin gpg.ssh.program      # file:/etc/git/host.inc …/git-signing-keygen
osascript -e 'quit app "1Password"'           # prove 1Password isn't involved
cd "$(mktemp -d)" && git init -q && git commit -q --allow-empty -m test \
  && git log -1 --format='%G? %GK'            # G SHA256:jT1EvkkbjWfjMQHKdiytb0pET1Xvs2g9DuPHIER+Hvs
```

On nebula:

```sh
systemctl is-active git-signing-agent         # active
journalctl -u git-signing-agent -n 3          # … signing key loaded: 256 SHA256:… (ED25519)
cat /run/secrets/git-signing-key              # must fail: Permission denied
git config --show-origin gpg.ssh.program      # file:/etc/git/host.inc …/git-signing-keygen
cd "$(mktemp -d)" && git init -q && git commit -q --allow-empty -m test \
  && git log -1 --format='%G? %GK'            # G SHA256:jT1EvkkbjWfjMQHKdiytb0pET1Xvs2g9DuPHIER+Hvs
```

Then push a real commit and check that GitHub shows **Verified**. On a host
without the agent (the work Mac), `git config --show-origin gpg.ssh.program`
should still point at `op-ssh-sign`.

## Rotate

- **Token (mini only):** rotate the token in the 1Password web console,
  under Developer → Service Accounts (`op` can't rotate). Paste the new
  token over "mini-automation token" using the copy button, not a terminal
  selection, which has truncated tokens before
  ([rotate-op-sa-token](rotate-op-sa-token.md)). Re-run setup step 3's
  block (it's safe to re-run), commit `secrets.yaml`, `nrs` on mini, then
  `sudo launchctl kickstart -k system/org.nixos.git-signing-agent`. The
  plist doesn't change, so `nrs` alone won't reload the daemon.
- **Key (all three hosts):** generate a new SSH Key item in
  `mini-automation`, and point `opItem` and the two blocks above at it if
  its title changed. Re-run setup step 3's block, which rewrites
  `git-signing.pub`; replace the old line in `allowed_signers`; then
  re-run the sops block. On GitHub, add the new signing key and delete the
  old one. Commit, and `nrs` on every host: the changed public key reloads
  each daemon. Commits GitHub has already verified stay verified.

## Revoke

Remove the signing key on GitHub and its line in `allowed_signers`. That
ends trust in the key everywhere at once. Then take it away from the hosts:

- **mini:** delete the `mini-automation` service account in the web
  console. The key stays in the running agent's memory until a restart, so
  cut it off now with
  `sudo launchctl kickstart -k system/org.nixos.git-signing-agent`. The
  reload then fails and the agent stays empty. To turn it off permanently,
  set `enable = false` and `nrs`.
- **k and nebula:** `git rm modules/hosts/git-signing.yaml`, commit, and
  `nrs` on each. The agent is disabled and commits sign through
  `op-ssh-sign` again. The file's history still holds the encrypted key,
  so a key that may have leaked must be revoked as above, not only removed.

## Troubleshooting

Setup step 3 on k: `error loading config: no matching creation rules found`
means `.sops.yaml` has no rule for that file in that checkout yet →
`git pull`, then re-run the block.

Commits on k or nebula still ask 1Password: the agent is off because
`git-signing.yaml` isn't tracked in that checkout (`git ls-files
modules/hosts/git-signing.yaml`), or the host hasn't switched since it
arrived.

The rest are in `/var/log/git-signing-agent.log` (darwin) or
`journalctl -u git-signing-agent` (nebula):

| Log line | Cause → fix |
|---|---|
| `waiting for /run/secrets/…` | sops hasn't decrypted it. Check the file was encrypted to this host's recipient and committed, then `sudo launchctl print system/org.nixos.sops-install-secrets`. |
| `could not load … [ERROR] … token` | Token wrong, expired, or truncated → re-bank it and re-run setup step 3's block. |
| `could not load … isn't a vault/item` | `opItem` doesn't match the vault/item names, or the service account can't see the vault (`op vault list` with its token). |
| `… is not the configured publicKey` | `git-signing.pub` and the secret differ → re-run setup step 3's block, then the sops block. |
| commit: `no signing key in the agent` | The daemon hasn't loaded yet (network or sops at boot) or has failed → read the log. |
| `nrs` on nebula reports a failed unit | `git-signing-agent.service` couldn't load the key; the journal says why. Fix the secret and run `nrs` again. |
| GitHub says Unverified | Added as an authentication key, not a signing key, or the commit email isn't on the account. |

[^op-service-account-cli]: `op service-account create <name> --vault <vault>:read_items [--expires-in 90d] --raw`; Private/Personal vaults can't be granted.
[^op-secret-reference-syntax]: `op://vault/item/field`; `?ssh-format=openssh` on the private key field returns the OpenSSH format `ssh-add` reads.
[^github-signing-key]: GitHub docs on SSH signing keys and `gpg.format ssh`.
[^sops-nix]: sops encrypts to the recipients named by the matching `.sops.yaml` creation rule; sops-nix checks at build time that each declared key exists in its file.
