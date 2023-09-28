#!/usr/bin/env bash

set -euo pipefail

tempdir=$(mktemp -d /tmp/tmp.nix-updateinfo.XXX)
git clone --reference /etc/nixos /etc/nixos $tempdir > /dev/null 2>&1
pushd $tempdir
nix flake lock --update-input nixpkgs
nix build ".#nixosConfigurations.$(hostname).config.system.build.toplevel"
nix store diff-closures /run/current-system ./result \
	| awk '/[0-9] →|→ [0-9]/ && !/nixos/' || echo
popd
rm -rf $tempdir