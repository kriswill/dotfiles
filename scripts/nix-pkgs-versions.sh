#!/usr/bin/env bash
# nix-pkgs-versions — list pname/version for every package this flake
# materialises on the current system (environment.systemPackages +
# home-manager home.packages). Interactive fzf picker by default;
# --list / --json for non-interactive use.
#
# Does NOT cover programs.X.package options that don't reach
# systemPackages/home.packages, nor closure-only transitive deps.

set -euo pipefail

RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
DIM=$'\033[2m'
NC=$'\033[0m'

usage() {
  cat <<EOF
Usage: nix-pkgs-versions [--list|--json] [--host <name>] [--user <name>]

  -l, --list      print colorised table, no fzf
  -j, --json      emit raw JSON from nix eval
      --host N    darwinConfigurations.<N>  (default: \`hostname -s\` if it matches, else k)
      --user N    home-manager.users.<N>    (default: \$USER)
  -h, --help      this message

Source: config.environment.systemPackages + config.home-manager.users.<user>.home.packages
Does not cover programs.X.package options or transitive closure-only deps.
EOF
}

die() { printf '%snix-pkgs-versions:%s %s\n' "$RED" "$NC" "$*" >&2; exit 1; }

mode="fzf"
host=""
user="${USER:-}"

while (($#)); do
  case "$1" in
    -l|--list) mode="list"; shift ;;
    -j|--json) mode="json"; shift ;;
    --host)    host="${2:-}"; shift 2 || die "--host needs a value" ;;
    --user)    user="${2:-}"; shift 2 || die "--user needs a value" ;;
    -h|--help) usage; exit 0 ;;
    *)         die "unknown arg: $1" ;;
  esac
done

command -v nix >/dev/null || die "nix not found in PATH"
command -v jq  >/dev/null || die "jq not found in PATH"
[[ "$mode" != "fzf" ]] || command -v fzf >/dev/null || die "fzf not found (install or use --list)"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

hosts_json="$(nix eval --json .#darwinConfigurations --apply 'cfgs: builtins.attrNames cfgs' 2>/dev/null)" \
  || die "could not enumerate darwinConfigurations"
mapfile -t available_hosts < <(printf '%s' "$hosts_json" | jq -r '.[]')
((${#available_hosts[@]})) || die "no darwinConfigurations defined in this flake"

if [[ -z "$host" ]]; then
  short="$(hostname -s 2>/dev/null || true)"
  for h in "${available_hosts[@]}"; do
    [[ "$h" == "$short" ]] && { host="$h"; break; }
  done
  [[ -n "$host" ]] || host="k"
fi

# Validate host
ok=0
for h in "${available_hosts[@]}"; do [[ "$h" == "$host" ]] && ok=1; done
if ((!ok)); then
  printf '%sUnknown host:%s %s\nAvailable: %s\n' "$RED" "$NC" "$host" "${available_hosts[*]}" >&2
  exit 1
fi

[[ -n "$user" ]] || die "--user not set and \$USER empty"

# Build the --apply expression. Use a Nix `let` to inject host/user names.
apply_expr=$(cat <<NIX
cfg: let
  sys  = cfg.environment.systemPackages or [];
  hmU  = cfg.home-manager.users.${user} or {};
  home = hmU.home.packages or [];
  mk = src: p: {
    pname       = p.pname or p.name or "?";
    version     = p.version or "";
    description = p.meta.description or "";
    source      = src;
  };
in (map (mk "system") sys) ++ (map (mk "home") home)
NIX
)

err_file="$(mktemp)"
trap 'rm -f "$err_file"' EXIT
if ! json="$(nix eval --json ".#darwinConfigurations.${host}.config" --apply "$apply_expr" 2>"$err_file")"; then
  die "nix eval failed:\n$(cat "$err_file")"
fi

if [[ "$mode" == "json" ]]; then
  printf '%s\n' "$json" | jq '.'
  exit 0
fi

# Sorted TSV: pname \t version \t source \t description
tsv="$(printf '%s' "$json" | jq -r '
  sort_by(.pname | ascii_downcase)
  | .[]
  | [.pname, .version, .source, .description] | @tsv')"

# Colorise per-field then column-align. Awk handles ANSI plus alignment via
# `column -t -s` over a delimiter not present in any field — use unit-separator.
US=$'\x1f'
colored="$(printf '%s\n' "$tsv" | awk -v Y="$YELLOW" -v G="$GREEN" -v B="$BLUE" -v D="$DIM" -v N="$NC" -v US="$US" '
  BEGIN { FS="\t" }
  { printf "%s%s%s%s%s%s%s%s%s%s%s%s%s\n", Y,$1,N, US, G,$2,N, US, B,$3,N, US, D $4 N }
')"

table="$(printf '%s\n' "$colored" | column -t -s "$US")"

if [[ "$mode" == "list" ]]; then
  printf '%s\n' "$table"
  exit 0
fi

count="$(printf '%s\n' "$tsv" | wc -l | tr -d ' ')"
header_line=$(printf '%s%d packages%s  (host=%s user=%s)' "$YELLOW" "$count" "$NC" "$host" "$user")

printf '%s\n' "$table" | fzf \
  --ansi \
  --multi \
  --header "$header_line" \
  --prompt "pkg⟫ " \
  --bind "ctrl-j:down,ctrl-k:up" \
  --preview-window "down,5,wrap" \
  --preview 'echo {}' \
  || true
