# Kris' yazi (system-level port of the old home-manager module).
#
# nix-darwin has no `programs.yazi`, so this module installs the binary and
# wires the config the way the rest of the repo does:
#
#  * Static config — yazi.toml, theme.toml, init.lua and the user's own
#    `font-dark` previewer plugin — lives in the stow tree
#    (home/yazi/.config/yazi/…) and is symlinked into ~ by dotfiles-stow.nix
#    (the live, editable repo copy rather than a /nix/store snapshot).
#  * The third-party plugins (git, faster-piper, and the types.yazi LuaCATS
#    stubs) and the generated kanagawa-dragon flavor all resolve to /nix/store
#    paths only Nix knows — so, exactly like tmux's plugins.conf, they can't be
#    static stow symlinks. We link them under ~/.config/yazi/{plugins,flavors}
#    during activation instead. Plugin dirs follow yazi's `<name>.yazi`
#    naming; yazi.toml refers to them without the suffix (`git`, `faster-piper`,
#    `font-dark`).
#  * The `y` shell wrapper (cd into yazi's last dir on quit) is hand-defined in
#    the stow zshrc (home/zsh/.config/zsh/.zshrc), independent of any shell
#    integration, so nothing is generated here for it.
{
  flake.modules.darwin.yazi =
    {
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      # kanagawa-dragon flavor (flavor.toml + tmtheme.xml) generated from the
      # shared lib.kanagawa palette — see ./_themes/kanagawa-dragon. `lib` here
      # is the repo-extended lib carrying `kanagawa` (darwin specialArgs).
      flavor = import ./_themes/kanagawa-dragon { inherit lib pkgs; };
    in
    {
      # yazi itself, plus `magick` (ImageMagick 7) required by the font
      # previewer. glow (md previews, from core.nix) and bat (code previews)
      # are already on PATH; the previewer invokes them by bare name.
      environment.systemPackages = builtins.attrValues {
        inherit (pkgs) yazi imagemagick;
      };

      # Order 1600: after dotfiles-stow (1500) has populated ~/.config/yazi
      # (the static files + the font-dark plugin dir). Run as the user so the
      # dirs/links aren't root-owned; `ln -sfn` replaces any stale link so the
      # store paths track rebuilds.
      system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
        /usr/bin/sudo -u k --set-home /bin/sh -c '
          mkdir -p /Users/k/.config/yazi/plugins /Users/k/.config/yazi/flavors
          ln -sfn ${pkgs.yaziPlugins.git} /Users/k/.config/yazi/plugins/git.yazi
          ln -sfn ${inputs.faster-piper-yazi} /Users/k/.config/yazi/plugins/faster-piper.yazi
          ln -sfn ${inputs.yazi-plugins}/types.yazi /Users/k/.config/yazi/plugins/types.yazi
          ln -sfn ${flavor} /Users/k/.config/yazi/flavors/kanagawa-dragon.yazi
        '
      '';
    };
}
