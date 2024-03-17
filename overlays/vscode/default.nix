{ channels, ... }:

final: prev: {
  inherit (channels.unstable) vscode vscode-extensions;
}