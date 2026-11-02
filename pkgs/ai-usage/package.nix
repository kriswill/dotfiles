{
  writeShellApplication,
  bun,
}:
# ai-usage — what the AI accounts have used: Claude Max's plan limits and
# extra usage (the OAuth usage endpoint behind Claude Code's /usage), the
# Anthropic API's month-to-date cost (Admin API cost_report), and ChatGPT's
# Codex limits (chatgpt.com wham/usage). One Bun script:
#
#   ai-usage [show [--json]] | refresh | once [--force] | daemon | path | config
#
# `daemon` is what the NixOS user service / darwin launchd agent run
# (modules/{nixos,darwin}/ai-usage.nix); it writes
# ~/.cache/ai-usage/usage.json, which the herdr-app `ai-usage` mod draws.
# Accounts: ~/.config/ai-usage/config.json (the `ai-usage` stow package).
#
# `op` is deliberately not a runtime input: the Admin key's `op read` must
# reach the system's setgid, desktop-integrated 1Password CLI on PATH.
writeShellApplication {
  name = "ai-usage";
  runtimeInputs = [ bun ];
  text = ''exec bun run ${./main.ts} "$@"'';
}
