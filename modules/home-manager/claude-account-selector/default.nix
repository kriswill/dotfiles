{
  flake.modules.homeManager.claude-account-selector =
    { lib, config, ... }:
    {
      options.kriswill.claude-account-selector.enable =
        lib.mkEnableOption "Kris' profile-aware claude wrapper (per-project account selection)";
      config = lib.mkIf config.kriswill.claude-account-selector.enable {
        programs.zsh.initContent = lib.mkAfter (builtins.readFile ./wrapper.zsh);
      };
    };
}
