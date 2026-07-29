#!/usr/bin/env bash
# ci-watch.sh <pr-number> [--interval S] [--repo OWNER/REPO]
#
# Streams one PR's checks as events. Records the ARMED head SHA up front,
# polls `gh pr checks --json name,bucket` (default 30s), emits each check
# ONCE as it settles, and — the load-bearing part — if the head SHA changes
# mid-watch it declares every settled verdict VOID and re-arms on the new
# SHA: a fresh push resets checks, and reusing a verdict from a superseded
# SHA is the exact race that nearly shipped in a live mission.
#
# Exits when all checks settle: 0 all pass/skip (prints the merge-pr.sh
# invocation for the settled SHA), 1 any fail/cancel, 2 usage/gh error.
set -u

self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

if [ "${1:-}" = "--self-test" ]; then
  fail=0
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  export CI_WATCH_MOCK_STATE="$tmp/calls"
  # Scenario 1: head SHA changes between arm and first poll; checks settle
  # green on the new SHA. Expect VOID + re-arm + once-emitted check + rc 0.
  cat > "$tmp/gh" <<'MOCK'
#!/usr/bin/env bash
n=0; [ -f "$CI_WATCH_MOCK_STATE" ] && n="$(cat "$CI_WATCH_MOCK_STATE")"
case "$*" in
  *"pr view"*)
    n=$((n+1)); echo "$n" > "$CI_WATCH_MOCK_STATE"
    if [ "$n" -le 1 ]; then echo "aaaa111aaaa111aaaa"; else echo "bbbb222bbbb222bbbb"; fi ;;
  *"pr checks"*)
    if [ "$n" -le 1 ]; then printf 'pending\tbuild\n'; else printf 'pass\tbuild\n'; fi ;;
esac
MOCK
  chmod +x "$tmp/gh"
  out="$(PATH="$tmp:$PATH" "$self" 99 --interval 1)"; rc=$?
  printf '%s\n' "$out" | grep -q 'SHA CHANGED' || { echo "self-test: FAIL no VOID on SHA change"; fail=1; }
  printf '%s\n' "$out" | grep -q 'build -> pass' || { echo "self-test: FAIL check not emitted"; fail=1; }
  printf '%s\n' "$out" | grep -q 'ALL SETTLED' || { echo "self-test: FAIL no settle line"; fail=1; }
  [ "$rc" = 0 ] || { echo "self-test: FAIL green run rc=$rc (want 0)"; fail=1; }
  # Scenario 2: a failing check. Expect rc 1 and the failure emitted.
  cat > "$tmp/gh" <<'MOCK'
#!/usr/bin/env bash
case "$*" in
  *"pr view"*) echo "cccc333cccc333cccc" ;;
  *"pr checks"*) printf 'fail\ttest\npass\tbuild\n' ;;
esac
MOCK
  out="$(PATH="$tmp:$PATH" "$self" 99 --interval 1)"; rc=$?
  [ "$rc" = 1 ] || { echo "self-test: FAIL red run rc=$rc (want 1)"; fail=1; }
  printf '%s\n' "$out" | grep -q 'test -> fail' || { echo "self-test: FAIL fail check not emitted"; fail=1; }
  [ "$fail" = 0 ] && echo "self-test: OK (mock gh; real PR not exercised)"
  exit "$fail"
fi

pr="${1:?usage: ci-watch.sh <pr> [--interval S] [--repo OWNER/REPO]}"
shift
interval=30
repo_args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --interval) interval="${2:?--interval needs seconds}"; shift 2 ;;
    --repo) repo_args=(-R "${2:?--repo needs OWNER/REPO}"); shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

now() { date +%H:%M; }
head_sha() {
  gh pr view "$pr" ${repo_args[@]:+"${repo_args[@]}"} --json headRefOid --jq .headRefOid 2>/dev/null
}

armed="$(head_sha)"
[ -n "$armed" ] || { echo "ci-watch.sh: cannot read PR #$pr head SHA (gh auth? --repo?)" >&2; exit 2; }
echo "[$(now)] ci-watch PR#$pr: armed on ${armed:0:9}"

seen="|"
noted_empty=0
while :; do
  cur="$(head_sha)"
  if [ -n "$cur" ] && [ "$cur" != "$armed" ]; then
    echo "[$(now)] ci-watch PR#$pr: *** SHA CHANGED *** ${armed:0:9} -> ${cur:0:9} - settled verdicts on ${armed:0:9} are VOID; re-armed"
    armed="$cur"; seen="|"
  fi
  checks="$(gh pr checks "$pr" ${repo_args[@]:+"${repo_args[@]}"} --json name,bucket \
    --jq '.[] | .bucket + "\t" + .name' 2>/dev/null || true)"
  if [ -z "$checks" ]; then
    if [ "$noted_empty" = 0 ]; then
      echo "[$(now)] ci-watch PR#$pr: no checks reported yet (CI may not have started)"
      noted_empty=1
    fi
  else
    pending=0; passed=0; failed=0; skipped=0
    while IFS=$'\t' read -r bucket cname; do
      [ -n "$bucket" ] || continue
      case "$bucket" in
        pending) pending=$((pending+1)); continue ;;
        pass) passed=$((passed+1)) ;;
        fail|cancel) failed=$((failed+1)) ;;
        *) skipped=$((skipped+1)) ;;
      esac
      case "$seen" in
        *"|$cname|"*) ;;
        *) echo "[$(now)] ci-watch PR#$pr: $cname -> $bucket"; seen="$seen$cname|" ;;
      esac
    done <<<"$checks"
    if [ "$pending" -eq 0 ]; then
      if [ "$failed" -eq 0 ]; then
        echo "[$(now)] ci-watch PR#$pr: ALL SETTLED on ${armed:0:9} - $passed pass, $skipped skipped. merge path (policy-gated): merge-pr.sh $pr $armed --policy \$SCRATCH/mission-policy"
        exit 0
      fi
      echo "[$(now)] ci-watch PR#$pr: ALL SETTLED on ${armed:0:9} - $failed FAILED, $passed pass. Job log: gh api .../jobs/<id>/logs, grep '##\[error\]' (the real error is near the end; naive greps match test names containing 'fail')"
      exit 1
    fi
  fi
  sleep "$interval"
done
