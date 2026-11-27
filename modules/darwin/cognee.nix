{ inputs, ... }:
{
  flake.modules.darwin.cognee = inputs.cognee.darwinModules.cognee;
}
