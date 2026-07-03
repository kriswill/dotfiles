# cbissues — browse/filter a Codeberg (Forgejo) repo's issues (fzf TUI + --plain).
# The implementation lives in ./cbissues.sh (plain bash); this just wraps it with
# pinned runtime deps and ShellCheck. `op` is resolved from the ambient PATH (only
# needed for private repos); the token reference defaults inside the script and is
# overridable via $CBISSUE_TOKEN_REF.
{
  writeShellApplication,
  curl,
  jq,
  fzf,
  git,
  xdg-utils,
  util-linux,
  coreutils,
}:
writeShellApplication {
  name = "cbissues";
  runtimeInputs = [
    curl
    jq
    fzf
    git
    xdg-utils
    util-linux
    coreutils
  ];
  text = builtins.readFile ./cbissues.sh;
}
