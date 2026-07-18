---
type: Playbook
title: Rotate the nebula-gh Service-Account Token
description: ~90-day rotation of the 1Password service-account token behind the gh wrapper's prompt-free op read — web-UI rotate, re-bank, sops re-set, rebuild, verify.
tags: [secrets, 1password]
timestamp: '2026-07-18T23:55:00+00:00'
---

Current token expires **2026-10-18** (1Password alert Oct 11). Background:
[op-service-account-token](../decisions/op-service-account-token.md);
consumer: [gh-op](../packages/gh-op.md). Rotation cannot be done via `op`
CLI — service accounts there support only `create`/`ratelimit`.

## Examples

1. **Rotate**: 1password.com → Developer → Service Accounts → `nebula-gh` →
   rotate token (issues a new one; the old token can be given a short
   expiry for overlap, though the gh wrapper's fallback to interactive auth
   makes a hard cutover harmless here).
2. **Re-bank**: paste the new token over the `credential` field of the
   "Service Account Auth Token: nebula-gh" item (Automation vault). Use the
   **copy button** — selecting the token text in a terminal truncated it the
   first time (818 of 852 chars; symptom: `DecodeSACredentials … unexpected
   end of JSON input`).
3. **Update sops** — token and age key piped in-memory, nothing printed
   (the item name's `:` is illegal in `op://` refs, hence the ID lookup):

   ```sh
   cd ~/src/dotfiles
   tokid=$(op item get "Service Account Auth Token: nebula-gh" --format json | jq -r .id)
   tok=$(op read "op://Automation/$tokid/credential")
   export SOPS_AGE_KEY=$(op item get "nebula sops-age key" --format json --reveal \
     | jq -r '.fields[] | select(.label=="keys.txt").value' \
     | grep -o 'AGE-SECRET-KEY-[A-Z0-9]*')
   sops set modules/hosts/nebula/secrets.yaml '["op-sa-token"]' "\"$tok\""
   ```

4. **Deploy**: rebuild per [rebuild-and-rollback](rebuild-and-rollback.md)
   (`sudo nixos-rebuild switch --flake .#nebula` from the real checkout).
5. **Verify** (proves the SA path specifically, then end to end):

   ```sh
   OP_SERVICE_ACCOUNT_TOKEN=$(cat /run/secrets/op-sa-token) \
     op whoami   # User Type: SERVICE_ACCOUNT
   env -u GH_TOKEN gh api user -q .login   # kriswill, no 1Password prompt
   ```

6. **Reset the clock**: set the next expiry/alert on the new token if the
   web UI didn't carry it over, and update the expiry date at the top of
   this playbook and in [gh-op](../packages/gh-op.md).

## Citations

- [Manage service accounts](https://developer.1password.com/docs/service-accounts/manage-service-accounts/)
