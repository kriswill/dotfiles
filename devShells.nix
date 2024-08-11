{ inputs, lib, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShellNoCC {
        nativeBuildInputs = [
          pkgs.git
          pkgs.ripgrep
          pkgs.fd
          pkgs.fzf
          # inputs'.fast-flake-update.packages.default
          # pkgs.python3.pkgs.invoke
          # pkgs.python3.pkgs.deploykit
          # inputs'.clan-core.packages.default
        ] ++ lib.optionals (!pkgs.stdenv.isDarwin) [ pkgs.bubblewrap ];
      };

      treefmt = {
        projectRootFile = ".git/config";
        programs = {
          terraform.enable = true;
          hclfmt.enable = true;
          yamlfmt.enable = true;
          mypy.directories = {
            "tasks" = {
              directory = ".";
              modules = [ ];
              files = [ "**/tasks.py" ];
              extraPythonPackages = [
                pkgs.python3.pkgs.deploykit
                pkgs.python3.pkgs.invoke
              ];
            };
          };
          deadnix.enable = true;
          stylua.enable = true;
          clang-format.enable = true;
          deno.enable = true;
          nixfmt.enable = true;
          nixfmt.package = pkgs.nixfmt-rfc-style;
          shellcheck.enable = true;
          shfmt.enable = true;
          rustfmt.enable = true;
        };
        settings = {
          formatter = {
            shellcheck = {
              options = [
                "--external-sources"
                "--source-path=SCRIPTDIR"
              ];
              excludes = [
                "gdb/*"
                "zsh/*"
              ];
            };
            shfmt = {
              includes = [
                "*.envrc"
                "*.zshrc"
              ];
              excludes = [
                "gdb/*"
                "zsh/*"
              ];
            };
          };
        };
      };
    };
}
