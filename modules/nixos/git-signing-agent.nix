# Prompt-free git commit signing on NixOS: the twin of
# modules/darwin/git-signing-agent (the design is there and in
# knowledge/decisions/headless-git-signing-agent.md). git gets the same
# contract on both OSes:
#
#   sops  → /run/secrets/<keySecret>     the private key, root 0400
#   git-signing-agent.service            ExecStart      ssh-agent as `user` on
#                                                       /run/git-signing/agent.sock
#                                        ExecStartPost  root ssh-adds the key and
#                                                       checks it is `publicKey`
#   /etc/git/host.inc                    included LAST by the shared
#                                        ~/.config/git/config: points
#                                        gpg.ssh.program at git-signing-keygen
#                                        and user.signingkey at this key
#
# The user's processes can sign through the socket but can't read the secret
# (0400 root) or the key (ssh-agent marks itself undumpable, so its own uid
# can't ptrace it or read its memory). That needs the user to have no
# passwordless sudo.
#
# systemd does what the darwin loader script does by hand: it owns the socket
# directory (RuntimeDirectory), runs the agent as the user, and restarts it.
# sops-nix decrypts during activation, before any unit starts, so there is no
# wait-and-retry loop either. The key comes from sops only: the darwin twin's
# 1Password source (opItem) isn't ported, because no NixOS host uses it.
#
# Gated like the darwin twin, since the host supplies the key: nebula enables
# it in modules/hosts/nebula/git-signing-agent.nix.
{
  flake.modules.nixos.git-signing-agent =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.git-signing-agent;
      gitSigning = import ../../lib/git-signing.nix;
      runtimeDir = "git-signing";
      socket = "/run/${runtimeDir}/agent.sock";
      unit = "git-signing-agent.service";
      ssh = config.programs.ssh.package;

      publicKey = gitSigning.publicKey lib cfg.publicKey;
      keyFile = config.sops.secrets.${cfg.keySecret}.path;

      # Runs as root after ssh-agent is exec'd. The key goes from the secret
      # into ssh-add's stdin; nothing else ever holds it.
      loadKey = pkgs.writeShellApplication {
        name = "git-signing-load-key";
        runtimeInputs = [
          ssh
          pkgs.coreutils
        ];
        text = ''
          export SSH_AUTH_SOCK=${socket}
          want=${lib.escapeShellArg publicKey}

          # ssh-agent binds its socket a moment after it is exec'd.
          for _ in $(seq 50); do
            [ -S "$SSH_AUTH_SOCK" ] && break
            sleep 0.1
          done
          [ -S "$SSH_AUTH_SOCK" ] || {
            echo "ssh-agent never created $SSH_AUTH_SOCK" >&2
            exit 1
          }

          ssh-add -q - <${keyFile}
          # Type and base64 only: the configured key and `ssh-add -L` differ
          # in comment.
          have=$(ssh-add -L | cut -d' ' -f1,2)
          if [ "$have" != "$want" ]; then
            ssh-add -D >/dev/null 2>&1 || true
            echo "${keyFile} is not the configured publicKey; unloaded it." \
              "Loaded: ''${have:-nothing}. Expected: $want" >&2
            exit 1
          fi
          echo "signing key loaded: $(ssh-add -l)"
        '';
      };

      # gpg.ssh.program: the system's ssh-keygen, aimed at the signing agent.
      keygen = pkgs.writeShellApplication {
        name = "git-signing-keygen";
        text = gitSigning.keygenText {
          inherit socket;
          sshAdd = "${ssh}/bin/ssh-add";
          sshKeygen = "${ssh}/bin/ssh-keygen";
          status = "systemctl status ${unit}";
          log = "journalctl -u ${unit}";
        };
      };
    in
    {
      options.services.git-signing-agent = {
        enable = lib.mkEnableOption "prompt-free git commit signing from an ssh-agent a root daemon loads";

        publicKey = lib.mkOption {
          type = with lib.types; either path str;
          example = lib.literalExpression "../git-signing.pub";
          description = ''
            Public half of the signing key (a file or the literal
            `ssh-ed25519 AAAA…`). git signs with it, and the service refuses
            to load any other key.
          '';
        };

        sopsFile = lib.mkOption {
          type = lib.types.path;
          example = lib.literalExpression "../git-signing.yaml";
          description = "sops file holding the private key under `keySecret`.";
        };

        keySecret = lib.mkOption {
          type = lib.types.str;
          default = "git-signing-key";
          description = ''
            Key in `sopsFile` of the private signing key itself, in OpenSSH
            format. The service loads it straight from sops, with no
            1Password and no network.
          '';
        };

        user = lib.mkOption {
          type = lib.types.str;
          example = "k";
          description = "Owner of the agent socket: the user whose commits get signed.";
        };
      };

      config = lib.mkIf cfg.enable {
        # sops-nix's default is root:root 0400, so only root can read it.
        # Nothing here may loosen that. restartUnits: a rotated key reloads.
        sops.secrets.${cfg.keySecret} = {
          inherit (cfg) sopsFile;
          restartUnits = [ unit ];
        };

        systemd.services.git-signing-agent = {
          description = "ssh-agent holding the git commit-signing key";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "exec";
            User = cfg.user;
            # /run/git-signing, owned by the user, removed with the unit: no
            # stale socket for the next start to trip over.
            RuntimeDirectory = runtimeDir;
            RuntimeDirectoryMode = "0700";
            ExecStart = "${ssh}/bin/ssh-agent -D -a ${socket}";
            # `+` runs it as root, which ssh-agent accepts next to its own
            # uid. A failed load fails the start, and Restart tries again:
            # after 5 s for a dead agent, backing off to 5 min (as the
            # darwin loader does) for a key that keeps failing to load.
            ExecStartPost = "+${lib.getExe loadKey}";
            Restart = "always";
            RestartSec = 5;
            RestartSteps = 6;
            RestartMaxDelaySec = 300;

            # The agent needs a unix socket and nothing else.
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateNetwork = true;
            RestrictAddressFamilies = "AF_UNIX";
            # Keep the key out of any swap device.
            MemorySwapMax = 0;
          };
        };

        environment = {
          systemPackages = [ keygen ];

          # Embeds a store path, so nix writes it rather than stow.
          etc."git/host.inc".text = gitSigning.hostInc {
            inherit publicKey;
            keygen = lib.getExe keygen;
            module = "modules/nixos/git-signing-agent.nix";
          };
        };
      };
    };
}
