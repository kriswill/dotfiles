# shellcheck shell=bash
# Body of nixploit-report. Loaded verbatim by ./report.nix via builtins.readFile
# into writeShellApplication, which also sets $NIXPLOIT_REPORT_TEMPLATE (the
# viewer, ./report.html) and puts nixploit-report-graph on PATH. Standalone:
#
#   NIXPLOIT_REPORT_TEMPLATE=report.html PATH=<graph on PATH>:$PATH bash report.sh <dir>
#
# Renders <dir>/report.html (default /var/lib/nixploit) from <dir>/report.json:
# the viewer with the report, and the system's dependency graph when collecting
# it works, embedded at the template's marker line. Browsers block fetch() from
# a file:// page, so a viewer next to report.json couldn't load it. Escaping
# every `<` keeps the JSON (where `<` only appears inside strings) from closing
# its script tag. The graph is a separate program so its failure only drops the
# analysis: errexit doesn't apply inside an `if` condition. The page is written
# 0640, so the owner's group can read it.
set -euo pipefail

dir=${1:-/var/lib/nixploit}
report=$dir/report.json
template=${NIXPLOIT_REPORT_TEMPLATE:?must point at the viewer template}
[ -e "$report" ] || exit 0

tmp=""
work=$(mktemp -d)
trap 'rm -rf "$work"; rm -f "$tmp"' EXIT
if ! nixploit-report-graph >"$work/graph.json"; then
  echo "nixploit-report: no dependency graph, rendering without it" >&2
  : >"$work/graph.json"
fi

tmp=$(mktemp "$dir/.report.html.XXXXXX")
{
  sed '/@NIXPLOIT_REPORT@/,$d' "$template"
  printf '<script id="report-meta" type="application/json">{"generated":"%s","host":"%s"}</script>\n' \
    "$(date -r "$report" --iso-8601=seconds)" "$(cat /proc/sys/kernel/hostname)"
  printf '<script id="report-data" type="application/json">'
  sed 's/</\\u003c/g' "$report"
  printf '</script>\n'
  if [ -s "$work/graph.json" ]; then
    printf '<script id="report-graph" type="application/json">'
    sed 's/</\\u003c/g' "$work/graph.json"
    printf '</script>\n'
  fi
  sed '1,/@NIXPLOIT_REPORT@/d' "$template"
} >"$tmp"
chmod 0640 "$tmp"
mv -f "$tmp" "$dir/report.html"
