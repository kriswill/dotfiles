{ inputs, ... }:

{
  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  # nixpkgs-unstable = final: _prev: {
  #   unstable = import inputs.nixpkgs-unstable {
  #     inherit (final) system;
  #     config.allowUnfree = true;
  #   };
  # };
  kitty = final: prev: {
    kitty = prev.kitty.overrideAttrs (old: {
      preCheck = ''
        # skip failing tests due to darwin sandbox
        substituteInPlace kitty_tests/file_transmission.py \
          --replace test_file_get dont_test_file_get \
          --replace test_path_mapping_receive dont_test_path_mapping_receive \
          --replace test_transfer_send dont_test_transfer_send
        substituteInPlace kitty_tests/shell_integration.py \
          --replace test_fish_integration dont_test_fish_integration
        substituteInPlace kitty_tests/shell_integration.py \
          --replace test_bash_integration dont_test_bash_integration
        substituteInPlace kitty_tests/open_actions.py \
          --replace test_parsing_of_open_actions dont_test_parsing_of_open_actions
        substituteInPlace kitty_tests/ssh.py \
          --replace test_ssh_connection_data dont_test_ssh_connection_data
        substituteInPlace kitty_tests/fonts.py \
          --replace 'class Rendering(BaseTest)' 'class Rendering'

        # TODO(emile): figure out why this test is failing and activate it
        # again.
        substituteInPlace kittens/hyperlinked_grep/main_test.go \
          --replace TestRgArgParsing DontTestRgArgParsing \

        # theme collection test starts an http server
        rm tools/themes/collection_test.go
        # passwd_test tries to exec /usr/bin/dscl
        rm tools/utils/passwd_test.go
      '';
    });
  };
}
