# Log

## 2026-11-05

- **Creation**: [git-signing-agent-setup](git-signing-agent-setup.md): the
  one-time 1Password, GitHub, and repo steps that enable
  [git-signing-agent](../modules/git-signing-agent.md) on mini, plus
  verify, rotate, revoke, and troubleshooting.

## 2026-07-18

- **Creation** — [rotate-op-sa-token](rotate-op-sa-token.md) /
  [gh-op](../packages/gh-op.md) /
  [op-service-account-token](../decisions/op-service-account-token.md): the
  ~90-day rotation procedure for the `nebula-gh` 1Password service-account
  token (web-UI rotate → re-bank with the copy button → in-memory `sops set`
  → rebuild → SA-path verification), extracted from the gh-op doc so the
  concept docs link to it instead of carrying the steps inline. Current
  token expires 2026-10-18.
