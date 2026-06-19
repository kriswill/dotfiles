#!/usr/bin/env bash
# Toggle zero gaps + square (un-rounded) corners on the CURRENT MONITOR only,
# and disable Noctalia's rounded screen-corner overlay to match.
#
# Gaps (general.gaps_in/out) and decoration.rounding are GLOBAL options in
# Hyprland — there is no per-monitor variant. But each monitor shows exactly one
# workspace at a time, so "current monitor" == the workspace currently DISPLAYED
# on the focused monitor. We scope the change with an hl.workspace_rule on that
# workspace, which reflows existing windows live (layout preserved, windows grow
# into the freed space, corners go square).
#
# IMPORTANT: target the *displayed* workspace, not `hyprctl activeworkspace`.
# When a special/scratchpad workspace is open on the monitor, activeworkspace
# still reports the regular workspace underneath it — so we'd toggle the wrong
# (often empty) workspace. Read the focused monitor and prefer its
# specialWorkspace when one is shown (id != 0), else its activeWorkspace.
#
# SCREEN CORNERS: Noctalia paints a rounded-corner black overlay on the screen
# edges ([shell.screen_corners].enabled). That clips windows even when gaps are
# 0, defeating the edge-to-edge look. Noctalia's screen corners are a GLOBAL
# setting with NO per-monitor option, so we can only flip it for the whole
# shell — we tie it to this toggle: gaps off -> corners off, gaps on -> corners
# on. On a multi-monitor setup this affects every monitor's screen corners, not
# just the one being toggled (the last toggle wins). Edited with `toml-set`
# (format-preserving AST edit; see packages/toml-set.nix) + `noctalia msg
# config-reload` to apply live.
#
# Stateless: read the workspace's current gapsOut and flip it. In 0.55 Lua mode
# `hyprctl keyword` is dead, so changes go through `hyprctl eval`. The restore
# branch hard-codes the defaults from hyprland.lua's LOOK AND FEEL block
# (gaps_in 5 / gaps_out 20 / rounding on) — keep them in sync if those change.
set -eu

settings="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"

ws=$(hyprctl -j monitors | jq -r '
	.[] | select(.focused)
	| if .specialWorkspace.id != 0 then .specialWorkspace.name else .activeWorkspace.name end')

cur=$(hyprctl -j workspacerules | jq -r --arg w "$ws" '([.[] | select(.workspaceString == $w).gapsOut[0]][0]) // 20')

set_screen_corners() {
	# $1 = true|false. Only touch Noctalia if the setting actually changes and
	# the tools are present, so the gaps toggle still works without Noctalia.
	command -v toml-set >/dev/null 2>&1 || return 0
	[ -f "$settings" ] || return 0
	toml-set "$settings" shell.screen_corners.enabled "$1"
	command -v noctalia >/dev/null 2>&1 && noctalia msg config-reload >/dev/null 2>&1 || true
}

if [ "$cur" = "0" ]; then
	# currently zero-gap -> restore gaps, rounding, and screen corners
	hyprctl eval "hl.workspace_rule({ workspace = \"$ws\", gaps_in = 5, gaps_out = 20, no_rounding = false })"
	set_screen_corners true
else
	# add zero-gap + square corners, and drop the screen-corner overlay
	hyprctl eval "hl.workspace_rule({ workspace = \"$ws\", gaps_in = 0, gaps_out = 0, no_rounding = true })"
	set_screen_corners false
fi
