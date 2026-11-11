{
  # Work around two ChatGPT app dependencies that don't build at the flake's
  # nixpkgs pin. nixpkgs' rust hooks now tell the vendored -sys crates to link
  # the system libraries (AWS_LC_SYS_USE_SYSTEM and friends), and each package
  # has to list those libraries as inputs. tectonic and codex didn't yet, so
  # aws-lc-sys' build script panics. Both were fixed upstream right after the
  # pin (NixOS/nixpkgs 743696b7 for tectonic, 16b46369 for codex).
  #
  # - tectonic gets the missing input (aws-lc), as upstream added it.
  # - codex is left out: the app runs the codex OpenAI bundled with it
  #   (`codex = null`) instead of nixpkgs'. Fixing codex the same way works on
  #   nebula (19 min on 24 cores), but nothing caches it, and compiling it
  #   takes down the 4-core, 15 GiB CI runner.
  #
  # Each half switches itself off once nixpkgs' package lists aws-lc. When both
  # have, a warning on every evaluation, nrs and CI alike, says to delete this
  # file; that also puts the app back on nixpkgs' codex.
  configurations.nixos.nebula.module =
    { pkgs, lib, ... }:
    let
      fixed = drv: lib.any (p: lib.getName p == "aws-lc") drv.buildInputs;
    in
    {
      nixpkgs.overlays = [
        (final: prev: {
          tectonic-unwrapped =
            if fixed prev.tectonic-unwrapped then
              prev.tectonic-unwrapped
            else
              prev.tectonic-unwrapped.overrideAttrs (old: {
                buildInputs = old.buildInputs ++ [ final.aws-lc ];
                passthru = old.passthru // {
                  awsLcOverride = true;
                };
              });
          chatgpt = if fixed prev.codex then prev.chatgpt else prev.chatgpt.override { codex = null; };
        })
      ];
      warnings =
        lib.optional (fixed pkgs.codex && !(pkgs.tectonic-unwrapped.awsLcOverride or false))
          "nixpkgs' tectonic and codex build again, so the ChatGPT workarounds are switched off. Delete modules/hosts/nebula/chatgpt-broken-deps.nix.";
    };
}
