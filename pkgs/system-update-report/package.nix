{
  writeShellApplication,
  bun,
  nvd,
  git,
}:
# HTML report of what changed between two system generations: `nvd diff`
# (booted vs current on NixOS; previous vs current profile generation on
# darwin, which has no /run/booted-system) plus the latest commit touching
# flake.lock in the dotfiles repo, its `• Updated/Added/Removed input` blocks
# parsed into a flake-input from/to table.
#
#   system-update-report [-o out.html] [--repo DIR] [FROM] [TO]
#
# Defaults: out = ~/Documents/system-update-<host>-<date>.html,
# repo = $DOTFILES or ~/src/dotfiles. Themed with the html-doc skill's theme
# asset, read from its git-tracked home in the stow tree (single source).
let
  theme = ../../home/agents/.agents/skills/html-doc/assets/theme.html;
in
writeShellApplication {
  name = "system-update-report";
  runtimeInputs = [
    bun
    nvd
    git
  ];
  text = ''THEME_HTML=${theme} exec bun run ${./main.ts} "$@"'';
}
