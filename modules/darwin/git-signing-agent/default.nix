# Headless git commit signing: a host-only SSH signing key that a launchd
# daemon loads from 1Password, through a service account, into an ssh-agent
# with no 1Password prompt (knowledge/decisions/headless-git-signing-agent.md;
# setup and rotation: knowledge/playbooks/git-signing-agent-setup.md).
#
# Every other mac signs through 1Password's op-ssh-sign (home/git signing-*.inc),
# which prompts for approval per process and stops working when the app
# locks. That's fine at a keyboard, but a headless mac running Claude under
# herdr core has nobody to click. Here:
#
#   sops  → /run/secrets/<tokenSecret>   service-account token, root 0400
#   daemon (root, ./loader.sh)           runs ssh-agent as `user` on
#                                        /var/run/git-signing/agent.sock,
#                                        `op read`s the key, ssh-adds it
#   /etc/git/host.inc                    included LAST by the shared
#                                        ~/.config/git/config: points
#                                        gpg.ssh.program at git-signing-keygen
#                                        and user.signingkey at this key
#
# The user's processes can sign through the socket but can't read the token
# or the key. A hijacked session can sign only while it's on this machine,
# and can't carry the key off it. That needs the user to have no
# passwordless sudo.
#
# Host-selective: enable in modules/hosts/<host>/default.nix (today: mini).
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
      socketDir = "/var/run/git-signing";
      socket = "${socketDir}/agent.sock";
      logFile = "/var/log/git-signing-agent.log";
      label = "org.nixos.git-signing-agent";

      # "type base64" only. A comment adds nothing, and the loader compares
      # these two fields against `ssh-add -L`.
      publicKey =
        let
          raw = if builtins.isPath cfg.publicKey then builtins.readFile cfg.publicKey else cfg.publicKey;
        in
        lib.concatStringsSep " " (lib.take 2 (lib.splitString " " (lib.trim raw)));

      loader = pkgs.writeShellApplication {
        name = "git-signing-agent";
        text = builtins.readFile ./loader.sh;
      };

      # gpg.ssh.program: Apple's ssh-keygen, aimed at the signing agent. git
      # also runs it to verify (-Y verify / find-principals), which needs no
      # agent, so only -Y sign gets the clear error when the key is missing.
      keygen = pkgs.writeShellApplication {
        name = "git-signing-keygen";
        text = ''
          export SSH_AUTH_SOCK=${socket}
          if [ "''${1-}" = -Y ] && [ "''${2-}" = sign ] && ! /usr/bin/ssh-add -l >/dev/null 2>&1; then
            echo "git-signing-keygen: no signing key in the agent at $SSH_AUTH_SOCK" >&2
            echo "  status: sudo launchctl print system/${label}" >&2
            echo "  log:    ${logFile}" >&2
            exit 1
          fi
          exec /usr/bin/ssh-keygen "$@"
        '';
      };
    in
    {
      options.services.git-signing-agent = {
        enable = lib.mkEnableOption "prompt-free git commit signing from a 1Password service account";

        publicKey = lib.mkOption {
          type = with lib.types; either path str;
          example = lib.literalExpression "./git-signing.pub";
          description = ''
            Public half of the signing key (a file or the literal
            `ssh-ed25519 AAAA…`). git signs with it, and the daemon refuses
            to load any other key.
          '';
        };

        opItem = lib.mkOption {
          type = lib.types.str;
          example = "mini-automation/mini git signing key";
          description = ''
            `vault/item` of the 1Password SSH Key item: an `op://` reference
            without the scheme or field. The service account must be able to
            read the vault.
          '';
        };

        sopsFile = lib.mkOption {
          type = lib.types.path;
          example = lib.literalExpression "./secrets.yaml";
          description = "sops file holding the service-account token under `tokenSecret`.";
        };

        tokenSecret = lib.mkOption {
          type = lib.types.str;
          default = "op-sa-token";
          description = "Key of the service-account token in `sopsFile`.";
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
          description = "The 1Password CLI (Homebrew's 1password-cli cask, modules/darwin/homebrew.nix).";
        };
      };

      config = lib.mkIf cfg.enable {
        # sops-nix's darwin default is root:staff 0400, so only root can read
        # it. Nothing here may loosen that.
        sops.secrets.${cfg.tokenSecret} = { inherit (cfg) sopsFile; };

        launchd.daemons.git-signing-agent.serviceConfig = {
          Label = label;
          ProgramArguments = [ (lib.getExe loader) ];
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 30;
          ProcessType = "Background";
          EnvironmentVariables = {
            PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
            HOME = "/var/root";
            # No `op` cache daemon lingering as root after each read.
            OP_CACHE = "false";
            GSA_USER = cfg.user;
            GSA_SOCKET_DIR = socketDir;
            GSA_TOKEN_FILE = config.sops.secrets.${cfg.tokenSecret}.path;
            GSA_OP_ITEM = cfg.opItem;
            GSA_PUBLIC_KEY = publicKey;
            GSA_OP = cfg.op;
          };
          StandardOutPath = logFile;
          StandardErrorPath = logFile;
        };

        environment = {
          systemPackages = [ keygen ];

          # newsyslog: rotate at 1 MiB, keep 3, compress.
          etc."newsyslog.d/git-signing-agent.conf".text = ''
            ${logFile}  644  3  1024  *  J
          '';

          # The shared git config includes this last, so these win over the
          # op-ssh-sign settings above them. A missing include is a no-op,
          # which leaves every other host on 1Password.
          etc."git/host.inc".text = ''
            # Written by services.git-signing-agent (modules/darwin/git-signing-agent).
            [gpg "ssh"]
            	program = "${lib.getExe keygen}"
            [user]
            	signingkey = "key::${publicKey}"
          '';
        };
      };
    };
}
