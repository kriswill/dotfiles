---
type: Playbook
title: Set Up, Rotate, and Revoke mini's Headless Git Signing
description: 'One-time 1Password, GitHub, and repo steps that turn on services.git-signing-agent on mini, then how to verify it, rotate the token or key, and revoke it.'
tags: [git, 1password, secrets]
generated: { by: claude-code/opus-5.5, at: 2026-11-05T12:45:00-08:00 }
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
---

Background: [headless-git-signing-agent](../decisions/headless-git-signing-agent.md).
Module: [git-signing-agent](../modules/git-signing-agent.md). Host:
[mini](../hosts/mini.md). The rendered walkthrough (an HTML artifact) has
the same steps.

## Setup

Run steps 1–4 on a machine with the 1Password desktop app unlocked, CLI
integration on, and a checkout of this repo that includes the module
(k works). Run them from the repo root inside the dev shell, which
provides `sops` and `jq`.

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
   encrypt the token to mini.[^op-secret-reference-syntax] This needs only mini's public age recipient,
   which is already in `.sops.yaml`.

   ```sh
   op read "op://mini-automation/mini git signing key/public key" > modules/hosts/mini/git-signing.pub
   { echo "# mini: headless git-signing-agent key (modules/hosts/mini/git-signing.pub)"
     printf '115474+kriswill@users.noreply.github.com %s\n' "$(cut -d' ' -f1,2 modules/hosts/mini/git-signing.pub)"
   } >> home/git/.config/git/allowed_signers
   printf 'op-sa-token: "%s"\n' "$(op read 'op://Private/mini-automation token/credential')" \
     | sops encrypt --filename-override modules/hosts/mini/secrets.yaml \
         --input-type yaml --output-type yaml /dev/stdin > modules/hosts/mini/secrets.yaml
   ```

   Then set `services.git-signing-agent.enable = true;` in
   `modules/hosts/mini/default.nix`, run
   `git add modules/hosts/mini/git-signing.pub modules/hosts/mini/secrets.yaml`
   (flakes only see tracked files), and commit and push.

4. **GitHub signing key.** Add `git-signing.pub` as a **Signing Key**: in
   the web UI, Settings → SSH and GPG keys → New SSH key → Key type:
   Signing Key.[^github-signing-key] An authentication key never makes
   commits Verified. Or with gh:

   ```sh
   gh auth refresh -h github.com -s admin:ssh_signing_key
   gh ssh-key add modules/hosts/mini/git-signing.pub --type signing --title "mini (git-signing-agent)"
   ```

5. **Deploy on mini:** `git pull`, then `nrs`. sudo asks for a password
   over ssh.

## Verify (on mini)

```sh
sudo launchctl print system/org.nixos.git-signing-agent | grep -E '^\s+(state|pid) ='
tail -3 /var/log/git-signing-agent.log        # … signing key loaded: 256 SHA256:… (ED25519)
cat /run/secrets/op-sa-token                  # must fail: Permission denied
git config --show-origin gpg.ssh.program      # file:/etc/git/host.inc …/git-signing-keygen
osascript -e 'quit app "1Password"'           # prove 1Password isn't involved
cd "$(mktemp -d)" && git init -q && git commit -q --allow-empty -m test \
  && git log -1 --format='%G? %GK'            # G SHA256:… (mini's key)
```

Then push a real commit and check that GitHub shows **Verified**. On k,
`git config --show-origin gpg.ssh.program` should still point at
`op-ssh-sign`.

## Rotate

- **Token:** rotate the token in the 1Password web console, under
  Developer → Service Accounts (`op` can't rotate). Paste the new token
  over "mini-automation token" using the copy button, not a terminal
  selection, which has truncated tokens before
  ([rotate-op-sa-token](rotate-op-sa-token.md)). Re-run the `sops encrypt`
  line from step 3, commit, `nrs` on mini, then
  `sudo launchctl kickstart -k system/org.nixos.git-signing-agent`. The
  plist doesn't change, so `nrs` alone won't reload the daemon.
- **Key:** generate a new SSH Key item in `mini-automation`. Rewrite
  `git-signing.pub` and replace the mini line in `allowed_signers`. On
  GitHub, add the new signing key and delete the old one. Then `nrs` on
  mini; the changed public key reloads the daemon. Commits GitHub has
  already verified stay verified.

## Revoke

Delete the `mini-automation` service account in the web console and
remove the signing key on GitHub. The key stays in the running agent's
memory until a restart, so cut it off now with
`sudo launchctl kickstart -k system/org.nixos.git-signing-agent`. The
reload then fails and the agent stays empty. To turn it off permanently,
set `enable = false` and `nrs`.

## Troubleshooting

All in `/var/log/git-signing-agent.log`:

| Log line | Cause → fix |
|---|---|
| `waiting for /run/secrets/op-sa-token` | sops hasn't decrypted it. Check `secrets.yaml` was encrypted to `&mini` and committed, then `sudo launchctl print system/org.nixos.sops-install-secrets`. |
| `could not load … [ERROR] … token` | Token wrong, expired, or truncated → re-bank it and re-run step 3's `sops encrypt`. |
| `could not load … isn't a vault/item` | `opItem` doesn't match the vault/item names, or the service account can't see the vault (`op vault list` with its token). |
| `… is not the configured publicKey` | `git-signing.pub` and the 1Password item differ → re-run step 3's `op read … public key`. |
| commit: `no signing key in the agent` | The daemon hasn't loaded yet (network or sops at boot) or has failed → read the log. |
| GitHub says Unverified | Added as an authentication key, not a signing key, or the commit email isn't on the account. |

[^op-service-account-cli]: `op service-account create <name> --vault <vault>:read_items [--expires-in 90d] --raw`; Private/Personal vaults can't be granted.
[^op-secret-reference-syntax]: `op://vault/item/field`; the loader adds `?ssh-format=openssh` to the private key field.
[^github-signing-key]: GitHub docs on SSH signing keys and `gpg.format ssh`.
