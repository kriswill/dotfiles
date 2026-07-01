# op-ssh-sign on NixOS: stable system-profile path (survives rebuilds), provided
# by programs._1password-gui. Included from ../config via includeIf gitdir:/home/.
[gpg "ssh"]
	program = /run/current-system/sw/bin/op-ssh-sign
