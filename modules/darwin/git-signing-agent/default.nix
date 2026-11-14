# Prompt-free git commit signing: an SSH signing key that a launchd daemon
# loads into an ssh-agent, so a commit never waits on 1Password
# (knowledge/decisions/headless-git-signing-agent.md; setup and rotation:
# knowledge/playbooks/git-signing-agent-setup.md).
#
# Every other mac signs through 1Password's op-ssh-sign (home/git signing-*.inc),
# which prompts for approval per process and stops working when the app
# locks. That's fine at a keyboard, but an AI harness (Claude under herdr
# core) has nobody to click. Here:
#
#   sops  → /run/secrets/<secret>        root 0400. Either the private key
#                                        itself (keySecret), or a 1Password
#                                        service-account token (opItem +
#                                        tokenSecret)
#   daemon (root, ./loader.sh)           runs ssh-agent as `user` on
#                                        /var/run/git-signing/agent.sock and
#                                        ssh-adds the key: the secret's
#                                        contents, or `op read` with the token
#   /etc/git/host.inc                    included LAST by the shared
#                                        ~/.config/git/config: points
#                                        gpg.ssh.program at git-signing-keygen
#                                        and user.signingkey at this key
#
# The user's processes can sign through the socket but can't read the secret
# or the key. A hijacked session can sign only while it's on this machine,
# and can't carry the key off it. That needs the user to have no
# passwordless sudo.
#
# Host-selective: enable in modules/hosts/<host>/default.nix (mini: key from
# 1Password; k: key from sops). NixOS twin: modules/nixos/git-signing-agent.nix.
{
  flake.modules.darwin.git-signing-agent =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.git-signing-agent;
      gitSigning = import ../../../lib/git-signing.nix;
      socketDir = "/var/run/git-signing";
      socket = "${socketDir}/agent.sock";
      logFile = "/var/log/git-signing-agent.log";
      label = "org.nixos.git-signing-agent";

      publicKey = gitSigning.publicKey lib cfg.publicKey;

      # The one sops secret the daemon reads: the key, or (with opItem) the
      # token that fetches it.
      fromSops = cfg.opItem == null;
      secret = if fromSops then cfg.keySecret else cfg.tokenSecret;
      secretPath = config.sops.secrets.${secret}.path;

      loader = pkgs.writeShellApplication {
        name = "git-signing-agent";
        text = builtins.readFile ./loader.sh;
      };

      # gpg.ssh.program: Apple's ssh-keygen, aimed at the signing agent.
      keygen = pkgs.writeShellApplication {
        name = "git-signing-keygen";
        text = gitSigning.keygenText {
          inherit socket;
          sshAdd = "/usr/bin/ssh-add";
          sshKeygen = "/usr/bin/ssh-keygen";
          status = "sudo launchctl print system/${label}";
          log = logFile;
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
            `ssh-ed25519 AAAA…`). git signs with it, and the daemon refuses
            to load any other key.
          '';
        };

        sopsFile = lib.mkOption {
          type = lib.types.path;
          example = lib.literalExpression "../git-signing.yaml";
          description = ''
            sops file holding the daemon's secret: the private key under
            `keySecret`, or with `opItem` the service-account token under
            `tokenSecret`.
          '';
        };

        keySecret = lib.mkOption {
          type = lib.types.str;
          default = "git-signing-key";
          description = ''
            Key in `sopsFile` of the private signing key itself, in OpenSSH
            format. The daemon loads it straight from sops, with no 1Password
            and no network. Unused with `opItem`.
          '';
        };

        opItem = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          example = "mini-automation/mini git signing key";
          description = ''
            Keep the key in 1Password instead of sops: `vault/item` of its SSH
            Key item (an `op://` reference without the scheme or field). The
            daemon reads it with the service-account token under
            `tokenSecret`; that account must be able to read the vault.
          '';
        };

        tokenSecret = lib.mkOption {
          type = lib.types.str;
          default = "op-sa-token";
          description = "Key of the service-account token in `sopsFile` (with `opItem`).";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = config.system.primaryUser;
          defaultText = lib.literalExpression "config.system.primaryUser";
          description = "Owner of the agent socket: the user whose commits get signed.";
        };

        op = lib.mkOption {
          type = lib.types.str;
          default = "/opt/homebrew/bin/op";
          description = ''
            The 1Password CLI (Homebrew's 1password-cli cask,
            modules/darwin/homebrew.nix). Used with `opItem`.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # sops-nix's darwin default is root:staff 0400, so only root can read
        # it. Nothing here may loosen that.
        sops.secrets.${secret} = { inherit (cfg) sopsFile; };

        launchd.daemons.git-signing-agent.serviceConfig = {
          Label = label;
          # launchd can start this job before /nix is mounted. A missing
          # executable leaves it in EX_CONFIG despite KeepAlive; use Apple's
          # shell to wait for the loader, as nix-darwin's boot activation does.
          ProgramArguments = [
            "/bin/sh"
            "-c"
            ''
              printf '%s git-signing-agent: bootstrap started\n' "$(/bin/date '+%Y-%m-%dT%H:%M:%S%z')"
              /bin/wait4path ${lib.getExe loader} || exit $?
              printf '%s git-signing-agent: loader available; executing\n' "$(/bin/date '+%Y-%m-%dT%H:%M:%S%z')"
              exec ${lib.getExe loader}
            ''
          ];
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 30;
          ProcessType = "Background";
          EnvironmentVariables = {
            PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
            HOME = "/var/root";
            GSA_USER = cfg.user;
            GSA_SOCKET_DIR = socketDir;
            GSA_PUBLIC_KEY = publicKey;
          }
          // (
            if fromSops then
              { GSA_KEY_FILE = secretPath; }
            else
              {
                # No `op` cache daemon lingering as root after each read.
                OP_CACHE = "false";
                GSA_TOKEN_FILE = secretPath;
                GSA_OP_ITEM = cfg.opItem;
                GSA_OP = cfg.op;
              }
          );
          StandardOutPath = logFile;
          StandardErrorPath = logFile;
        };

        environment = {
          systemPackages = [ keygen ];

          # newsyslog: rotate at 1 MiB, keep 3, compress.
          etc."newsyslog.d/git-signing-agent.conf".text = ''
            ${logFile}  644  3  1024  *  J
          '';

          # Embeds a store path, so nix writes it rather than stow.
          etc."git/host.inc".text = gitSigning.hostInc {
            inherit publicKey;
            keygen = lib.getExe keygen;
            module = "modules/darwin/git-signing-agent";
          };
        };
      };
    };
}
