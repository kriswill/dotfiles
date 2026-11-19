# pam-tid-gate

Touch ID for `sudo` only while someone can reach the Mac's own Touch ID
readers. Otherwise `sudo` goes straight to the password instead of waiting on
a prompt nobody can answer.

## Why

Apple's `pam_tid.so` shows its prompt on the Mac's own screen and accepts only
that Mac's readers. A reader on another Mac driving it through Universal
Control doesn't count, and neither does anything you can do over SSH or a
remote terminal. When nobody is at the Mac, `sudo` waits on the prompt.

macOS PAM is OpenPAM, which can't skip a module on a condition, and macOS
ships no `pam_exec`. So the condition lives in a module that stands where
`pam_tid.so` would.

## Rules

`pam_tid_gate.so` returns `PAM_IGNORE`, so the stack goes on to the password,
when any enabled rule holds:

| Rule      | Holds when                                              | Read from                                   |
|-----------|---------------------------------------------------------|---------------------------------------------|
| `ssh`     | `sudo` runs under `sshd`/`sshd-session`, or has `SSH_CONNECTION`, `SSH_CLIENT` or `SSH_TTY` set | `sysctl` parent chain, environment |
| `locked`  | the console session's screen is locked                  | `IOConsoleUsers` → `CGSSessionScreenIsLocked` |
| `console` | no logged-in session is on the console                  | `IOConsoleUsers` → `kCGSSessionOnConsoleKey` |
| `idle`    | no local keyboard or mouse input for `idle=` seconds    | `IOHIDSystem` → `HIDIdleTime`               |
| `uc`      | Universal Control is linked to another Mac              | a `com.apple.universalcontrol.*` power assertion |

Otherwise it loads `/usr/lib/pam/pam_tid.so.2` and hands it the call, so Touch
ID works as before. A state it cannot read counts toward the password, except
Universal Control, which counts as not linked.

The environment check catches a shell in a tmux session started over ssh,
whose parent chain ends at launchd rather than `sshd`. A shell in an hc
(herdr-core) terminal has neither, so remote use through hc relies on the
`idle`, `locked` and `uc` rules.

Universal Control input counts as local input for `idle`, which is why `uc`
is its own rule. The Universal Control assertion is held whenever the Macs are
linked, including while the cursor is on the other Mac.

Module options: `rules=<comma list>` (default: all five), `idle=<seconds>`
(default 300, 0 turns the rule off), `debug` (prints the decision on stderr).
An option that doesn't parse keeps its default, and an empty or misspelled
`rules=` keeps all five, so a typo can't switch rules off.

The module calls no libpam function and links no libpam, so the only libpam
in `sudo` is the system one that `pam_tid` expects. OpenPAM's headers supply
the types and constants. The install check enforces both.

## Outputs

- `packages.aarch64-darwin.pam-tid-gate` (and `default`):
  `lib/pam/pam_tid_gate.so` and `bin/pam-tid-gate`, which prints what `sudo`
  would use right now and why (exit 0 for Touch ID, 1 for the password).
  Without arguments it uses the gate's options from `/etc/pam.d/sudo_local`. It
  can't show the Touch ID prompt itself: `pam_tid` asks `authd` for the
  `com.apple.security.sudo` right, which only an entitled client (`sudo`) gets.
- `darwinModules.pam-tid-gate` (and `default`): `security.pam-tid-gate.enable`
  and `.idleSeconds`. It turns off nix-darwin's plain `pam_tid` line
  (`security.pam.services.sudo_local.touchIdAuth`) and appends the gate to
  `/etc/pam.d/sudo_local` with `lib.mkAfter`, so a `pam_reattach` line added
  with `lib.mkBefore` stays ahead of it.

## Consuming it

```nix
inputs.pam-tid-gate = {
  url = "./flakes/pam-tid-gate"; # later: "github:<owner>/pam-tid-gate"
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-parts.follows = "flake-parts";
};
```

Import `inputs.pam-tid-gate.darwinModules.default` and set
`security.pam-tid-gate.enable = true;`. The module's `package` defaults to this
flake's build for the host system, so no overlay is needed.

Keep a root shell open the first time you switch to it: the module runs
inside `sudo`.
