# rtk (Rust Token Killer) — CLI proxy that filters/compresses common dev
# command output (git, grep, cargo, npm, docker, aws, …) before it reaches an
# LLM's context, cutting token usage 60-90%. Ships hooks that wrap tool calls
# in Claude Code and other agent CLIs. Upstream: https://github.com/rtk-ai/rtk
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.43.0";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    tag = "v${version}";
    hash = "sha256-n5bkPPsrdM4fE5ltocTjlq+JwRgp39yib6S79fci4m4=";
  };

  cargoLock.lockFile = "${src}/Cargo.lock";

  # Integration tests shell out to git/docker/aws/etc. and expect a live repo
  # environment; skip them in the sandbox build.
  doCheck = false;

  meta = {
    description = "CLI proxy that filters dev command output to cut LLM token usage";
    homepage = "https://github.com/rtk-ai/rtk";
    license = lib.licenses.asl20;
    mainProgram = "rtk";
  };
}
