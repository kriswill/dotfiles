#!/usr/bin/env bash
# merge-pr.sh <pr-number> <watched-sha> --policy <mission-policy-file>
#              [--user-approved] [--repo OWNER/REPO]
#
# The coordinator's only sanctioned merge path, and the enforcement point for
# the mission INTEGRATION POLICY (decided with the user at Step 1, written to
# <scratch>/mission-policy). Merging is forbidden by default:
#
#   (no --policy)    REFUSE - no policy declared, no merge, ever
#   no-github        REFUSE - the charter forbids touching GitHub at all
#   push-only        REFUSE - branches may be pushed, but PRs and merges are
#                    the user's, not the mission's
#   prs-user-merge   REFUSE unless --user-approved, which asserts the user
#                    explicitly approved merging THIS PR (their adversarial
#                    review in a separate session happens before that)
#   prs-auto-merge   proceed - the user pre-authorized coordinator merges
#
# This gate exists because a live mission opened PRs and merged to main
# despite a user instruction not to. Never pass --user-approved on your own
# judgment - it is a statement about what the USER said, not about CI.
#
# Requires the head SHA whose checks you actually watched (ci-watch.sh
# prints it beside its green verdict) and REFUSES (exit 3) if the PR head
# has moved — a teammate pushing between your check and your merge silently
# voids the verdict (this race happened; branch protection caught it, but
# the backstop is not the plan). On match it arms `gh pr merge --merge
# --auto`, closing the remaining race window server-side.
#
# <watched-sha> may be abbreviated but must be >= 7 chars (prefix-matched).
# Exit codes: 0 merge armed, 2 usage/gh error, 3 SHA mismatch (re-watch),
# 4 policy refusal (ask the user, or do not merge at all).
set -u

self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

if [ "${1:-}" = "--self-test" ]; then
  fail=0
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  cat > "$tmp/gh" <<'MOCK'
#!/usr/bin/env bash
case "$*" in
  *"pr view"*) echo "abc123def456abc123 CLEAN" ;;
  *"pr merge"*) exit 0 ;;
esac
MOCK
  chmod +x "$tmp/gh"
  echo "prs-auto-merge"  > "$tmp/pol-auto"
  echo "prs-user-merge"  > "$tmp/pol-user"
  echo "push-only"       > "$tmp/pol-push"

  # policy gate: forbidden by default, and at every level below auto-merge
  PATH="$tmp:$PATH" "$self" 7 abc123d >/dev/null 2>&1; rc=$?
  [ "$rc" = 4 ] || { echo "self-test: FAIL no-policy rc=$rc (want 4: refuse)"; fail=1; }
  PATH="$tmp:$PATH" "$self" 7 abc123d --policy "$tmp/pol-push" >/dev/null 2>&1; rc=$?
  [ "$rc" = 4 ] || { echo "self-test: FAIL push-only rc=$rc (want 4: refuse)"; fail=1; }
  PATH="$tmp:$PATH" "$self" 7 abc123d --policy "$tmp/pol-user" >/dev/null 2>&1; rc=$?
  [ "$rc" = 4 ] || { echo "self-test: FAIL user-merge-unapproved rc=$rc (want 4: refuse)"; fail=1; }
  PATH="$tmp:$PATH" "$self" 7 abc123d --policy "$tmp/pol-user" --user-approved >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] || { echo "self-test: FAIL user-merge-approved rc=$rc (want 0)"; fail=1; }

  # SHA gate (under a permitting policy)
  PATH="$tmp:$PATH" "$self" 7 deadbeef --policy "$tmp/pol-auto" >/dev/null 2>&1; rc=$?
  [ "$rc" = 3 ] || { echo "self-test: FAIL sha-mismatch rc=$rc (want 3: refuse)"; fail=1; }
  PATH="$tmp:$PATH" "$self" 7 abc123d --policy "$tmp/pol-auto" >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] || { echo "self-test: FAIL sha-match rc=$rc (want 0)"; fail=1; }
  PATH="$tmp:$PATH" "$self" 7 abc >/dev/null 2>&1; rc=$?
  [ "$rc" = 2 ] || { echo "self-test: FAIL short-sha rc=$rc (want 2: ambiguous prefix rejected)"; fail=1; }
  [ "$fail" = 0 ] && echo "self-test: OK (mock gh; real merge not exercised)"
  exit "$fail"
fi

pr="${1:?usage: merge-pr.sh <pr> <watched-sha> --policy <file> [--user-approved] [--repo OWNER/REPO]}"
want="${2:?merge-pr.sh: pass the head SHA whose checks you watched (ci-watch.sh prints it)}"
shift 2
repo_args=()
policy_file=""
user_approved=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo_args=(-R "${2:?--repo needs OWNER/REPO}"); shift 2 ;;
    --policy) policy_file="${2:?--policy needs the mission-policy file}"; shift 2 ;;
    --user-approved) user_approved=1; shift ;;
    *) echo "merge-pr.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ "${#want}" -ge 7 ] \
  || { echo "merge-pr.sh: watched-sha '$want' too short (${#want} chars; >=7 required for an unambiguous prefix)" >&2; exit 2; }

if [ -z "$policy_file" ]; then
  echo "*** REFUSED *** no integration policy declared - pass --policy <scratch>/mission-policy (written with the user at Step 1); merging is forbidden by default" >&2
  exit 4
fi
policy="$(grep -vE '^[[:space:]]*(#|$)' "$policy_file" 2>/dev/null | head -1 | tr -d '[:space:]')"
case "$policy" in
  prs-auto-merge) ;;
  prs-user-merge)
    if [ "$user_approved" != 1 ]; then
      echo "*** REFUSED *** policy prs-user-merge: each merge needs the user's explicit per-PR approval (their adversarial review may still be pending) - ask the user, then re-run with --user-approved" >&2
      exit 4
    fi ;;
  no-github|push-only)
    echo "*** REFUSED *** policy '$policy' forbids PRs/merges - if a PR exists it already violates the charter; escalate to the user, do not merge" >&2
    exit 4 ;;
  *)
    echo "*** REFUSED *** missing or invalid policy in $policy_file ('${policy:-empty}') - expected no-github|push-only|prs-user-merge|prs-auto-merge" >&2
    exit 4 ;;
esac

info="$(gh pr view "$pr" ${repo_args[@]:+"${repo_args[@]}"} --json headRefOid,mergeStateStatus \
  --jq '.headRefOid + " " + .mergeStateStatus' 2>/dev/null)" || info=""
actual="${info%% *}"; mstate="${info#* }"
[ -n "$actual" ] || { echo "merge-pr.sh: cannot read PR #$pr head (gh auth? --repo?)" >&2; exit 2; }

case "$actual" in
  "$want"*) ;;
  *)
    echo "*** REFUSED *** PR#$pr head is ${actual:0:9}, you watched ${want:0:9} - a push superseded the watched checks; re-run ci-watch.sh $pr and merge the SHA it settles on" >&2
    exit 3 ;;
esac

if gh pr merge "$pr" ${repo_args[@]:+"${repo_args[@]}"} --merge --auto; then
  echo "PR#$pr: auto-merge armed on ${actual:0:9} (mergeStateStatus $mstate)"
else
  echo "merge-pr.sh: gh pr merge failed for PR#$pr (mergeStateStatus $mstate)" >&2
  exit 2
fi
