#!/usr/bin/env bash
# merge-pr.sh <pr-number> <watched-sha> [--repo OWNER/REPO]
#
# The coordinator's only sanctioned merge path. Requires the head SHA whose
# checks you actually watched (ci-watch.sh prints it beside its green
# verdict) and REFUSES (exit 3) if the PR head has moved — a teammate
# pushing between your check and your merge silently voids the verdict
# (this race happened in a live mission; branch protection caught it, but
# the backstop is not the plan). On match it arms `gh pr merge --merge
# --auto`, closing the remaining race window server-side.
#
# <watched-sha> may be abbreviated but must be >= 7 chars (prefix-matched).
# Exit codes: 0 merge armed, 2 usage/gh error, 3 SHA mismatch (re-watch).
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
  PATH="$tmp:$PATH" "$self" 7 deadbeef >/dev/null 2>&1; rc=$?
  [ "$rc" = 3 ] || { echo "self-test: FAIL sha-mismatch rc=$rc (want 3: refuse)"; fail=1; }
  PATH="$tmp:$PATH" "$self" 7 abc123d >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] || { echo "self-test: FAIL sha-match rc=$rc (want 0)"; fail=1; }
  PATH="$tmp:$PATH" "$self" 7 abc >/dev/null 2>&1; rc=$?
  [ "$rc" = 2 ] || { echo "self-test: FAIL short-sha rc=$rc (want 2: ambiguous prefix rejected)"; fail=1; }
  [ "$fail" = 0 ] && echo "self-test: OK (mock gh; real merge not exercised)"
  exit "$fail"
fi

pr="${1:?usage: merge-pr.sh <pr> <watched-sha> [--repo OWNER/REPO]}"
want="${2:?merge-pr.sh: pass the head SHA whose checks you watched (ci-watch.sh prints it)}"
shift 2
repo_args=()
if [ "${1:-}" = "--repo" ]; then repo_args=(-R "${2:?--repo needs OWNER/REPO}"); fi

[ "${#want}" -ge 7 ] \
  || { echo "merge-pr.sh: watched-sha '$want' too short (${#want} chars; >=7 required for an unambiguous prefix)" >&2; exit 2; }

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
