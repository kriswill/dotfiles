# flatpak-user — `flatpak` wrapper defaulting scope-aware subcommands to
# --user (Linux-only consumer; the wrapper itself evaluates lazily elsewhere).
# See pkgs/flatpak-user.nix.
_final: prev: {
  flatpak-user = prev.callPackage ../pkgs/flatpak-user.nix { };
}
