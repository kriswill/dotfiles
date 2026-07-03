# tomato (binary: `tomato`, crate: `tomato-toml`) — a Rust CLI to get/set/delete
# TOML values while preserving comments and formatting (built on toml_edit, the
# same crate cargo uses to edit Cargo.toml). Replaces the earlier Python tomlkit
# helper. Upstream: https://github.com/ceejbot/tomato
#
#   tomato get <dotted.key> <file>
#   tomato set <dotted.key> <value> <file>     # bare true/false/NN -> typed; quote for strings
#
# `set` writes the file IN PLACE (File::create — truncate+rewrite, NOT atomic),
# so callers that target a live-watched file (e.g. Noctalia's settings.toml)
# must edit a same-directory temp copy and atomically `mv` it into place — see
# setNoctaliaScreenCorners in home/hyprland/.config/hypr/keybindings.lua (the
# gaps toggle, formerly scripts/toggle-gaps.sh) and docs/noctalia.md.
#
# Source comes from the `tomato` flake input (flake = false), passed as
# `tomato-src`. Deps are all crates.io, so cargoLock.lockFile pins them from the
# vendored Cargo.lock with no cargoHash to maintain.
{
  rustPlatform,
  tomato-src,
}:
rustPlatform.buildRustPackage {
  pname = "tomato-toml";
  version = "1.0.0";
  src = tomato-src;

  cargoLock.lockFile = "${tomato-src}/Cargo.lock";

  # The crate's own tests read fixture files; skip them in the sandbox build.
  doCheck = false;

  meta = {
    description = "CLI to get/set TOML values preserving comments and formatting";
    homepage = "https://github.com/ceejbot/tomato";
    mainProgram = "tomato";
  };
}
