{ config, lib, options, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.internal) mkBoolOpt;

  cfg = config.k.cli-apps.fastfetch;
in
{
  options.k.cli-apps.fastfetch = {
    enable = mkBoolOpt false "Whether or not to enable fastfetch.";
  };

  config = mkIf cfg.enable {
    xdg.configFile = {
      "fastfetch/config.jsonc".text =
        /* json */
        ''
          {
            "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
            "logo": {
              "padding": {
                "top": 2
              }
            },
            "display": {
              "color": {
                "keys": "green",
                "title": "blue"
              },
              "percent": {
                "type": 9
              },
              "separator": " 󰁔 ",
            },
            "modules": [
              {
                "type": "custom",
                "format": "\u001b[34m┌──────────── \u001b[1mOS Information\u001b[0m \u001b[34m────────────┐"
              },
              {
                "type": "title",
                "key": " ╭─ ",
                "keyColor": "green",
                "color": {
                  "user": "green",
                  "host": "green"
                }
              },${lib.optionalString pkgs.stdenv.isDarwin /* json */ ''
                {
                      "type": "os",
                      "key": " ├─  ",
                      "keyColor": "green"
                    },
                    {
                      "type": "kernel",
                      "key": " ├─  ",
                      "keyColor": "green"
                    },
                    {
                      "type": "packages",
                      "key": " ├─  ",
                      "keyColor": "green"
                    },
              ''}${lib.optionalString pkgs.stdenv.isLinux /* json */ ''
                {
                      "type": "os",
                      "key": " ├─ ",
                      "keyColor": "green"
                    },
                    {
                      "type": "kernel",
                      "key": " ├─ ",
                      "keyColor": "green"
                    },
                    {
                      "type": "packages",
                      "key": " ├─ ",
                      "keyColor": "green"
                    },
              ''}
              {
                "type": "shell",
                "key": " ╰─  ",
                "keyColor": "green"
              },
              {
                "type": "custom",
                "format": "\u001b[34m├───────── \u001b[1mHardware Information\u001b[0m \u001b[34m─────────┤"
              },
              {
                "type": "display",
                "key": " ╭─ 󰍹 ",
                "keyColor": "blue"
              },
              {
                "type": "cpu",
                "key": " ├─ 󰍛 ",
                "keyColor": "blue"
              },
              {
                "type": "gpu",
                "key": " ├─ 󰍛 ",
                "keyColor": "blue"
              },
              {
                "type": "memory",
                "key": " ├─   ",
                "keyColor": "blue"
              },
              {
                "type": "disk",
                "key": " ╰─ 󱛟 ",
                "keyColor": "blue"
              },
              {
                "type": "custom",
                "format": "\u001b[34m├───────── \u001b[1mSoftware Information\u001b[0m \u001b[34m─────────┤"
              },
              {
                "type": "wm",
                "key": " ╭─  ",
                "keyColor": "yellow"
              },
              {
                "type": "terminal",
                "key": " ├─  ",
                "keyColor": "yellow"
              },
              {
                "type": "font",
                "key": " ╰─  ",
                "keyColor": "yellow"
              },
              {
                "type": "custom",
                "format": "\u001b[34m└────────────────────────────────────────┘"
              },
              {
                "type": "custom",
                "format": "   \u001b[38m   \u001b[34m    \u001b[36m    \u001b[35m    \u001b[34m    \u001b[33m    \u001b[32m    \u001b[31m "
              },
              "break"
            ]
          }
        '';
    };
  };
}

