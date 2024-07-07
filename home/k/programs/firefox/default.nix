{ config, pkgs, ... }:
let
  user_js =
    config.home.homeDirectory + "/src/github/kriswill/dotfiles/home/${config.home.username}/programs/firefox/user.js";
  inherit (pkgs.nur.repos.rycee) firefox-addons;
in
{
  home = {
    file = {
      ".mozilla/firefox/${config.home.username}/user.js".source = config.lib.file.mkOutOfStoreSymlink user_js;
    };
  };
  programs.firefox = {
    enable = true;
    profiles = {
      "${config.home.username}" = {
        id = 0;
        extensions = with firefox-addons; [
          ublock-origin
          onepassword-password-manager
          darkreader
        ];
        search = {
          default = "Searx";
          force = true;
          engines = {
            "Searx" = {
              urls = [
                {
                  template = "https://searx.tiekoetter.com/search";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              definedAliases = [ "@sx" ];
            };
            "Nix Packages" = {
              urls = [
                {
                  template = "https://search.nixos.org/packages";
                  params = [
                    {
                      name = "type";
                      value = "packages";
                    }
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@np" ];
            };
            "Home Manager Options" = {
              urls = [
                {
                  template = "https://mipmip.github.io/home-manager-option-search/";
                  params = [
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@hm" ];
            };
            "NixOS Wiki" = {
              urls = [ { template = "https://nixos.wiki/index.php?search={searchTerms}"; } ];
              iconUpdateURL = "https://nixos.wiki/favicon.png";
              updateInterval = 24 * 60 * 60 * 1000; # every day
              definedAliases = [ "@nw" ];
            };
            "Bing".metaData.hidden = true;
            "Google".metaData.alias = "@g"; # builtin engines only support specifying one additional alias
          };
        };
      };
    };
  };
}
