# Mini agent credential review

Mini access checks were performed on **2026-11-13**, generation **29**;
repository state was reconciled on **2026-11-14** through `85e3e8e4`.
This is an access review and proposal for the next experiment, not a settled
fleet rollout policy.
The separate `mini-automation` vault is intentional for Mini/Hermes;
preferring shared `Automation` does not grant Hermes that access.

## Current authority and evidence

| Machine / principal | Intended vault | Credential or interface | Direct operations | Delegated operations | Evidence / limit |
| --- | --- | --- | --- | --- | --- |
| Mini root signing loader | mini-automation | Root-only SOPS `op-sa-token` | Fetch the designated private signing key and load the in-memory agent | k processes request signatures through its socket | Boot fetch succeeded; generation-29 signature verified. k cannot read the root token or private key. |
| Mini Codex / Core as k | Automation is a desired machine-automation source; no new grant made | Host Git signer, machine SSH file; existing gh credential in `~/.config/gh/hosts.yml` | Sign; SSH; existing GitHub operations | Core runs local commands and reaches configured peers | Signed checkpoint push, fresh SSH to k/nebula and gh auth metadata succeeded. No separate Mini Automation token is provisioned here. |
| Mini Hermes, direct sandbox | mini-automation boundary retained; general item reads not provisioned | Private Hermes HOME, provider auth file, allowed checkout paths | Agent state and opted-in checkouts | Explicit Core socket exception grants commands as k outside Seatbelt, including host signing/SSH and access to k's credentials | Sandbox → Core → host Git configuration succeeded. Provider/GUI readiness and direct vault retrieval were not tested. Core authority exceeds the intended vault boundary. |
| nebula user k / agents | Automation | Existing `nebula-gh` token, SOPS owner k; gh-op wrapper; separate root-loaded SOPS signing agent | Fetch GitHub CLI token; request signatures; token scope exceeds that one wrapper operation | Host user / remote-command authority | Incoming signing record reports live generation-236 verification. Current vault-token validity and complete grants were not revalidated in this Mini follow-up. |
| k laptop user / agents | Automation preferred for future machine automation | Root-loaded SOPS signing agent; managed-peer machine SSH; interactive 1Password remains available | Request signatures; SSH; existing laptop workflows | Its own Core/user authority | Incoming signing record reports live generation-291 verification. No general Automation token was provisioned by this Mini work; k's separate sessions own its deployment. |
| SOC-Kris-Williams | No new agent-vault policy specified | Existing work-Mac interactive setup | Existing desktop workflows | Not examined live | Configuration evaluates; deployment/reboot and credential readiness unverified while offline. |

Requesting a signature is not reading the signing key or root token.
Sharing a vault need not mean sharing a service-account credential: each
machine could have an independently revocable account for the same vault.
Each account would still receive its configured vault scope. In the separately
approved [shared signing-key decision](../knowledge/decisions/git-signing-key-in-sops.md),
k and nebula now load the same signing key from their root-only SOPS secret.
Mini still fetches it from `mini-automation`. This shares signing authority,
not the Mini service-account token or general vault access; the live k/nebula
verification above comes from the incoming repository record, not new tests
performed from Mini.

## Metadata inspection

Authorized `op vault list` and `op item list` checks returned these IDs.
Only metadata was displayed; no credential values were revealed or copied.
This used the current account session, not unattended agent authentication.

| Vault | Vault ID | Current items (title / ID) |
| --- | --- | --- |
| mini-automation | `uau5k3ce56264zv7vivr5iri2y` | mini git signing key / `tbvmr5q367xnkkdf6iwx5xb3cu` |
| Automation | `oy5ldthjpvjn3aetqjxghujmty` | GitHub gh CLI token / `2kkkujvk57tt5yxwhrhan2ccsq`; Service Account Auth Token: nebula-gh / `goydru2rejzh6ooafdvhcwpp7i` |

Mini's checked-in SOPS secrets remain its root signing token and user SSH
key. No new token was created. The installed `op service-account` offers
`create` and `ratelimit`, not account enumeration; item metadata does not
prove that no other account exists in the developer console.

- `mini-automation` currently contains the private signing key. Raw vault
  read access for Hermes would defeat its signature-only boundary. Keep
  mediated signing; do not hand it the loader's token.
- `Automation` contains nebula's service-account token as well as the
  GitHub credential. A new vault-wide read account could read both. A
  wrapper requesting one item does not narrow a token readable by the same
  user. No item relocation or vault editing was authorized or performed.

## Decision before broader access

Hermes's `HC_SOCKET` reaches Core as k. Delegated commands run outside
Seatbelt, so k-readable Automation credentials introduced for Codex would
also be reachable through Hermes. This includes k's existing GitHub
authentication: `gh auth status` reports a working account sourced from
`~/.config/gh/hosts.yml`, and the checkpoint push succeeded. The Hermes
check read only Git configuration; no credential was extracted. The wider
authority follows from Core's configured delegation.

The decision is whether to retain full delegation and defer new Automation
access, or replace Hermes's arbitrary Core access with a restricted
interface before giving Codex broader credentials. Different environment
variables, wrapper names or token filenames under one UID do not enforce
agent separation. A broker must restrict callers and operations; arbitrary
local or remote shell delegation would recreate the broader access.

If the latter experiment is selected, the concrete proposal is:

1. Confirm or create a **distinct Mini machine service account** with
   `Automation:read_items`, no write/share/vault-creation grants, and an
   explicitly chosen expiry. Do not copy `nebula-gh`. Permissions are
   selected at account creation. [1Password service-account setup](https://developer.1password.com/docs/service-accounts/get-started/).
2. Encrypt its token separately as `op-automation-token` in
   `modules/hosts/mini/automation.yaml`, using Mini's existing public SOPS
   recipient. Deploy **root-only 0400** at `/run/secrets/op-automation-token`;
   leave the signing `op-sa-token` untouched.
3. Have the restricted broker retrieve only the requested secret, initially
   `op://oy5ldthjpvjn3aetqjxghujmty/2kkkujvk57tt5yxwhrhan2ccsq/credential`.
   Define approved GitHub operations and the caller boundary before exposing
   it to Codex. Keep Hermes on reviewed signing/SSH/desktop functions;
   raw signing-key and service-account-token reads remain unavailable.
4. Missing/expired credentials must fail explicitly without desktop `op`
   fallback. Verify signing, SSH and a harmless authorized GitHub read with
   the desktop locked during a separate test.

These are proposed paths and grants, **not deployed configuration**. No new
consumer, account, vault grant or cross-machine token copy was introduced.
k's separate session must coordinate any later laptop rollout.

Related: [headless signing](../knowledge/decisions/headless-git-signing-agent.md),
[machine SSH](../knowledge/decisions/headless-machine-ssh.md),
[Hermes authority](../knowledge/modules/mini-hermes-agent.md),
[boot evidence](shell-startup-performance.md#mini-cold-boot-and-credential-readiness-2026-11-13-generation-28).
