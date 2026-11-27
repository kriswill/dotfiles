{ lib, requireFile }:
requireFile {
  name = "cognee-root.crt";
  hash = "sha256-qM7ARs2vRWYb98MuSvIp8hUeG8oyREcdklXNx5FzpVQ=";
  message = ''
    Import mini's verified Caddy root.crt as cognee-root.crt with
    nix-store --add-fixed sha256 cognee-root.crt.
  '';
  meta.license = lib.licenses.publicDomain;
}
