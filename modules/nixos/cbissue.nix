{
  flake.modules.nixos.cbissue =
    # Global CLIs for Codeberg (Forgejo) issue tracking:
    #   cbissue  kriswill/foo "title" "body" -l bug -l "help wanted"   # open an issue
    #   cbissues kriswill/foo [--state open|closed|all] [--plain]      # browse/filter issues
    #
    # The derivations live in pkgs/cbissue.nix and pkgs/cbissues.nix
    # (exposed as pkgs.cbissue / pkgs.cbissues via the my-packages overlay). They
    # install only the commands; the Codeberg API token is fetched at call time
    # from 1Password (`op read`), so nothing secret is stored in the store or this
    # config. The 1Password CLI must be on PATH and unlocked — the same agent that
    # signs commits and backs the codeberg git credential helper. Override the
    # token's 1Password reference per call with $CBISSUE_TOKEN_REF.
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.cbissue
        pkgs.cbissues
      ];
    }

  ;
}
