# shellcheck shell=bash
# Body of nixploit-report-graph. Loaded verbatim by nixploit.nix via
# builtins.readFile into writeShellApplication (which prepends the shebang and
# the runtimeInputs PATH, and runs shellcheck at build time). No Nix
# interpolation lives here, so it runs standalone too:
#
#   bash modules/hosts/nebula/nixploit-report-graph.sh > graph.json
#
# Prints the running system's reference graph as JSON for the report viewer
# (modules/hosts/nebula/nixploit-report.html): every store path in
# /run/current-system's closure, the indices of the paths each one references,
# and, per system generation, which of those paths it also holds:
#
#   {"current": "<toplevel>", "booted": "<toplevel>", "nodes": ["<hash>-<name>", ...],
#    "refs": [[i, ...], ...], "generations": [{"n", "date", "top", "has": "0110..."}]}
#
# Runs unprivileged (the nixploit service user): path-info and --requisites go
# through the daemon, and the profile links are world-readable.
set -euo pipefail

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

current=$(readlink -f /run/current-system)
booted=$(readlink -f /run/booted-system)
nix path-info --recursive --json --json-format 2 "$current" >"$work/closure.json"

: >"$work/generations.jsonl"
for link in /nix/var/nix/profiles/system-*-link; do
  [ -e "$link" ] || continue
  n=${link##*/system-}
  n=${n%-link}
  top=$(readlink -f "$link")
  nix-store --query --requisites "$link" | sed 's|^/nix/store/||' |
    jq -cRn --argjson n "$n" --argjson date "$(stat -c %Y "$link")" --arg top "${top#/nix/store/}" \
      '{n: $n, date: $date, top: $top, paths: [inputs]}' >>"$work/generations.jsonl"
done

jq -c --slurpfile gens "$work/generations.jsonl" \
  --arg current "${current#/nix/store/}" --arg booted "${booted#/nix/store/}" '
  .info as $info
  | ($info | keys_unsorted) as $nodes
  | (reduce range(0; $nodes | length) as $i ({}; .[$nodes[$i]] = $i)) as $idx
  | {
      current: $current,
      booted: $booted,
      nodes: $nodes,
      refs: [$nodes[] | [$info[.].references[] | $idx[.] // empty]],
      generations: [$gens[] | INDEX(.paths[]; .) as $set
        | {n, date, top, has: ([$nodes[] | if $set[.] then "1" else "0" end] | join(""))}]
    }' "$work/closure.json"
