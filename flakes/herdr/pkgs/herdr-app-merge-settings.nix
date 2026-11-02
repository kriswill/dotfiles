# herdr-app-merge-settings <declared.json>: merge declared settings into the
# app's settings.json, declared keys winning (./merge-settings.sh). The Linux
# wrapper (./herdr-app-wrap.nix) runs it before each launch; the nix-darwin
# module (../modules/darwin.nix) runs it for each core user at activation,
# since Finder launches the bundle and not a wrapper.
{
  writeShellApplication,
  coreutils,
  jq,
}:
writeShellApplication {
  name = "herdr-app-merge-settings";
  runtimeInputs = [
    coreutils
    jq
  ];
  text = builtins.readFile ./merge-settings.sh;
}
