# Wires home-manager into nix-darwin as a darwin module (so every host picks it
# up via `builtins.attrValues config.flake.modules.darwin`). The user's
# home-manager configuration imports every `flake.modules.homeManager.*` module
# accumulated across the tree.
{ config, inputs, ... }:
{
  flake.modules.darwin.home-manager =
    { lib, ... }:
    {
      imports = [ inputs.home-manager.darwinModules.home-manager ];
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "hm.bak";
        # NB: do not pass `lib` here. home-manager derives the user-eval lib
        # from the darwin system's lib (which `modules/darwin.nix` already sets
        # to the extended lib carrying `kanagawa`/`mkProgramOption`) and adds its
        # own `hm` extensions on top. Overriding it would drop `lib.hm.*`.
        extraSpecialArgs = {
          inherit inputs;
          username = "k";
        };
        users.k = {
          imports = builtins.attrValues config.flake.modules.homeManager;
          # The old master `kriswill.enable` home toggle (and the core module it
          # drove) was retired once every feature it carried moved to a
          # system-level darwin module + the stow tree. The remaining
          # home-manager modules (brave/firefox/vscode/podman-desktop/
          # claude-account-selector) are enabled à la carte per host.
          home.username = "k";
          home.stateVersion = "26.05";
          # HM master lags nixpkgs-unstable by a release cycle; silence the
          # mismatch warning until upstream bumps release.json.
          home.enableNixpkgsReleaseCheck = false;
          home.homeDirectory = lib.mkForce "/Users/k";
          manual = {
            html.enable = false;
            json.enable = false;
            manpages.enable = false;
          };
        };
      };
    };
}
