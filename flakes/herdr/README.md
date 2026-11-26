# herdr

Everything herdr in one flake: our fork of the herdr TUI, Herdr's desktop app
and herdr-core (`hc`), the helper tools around them, a markdown viewer mod,
an update check, and the NixOS and nix-darwin modules that configure them. The root flake consumes it
as `inputs.herdr` (`./flakes/herdr`).

| Output | Systems | What |
|---|---|---|
| `packages.herdr-cli` (`default`) | all | the herdr TUI, from our fork (the `herdr-cli` input), with a build identity |
| `packages.herdr-nav` | all | vim-aware ctrl+h/j/k/l pane navigation for herdr |
| `packages.herdr-core` | all | `hc` / `herdr-core`: upstream's release build, untouched |
| `packages.herdr-app-unwrapped` | all | Herdr (GPUI + wgpu): upstream's release build, patchelf'd on Linux, the signed `Herdr.app` untouched on macOS |
| `packages.herdr-app` | all | the app with telemetry off and this core at the end of PATH, for `nix run` (a shell launch; Finder bypasses it) |
| `packages.herdr-update-check` | all | is any of these behind upstream, or running a stale build? |
| `packages.herdr-open` | all | `$BROWSER` that opens a link where you're looking at the terminal from (see "Links open where you are") |
| `packages.herdr-askpass` | all | an agent's `SUDO_ASKPASS` that asks for sudo's password in a dialog of the Herdr window you're looking from (see "sudo asks where you are") |
| `packages.herdr-md` | all | a markdown viewer mod for Herdr and `mdh`, its CLI: upstream at a pinned commit, patched for Linux (see "The markdown viewer") |
| `nixosModules.herdr` (`default`) | | `programs.herdr-{cli,core,app,md}`, `services.herdr-update-check` |
| `darwinModules.herdr` (`default`) | | the same options, with the app's choices written to settings.json |

Systems: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`.

## The herdr TUI (`herdr-cli`)

Built by our fork's own flake: `github:kriswill/herdr/vX.Y.Z-custom`, the
`custom` branch rebased onto each upstream release (its patch commits are
listed on the input in `flake.nix`). `pkgs/herdr-cli.nix` stamps it with
`HERDR_BUILD_CHANNEL=kriswill-custom` and `HERDR_BUILD_ID=<fork shortRev>`, so
`herdr --version` says which fork commit it is. It builds from source; there's
no binary cache. The fork's `rust-overlay` is overridden past the tag's pin
(and follows our nixpkgs).

To move to a new upstream release, rebase `custom` onto it, tag
`vA.B.C-custom`, and repoint `herdr-cli.url`. `herdr-update-check` reminds you.

`herdr-nav` runs herdr by store path, because the herdr server spawns
`[[keys.command]]` entries with a PATH we don't control. The module installs
it by default.

## herdr-core and Herdr: repackaged release builds

Nothing compiles, so there is nothing to cache. A build fetches upstream's
tarball (the same bytes a substituter would send) and, for the Linux app,
runs patchelf, all in seconds. On macOS both are upstream's Developer
ID-signed builds, installed with no fixup at all (see "darwin"). Upstream releases about daily, and `update.ts`
picks a release up as soon as you run it. The alternatives build from source
(Rust + Zig 0.16 + vendored Ghostty):

- nixpkgs: `herdr-core` + `herdr-desktop`, NixOS/nixpkgs#581031 (open, awaiting
  review as of 2026-11-01); Hydra-cached once merged, lagging days to weeks.
- numtide's [llm-agents.nix](https://github.com/numtide/llm-agents.nix)
  (`herdr-core`, `herdr-app`), cached on `cache.numtide.com` only when used
  with their nixpkgs.
- `herdrdev/herdr-nix` (cachix `herdr`) covers only the TUI.

A source-built `hc` is linked against the Nix store, so `hc machine add`
can't copy it to another machine; #581031 downloads upstream's build instead.
Upstream's static Linux binary copies fine. `programs.herdr-app.package` and
`programs.herdr-core.package` take a source build if you'd rather.

Packaging notes:

- **Environment leaks into every terminal.** The app passes its environment to
  herdr-core, which passes it to every terminal it starts. So nothing sets
  `LD_LIBRARY_PATH`: the dlopened Vulkan, Wayland and EGL go on the RUNPATH via
  `runtimeDependencies`. The wrapper adds no PATH and sets only
  `HERDR_TELEMETRY=0` and `HERDR_CORE_DIRS`, which only herdr-app reads.
- **The core is pinned.** The app puts the folder it found hc in first on its
  PATH (upstream `src/core_bin.rs` `use_core`), and every terminal inherits
  it. Left to search, it found `/run/current-system/sw/bin`, which then
  shadowed `/run/wrappers/bin` and broke `sudo` in every pane. The NixOS
  module sets `HERDR_CORE_DIRS` to `programs.herdr-core.package`'s bin, so
  the app finds hc there, and that folder holds only `hc` and `herdr-core`.
  The darwin module, which has no wrapper, writes `core = /etc/herdr-core/hc`
  into settings.json instead: a link to the same package, in a folder that
  holds only hc, at a path with no store hash in it.
- **Self-update is off.** On Linux a release build updates itself only when
  it finds `herdr-app.svg` beside its binary (upstream `src/update.rs`
  `find_root`). The icon lives in `share/icons`, and installCheck fails the
  build otherwise. On macOS any `Herdr.app` bundle is an install root, so the
  updater stays armed, but it stages downloads beside the bundle and
  nix-darwin's copy under `/Applications/Nix Apps` is root-owned: it gets
  EACCES, logs a warning and retries in 30 minutes, only once upstream is
  ahead (and only until the next `update.ts` bump). herdr-core sees its
  `/nix/store/` path (canonicalized, so the `/etc/herdr-core/hc` link counts)
  and refuses `hc update` ("update it in your Nix configuration"), and the
  app never updates such a core: since 0.1.16 its Settings says "Managed by
  nix: update it there", with the newer version when there is one.
- **No fixup for herdr-core.** On macOS it is upstream's signed
  `Herdr Core.app`, so strip or install_name_tool would break the signature.
  On Linux it is static-pie and needs nothing.
- **Linger.** hc starts its core as a transient `systemd-run --user` unit and,
  the first time, turns on linger for the user by itself, so terminals outlive
  logouts. The NixOS module declares it (`programs.herdr-core.linger`, on by
  default) for `programs.herdr-core.users`. Declaring it off doesn't stop hc.
  A lingering user manager starts at boot, and so does everything its
  `default.target` wants, timers included. macOS has no linger: hc starts the
  core as a one-shot launchd job (see "darwin").
- **No core service.** hc spawns the core on demand; a declared unit would
  compete with it.
- **Telemetry** is on by default upstream (a daily usage report). The modules
  and the standalone package turn it off: `HERDR_TELEMETRY=0` from the Linux
  wrapper, `telemetry: false` in settings.json on macOS.

## Modules

`modules/common.nix` declares every option and does what both OSes share.
`modules/nixos.nix` and `modules/darwin.nix` add the parts only their OS can
do.

| Option | NixOS | nix-darwin |
|---|---|---|
| `programs.herdr-cli.{enable,package,nav.enable,python}` | ✓ | ✓ |
| `programs.herdr-core.{enable,package,users,settings}` | ✓ (`settings` → tmpfiles link) | ✓ (`settings` → activation-script link) |
| `programs.herdr-core.linger` | ✓ | — |
| `programs.herdr-core.browser.{enable,package}` | ✓ (`BROWSER` session variable) | ✓ (`BROWSER` for shells and launchd's user domain) |
| `programs.herdr-core.askpass.{enable,package}` | ✓ (installs it; `SUDO_ASKPASS` goes in the agent's env) | ✓ (the same) |
| `programs.herdr-app.{enable,package,finalPackage,telemetry,settings,keys}` | ✓ (wrapper: env + merge at launch) | ✓ (`telemetry`, `core`, `settings` merged into settings.json at activation; `keys` → link; `finalPackage` is the bare bundle) |
| `programs.herdr-md.{enable,package}` | ✓ (the mod → tmpfiles links) | ✓ (the mod → activation-script links) |
| `services.herdr-update-check.{enable,package,finalPackage}` | systemd user timer, `calendar` | launchd user agent, `startCalendarInterval` |

`programs.herdr-cli.python` (default `python3`, `null` for none) is for
herdr's agent integration hooks. Claude's `herdr-agent-state.sh` reports the
session id over the herdr socket with python3, and exits silently without it.

## Links open where you are (`herdr-open`)

Claude Code on nebula, seen from Herdr on a Mac: a plain click on a link
used to open it in nebula's browser. Claude Code's fullscreen TUI turns on
mouse reporting, so the click goes to Claude Code, which runs `$BROWSER <url>`
on its own machine (`xdg-open` or `open` when `BROWSER` is unset). Herdr never
sees it. Cmd-click (Ctrl-click on Linux) already opened links in the Mac's
browser, because Herdr acts on that before the program gets the click
(upstream `src/terminal.rs`, `link_mods`). The URL has to be in the cell's
OSC 8 link or match Ghostty's link pattern.

`programs.herdr-core.browser.enable` makes plain clicks, and anything else a
program opens (`gh … --web`, an agent's login), land where you are:

1. **`herdr-open`** is `$BROWSER`. In an hc terminal, an http(s) URL becomes
   a label on that terminal, `herdr-open.<ms>-<hex>=<url>`, and it waits up
   to 2.5 s for `<key>.done`. With no answer it opens the URL locally, as
   before. Without `HC_TERMINAL_ID`, for another scheme, or with
   `HERDR_OPEN=off`, it skips the label and opens locally straight away. The
   local opener runs with `BROWSER` unset, because xdg-open falls back to
   `$BROWSER`.
2. herdr-core sends label changes to every Herdr window that knows the
   terminal, on every machine (`events.subscribe` mirrors other machines'
   terminals).
3. **The `herdr-open` mod**, an empty float in the `personal` layout, sees the
   request in `terminals()`. Only a window that is in front may claim it.
   Each window waits a while first: 0/100/200 ms if the terminal has the
   keyboard / is on screen in this tab / is elsewhere, plus, on macOS,
   10 ms per second since the last input (more than 60 s idle: no claim at
   all), or a flat 400 ms on Linux, which has no idle time here. The first
   window to claim (`<key>.claim=<me>`, read back, because the last write
   wins) opens the link with `open` or `xdg-open` and answers
   `<me> here`. For a loopback URL (localhost, 127.x, ::1, or an OAuth
   `redirect_uri` that points at one) from another machine's terminal, it
   answers `<me> host` and shows a toast, and herdr-open opens it on its own
   machine, where that address lives.

No machine names are configured anywhere. Whichever window you're in claims
the link, whichever machine runs the program. A Mac in use beats nebula's
window left in front on its desk, and a Mac idle for a minute stays out.

Security:

- **Who can ask.** Only a label carries a request, and labels are written
  through the core's API. Terminal output can't write one, so a hostile file
  you `cat` or a remote log can't open anything. (An escape sequence could
  have come from any output; that's why this isn't one.) Anything that can
  write labels already runs as you on one of your machines.
- **What can be opened.** http and https only, at most 8 KiB, no whitespace
  or control characters. The mod checks again, and runs `open` by argv with
  no shell. `vscode:`, `file:` and the like stay with the host's own opener
  (Claude Code reveals `file:` links itself).
- **Worst case.** A process running as you on one of your machines opens up
  to 6 http(s) tabs every 10 s in the browser of the machine you're using.
  Further requests are refused with a toast and open on their own machine.
  Every open that doesn't come from the terminal with the keyboard shows a
  toast with the URL.
- Cmd-click already follows a link's OSC 8 target, which needn't match the
  text shown. That's ordinary terminal behaviour, and it's Herdr's, not
  ours.

Testing, with nobody's hands on anything:

- `herdr-open --where <url>` in an hc terminal sends a dry request: every
  copy of the mod runs its checks and the claim, opens nothing, and the
  winner answers. It prints which machine would open the link, or that
  nobody answered.
- `bun test flakes/herdr/tests/herdr-open-mod.test.ts` runs the real mod
  against a simulated core and windows: Mac against nebula, an idle Mac,
  loopback, unsafe URLs, stale requests, two Macs racing, the rate limit.
- `HERDR_OPEN_LOCAL=<logger>` stands in for the local opener.

Applying it: `nrs` restows the mod, and the layout links pick up the float.
A core started before then has the old environment, so terminals it starts
don't have `BROWSER`. On NixOS the user manager learns the variable at the
next login (with linger, at a reboot), and on a Mac new shells have it.
After that, `hc server restart` moves running programs to a new core. Each
program keeps the environment it started with, so restart Claude Code to
pick it up.

## sudo asks where you are (`herdr-askpass`)

An agent's shell has no terminal: Claude Code's Bash tool runs commands
without one, so `sudo` (and `nrs`, which runs `sudo -v`) fails with "a
terminal is required to read the password". On a Mac you're using, Touch ID
might answer, but not on a headless one like mini, seen from Herdr on
another machine. `programs.herdr-core.askpass.enable` installs
`herdr-askpass` at `/run/current-system/sw/bin/herdr-askpass`, which makes
sudo ask in a dialog of the Herdr window you're looking from:

1. **sudo runs its askpass.** It does that for `sudo -A`, and on its own when
   it has no terminal while `SUDO_ASKPASS` *and* `DISPLAY` are both set.
   sudo's manual documents `SUDO_ASKPASS` for "if no terminal is available",
   but not the `DISPLAY` condition: that comes from sudo 1.9.17p2 on mini,
   where a probe askpass ran with both set and not with `SUDO_ASKPASS`
   alone. Both go in the agent's own environment (`env` in
   `~/.claude/settings.json`), and **neither is exported system-wide**:
   Homebrew adds `-A` to every sudo whenever `SUDO_ASKPASS` is set
   (`system_command.rb`, and `bin/brew` passes the variable through), so a
   global export would send every cask's sudo to the askpass.
2. **`herdr-askpass` with a terminal** (`sudo -A` or brew from a shell that
   has one) asks there, as sudo would have: prompt to `/dev/tty`, `read -s`.
3. **Without one**, it needs `HC_TERMINAL_ID` (otherwise it exits 1 at
   once). It makes a private directory (`mktemp -d`, 0700) holding a FIFO and
   two 0600 files, sudo's prompt and sudo's command line (`ps` of its
   parent), with control characters removed from both. It opens the FIFO
   read-write and starts a prompt terminal on this machine's core:
   `hc run --bg --no-parent --no-notify --rm` with labels `herdr-askpass=1`
   and `herdr-askpass.for=<the asking terminal>`, running
   `herdr-askpass --read <dir> <askpass pid> <deadline> <asker>`. The prompt
   and command line travel as files because herdr-core shows a terminal's
   argv to every connected window.
4. **The `herdr-askpass` mod**, an empty float in the `personal` layout,
   sees the labelled terminal in `terminals()`. Every window connected to
   that machine does, so each one opens it as a modal dialog: the mod again
   as a title bar (`{bar: true}`: where sudo runs, who asked, Cancel) over
   a `{terminal}` block. The dialog plays the `blocked` sound.
5. **You type into that terminal.** The prompt turns echo off once for its
   whole life and reads a key at a time. Enter sends the password, Esc or
   ctrl-c cancels, and the bar's Cancel kills the prompt terminal. The prompt
   writes one line to the FIFO, `P:<password>` or `C`, and herdr-askpass
   prints the password for sudo. The terminal ends, so every dialog closes
   itself.
6. **No answer** within `HERDR_ASKPASS_TIMEOUT` seconds (default 180, read as
   decimal), or the prompt ends without one: herdr-askpass exits 1, kills
   the prompt, and sudo reports no password. After a wrong password sudo
   calls it again (three tries), so a fresh dialog opens each time. If
   herdr-askpass is killed without its cleanup (Claude Code's Bash tool
   SIGKILLs a command at its timeout, 120 s by default), the prompt sees
   its pid gone within a second, removes the directory and ends, which
   closes the dialogs.

Security:

- **Where the password goes.** Keystrokes from the Herdr window to the
  prompt's pty, by the same path as anything you type in an hc terminal
  (to another machine, over the core's ssh connection). Then the FIFO in a
  0700 directory, then sudo's pipe. It's never in a label, an argument, a
  file or on screen. Echo is off for the prompt's whole life, not per
  `read -s` (that turns echo back on after each key, so a key arriving
  between two reads would be echoed), and `--rm` removes the terminal as it
  exits.
- **Who can ask.** Any process running as you can start a terminal with
  these labels, so a fake prompt is possible. Such a process could already
  wrap `sudo` itself. The dialog names the asking terminal and shows sudo's
  command line, and since the prompt text is stripped of control
  characters, `sudo -p` can't redraw that line. If you didn't expect it,
  press Cancel.
- **Who can answer.** Anything that can `hc send` into the prompt terminal,
  which again means a process running as you, and it still needs the
  password.

Gotchas the mod handles (keep them if you edit it):

- **Role from `props()`.** The dialog's bar is this mod too. A copy that
  takes its role from `init`'s argument doesn't see `{bar: true}`, watches
  as well, and opens a dialog per dialog. Only a copy outside any overlay
  watches.
- **No `pane.focus`.** A terminal in an overlay isn't a pane: `pane.focus
  {terminal}` fails with "no such pane" and posts a toast. The dialog takes
  the keyboard by itself.
- **One dialog per prompt per window.** Each dialog's bar beats in
  `shared("herdr-askpass.shown")` (prompt address → ms) every second and
  drops its entry when its dialog goes. The watcher opens a dialog for a live
  prompt with no fresh beat (3.5 s), unless it opened one in the last 2.5 s.
  So a reloaded watcher (a saved mod file, a layout switch) doesn't stack a
  second dialog, and a dialog closed while its prompt is live
  (`overlay.close`) comes back. After Cancel the entry is left to go stale,
  so no dialog flashes back while `terminals()` still lists the killed
  prompt.
- **Stale prompts.** `terminals()` can still list a prompt that just ended,
  and a dialog whose terminal is already gone never sees it end (it shows
  `terminal.attach: no terminal`). The watcher checks again just before it
  opens a dialog, and the bar closes its own dialog after its terminal has
  been missing for two checks in a row (one can be a reconnect's gap).
- **Notice on a timer too.** New prompts are noticed in `render()` and every
  250 ms, so a window that isn't being drawn still opens the dialog and
  plays the sound.

Testing:

- Without sudo: run `herdr-askpass` in an hc terminal, find the new terminal
  whose `hc get` labels include `herdr-askpass=1` (`hc ls --json` lists no
  labels), and answer with `hc send <t> <text>` or `hc keys <t> esc`. The
  text comes back on stdout. A window with the mod shows the dialog meanwhile,
  and `herdr-app status` lists it as a `layout` overlay. Send keys one at a
  time with `hc keys` and `hc read` the prompt to check nothing is echoed;
  SIGKILL the askpass and the prompt should end within a second.
- With a terminal: `printf 'pw\n' | script -q /dev/null herdr-askpass` asks
  on the pty and prints `pw`.
- With sudo: `SUDO_ASKPASS=… DISPLAY=x sudo -k /usr/bin/id -u` from an
  agent prints `0` once you answer.

Applying it: `nrs` installs it and restows the mod. Then give the agent
both variables and restart it. For Claude Code, in `~/.claude/settings.json`:
`"env": {"DISPLAY": "herdr-askpass", "SUDO_ASKPASS":
"/run/current-system/sw/bin/herdr-askpass"}`. `DISPLAY` only has to be
non-empty. Each viewing machine needs the mod, which means the dotfiles
checkout and a restow there.

## The markdown viewer (`herdr-md`)

[ryanthedev/herdr-md](https://github.com/ryanthedev/herdr-md) is a Herdr mod
that shows a markdown file as native elements (text, code, tables, images,
video, typeset math, Mermaid), with vim keys and a file picker. `mdh` drives
it from a shell, which is how an agent shows you a file and points at
passages: `mdh open FILE`, `mdh hl FILE --lines 40-52 --note …`, and
`mdh sel` for what you pinned back (`V`, move, `p`). `mdh --help` lists
the rest, and `?` in a viewer lists its keys. A viewer exists only where
something opens one: `mdh`, or a keys.json binding of `pane.split` with
`"mod": "herdr-md"` (`"props": {"pick": true}` starts in the picker).

Upstream installs by copying a folder into `~/.config/herdr-app/mods`, and
the mod then runs `npm install` for its figure renderer. `pkgs/herdr-md.nix`
pins both instead: the repo at a commit (`fetchFromGitHub`) and the
renderer's npm dependencies from upstream's lock file (`fetchNpmDeps`).
On top of that:

- **`herdr-md-linux.patch`.** Upstream is built and tested on macOS. The
  patch gives each Mac tool a Linux counterpart, chosen by the window's
  platform (image sizes from ffprobe, the app clipboard, xdg-open), finds the
  Mermaid browser on PATH, and makes the key help show the keys keys.json
  really binds to the picker.
- **One `main.js`.** A mod can only be JavaScript that Herdr's own engine
  loads, and Herdr refuses an import that resolves outside the mod's folder,
  which a link into the store does. `main.js` itself may be a link (every
  stowed mod's is). So `bun build` joins the mod's eight modules into one
  file with nothing left to import but Herdr's own modules.
- **One `render.js`, run by bun.** What a mod runs can be anything. The
  figure renderer (MathJax, mermaid-cli, puppeteer: 838 modules, 430 MB of
  `node_modules`) is bundled into one 6 MB file, and the mod runs it with
  bun, both by store path. mermaid-cli has the browser load a page and two
  scripts from beside its own source; those are installed as
  `libexec/herdr-md/mermaid` and its three lookups point there. Node is only
  in the build, to unpack the dependencies, and `disallowedReferences` keeps
  it out of the closure. The whole package is 22 MB.
- **Pinned helpers.** `mdh` runs a pinned python3. ffmpeg and ffprobe (video
  frames; image sizes on Linux) fall back to a pinned build when PATH has
  none. Mermaid needs a Chromium-family browser on PATH or in `CHROME_PATH`
  (nebula: helium); none is pinned, and without one diagrams show their
  source.

`programs.herdr-md.enable` puts `mdh` on PATH and installs the mod for
each of `programs.herdr-core.users`. `~/.config/herdr-app/mods/herdr-md`
stays a real folder owned by the user, because Herdr writes its typings into
every mod folder and the mod keeps its cache there (`.cache`). The modules
link the package's entries into it one by one (`main.js`, `mdh`,
`mod.json`: the package's `modFiles`). A copy installed by hand has those
three replaced; delete its other files (the separate modules, `render/`).

To update, set `rev`, the date in `version` and the two hashes in
`pkgs/herdr-md.nix`. The build fails if the patch or a substitution no
longer applies, or if upstream ships a file nothing places. Its checks run
upstream's tests on the patched source and render a formula with the
installed renderer. The sandbox has no browser, so draw one Mermaid diagram
by hand afterwards, and run `herdr-app check ~/.config/herdr-app/mods/herdr-md`
after the switch.

## Config files and stow

Each file option defaults to `null`, and then the module leaves the file
alone, so a dotfiles repo can link it in and version it. Herdr's saves write
through symlinks: upstream `src/persist.rs` resolves the link and renames onto
its target, and has tests for exactly that. So a linked `settings.json`,
`keys.json` or layout collects the app's own edits. The core never writes
`config.toml`.

| File (under `~/.config`) | Written by | Module option |
|---|---|---|
| `herdr-core/config.toml` | you only | `programs.herdr-core.settings` → read-only store link |
| `herdr-app/settings.json` | the app (Settings screen, zoom) | `programs.herdr-app.settings` → merged in at each launch (Linux) or each activation (macOS, with `telemetry` and `core`), declared keys win |
| `herdr-app/keys.json` | you; the app writes the defaults if it's missing | `programs.herdr-app.keys` → read-only store link |
| `herdr-app/{themes,layouts,mods}/…` | you, or the app when you duplicate/save one | — |
| `herdr-app/mods/herdr-md/{main.js,mdh,mod.json}` | nobody | `programs.herdr-md.enable` → read-only store links in a real folder (the mod's `.cache` and Herdr's typings sit beside them) |
| `herdr-app/` everything else | the app (shipped mods, `view.json`, telemetry state…) | — |
| `herdr/config.toml` (the TUI) | you | — |

Store links go to each of `programs.herdr-core.users` and replace whatever
is there. On NixOS that's `systemd-tmpfiles` `L+`; on nix-darwin it's
`ln -sfn` from the activation script.

## Updating and upgrade notices

```sh
bun flakes/herdr/update.ts           # rewrite sources.json from upstream's manifests
bun flakes/herdr/update.ts --check   # exit 10 if behind
```

`update.ts` reads `releases.herdr.dev/{core,app}/latest.json`, the manifests
upstream's installers read (there are no GitHub releases, only tags). It
converts their sha256s to SRI, and it refuses a pair where the app's
`core_min` is newer than the core. The relative-path input isn't hash-locked,
so after a rebuild the new pins are live. The TUI moves when you repoint
`herdr-cli.url`.

`herdr-update-check` reports two things:

- **Releases newer than ours:** the fork against GitHub's `releases/latest`
  (prereleases skipped), and the core and app against the manifests.
- **Stale running builds:** a herdr server, core or window older than the
  installed version. A rebuild swaps store paths, not processes. Stop the
  herdr server with `herdr server stop`; move the core with
  `hc server restart`, which keeps your terminals; reopen the window.

Run plain, it prints what's pending and exits 10. With `--notify` it raises
a notification. On Linux that's notify-send with a button per release, after
waiting for a notification daemon. On macOS it's osascript, which has no
buttons. With `--json` it prints one object for programs to read and exits
0: `installed` and `latest` versions per product, and `updates`, each with a
`kind` (`release`, or `running` for a stale process), `from`, `to`, the
changelog or release `url` and the `action` to take (the header of
`pkgs/herdr-update-check.sh` has the shape). The `herdr-updates` mod in the
dotfiles' Herdr layout draws it in the tab bar.

`services.herdr-update-check.enable` schedules it: a `Type=exec` systemd user
unit (see the comment there for why not oneshot), or a launchd agent. Both,
and the copy on PATH, run `finalPackage`: the package with the configured
programs' versions set (`environment`), so a hand run or a `--json` read
compares against what the modules installed rather than this flake's pins.

## darwin

Everything works on the macs. Since 0.1.18 herdr-core is upstream's
Developer ID-signed `Herdr Core.app` (`dev.herdr.core`), copied whole into
`$out/libexec` (not `Applications/`: it's a background helper with nothing to
launch from Finder), with `bin/herdr-core` and `bin/hc` linking into it.
macOS credits a terminal program's privacy requests (local network,
microphone) to the core, since the core and its holders disclaim
responsibility, and only an executable inside the bundle carries the usage
descriptions those prompts need. The tarball's bare `herdr-core` is left
out. hc canonicalizes its own path, so the links still find the bundle, and
`hc machine add` packs the whole bundle for another Mac. Grants key on the
signature, so they survive version bumps. Terminals started under a pre-0.1.18
core keep their old privacy context until they're recreated. Herdr is upstream's Developer
ID-signed `Herdr.app`, copied whole into `$out/Applications` with no fixup
(installCheck runs `codesign --verify --deep --strict` on the copy), plus
`bin/herdr-app` into the bundle for the CLI (`herdr-app ls|do|status`).
nix-darwin copies `Applications/` of every system package into
`/Applications/Nix Apps`, where Spotlight finds it. The Linux mechanisms
don't reach a bundle Finder launches, so the darwin module does their work
through files instead:

- **Telemetry and the core pin** are settings.json keys (`telemetry`,
  `core`), merged into each core user's `~/.config/herdr-app/settings.json`
  at activation together with `programs.herdr-app.settings`, declared keys
  winning. The core pin is `/etc/herdr-core/hc` (`environment.etc`), a link to
  `programs.herdr-core.package`: a stable path, so a stowed settings.json in
  a repo doesn't collect store hashes. The Settings screen can flip
  telemetry back on until the next rebuild.
- **Self-update** can't be disarmed by layout (a bundle is always a root),
  and isn't editable out of the bundle (that breaks the signature). It is
  defeated by ownership: the staging folder would go beside the bundle under
  `/Applications/Nix Apps`, which root owns and nix-darwin rsyncs
  (`--delete`) on every switch. A warning in the app's log every 30 minutes,
  once upstream is ahead, is the whole cost; herdr-update-check reports the
  same release once a day.
- **No linger; a one-shot launchd job instead.** Since core 0.1.17
  (herdr-app#294) hc starts the core through launchd, because a plain
  detached process stayed in the app's coalition and quitting Herdr killed
  every agent. hc bootstraps a temporary job into `gui/<uid>`, hands the new
  core its own environment over a socket (so the core pin and
  `HERDR_TELEMETRY` still reach every terminal), then boots the job out and
  deletes the plist. Nothing lands in `~/Library/LaunchAgents`, and no store
  path outlives a garbage collection. A core reached over SSH, or one whose
  launchd start fails, still starts as a detached process.
- **The CLI link.** On first launch the app symlinks `~/.local/bin/herdr-app`
  to the bundle's binary (upstream `src/core_bin/cli_link.rs`), unless
  something else is there. It points at nix-darwin's copy, which the next
  switch replaces in place, so it stays current.
- **Stale running builds**: a process started through a symlink (`hc` on
  PATH, `/etc/herdr-core/hc`) names the link in its argv, so on macOS the
  check asks `lsof` for the executable's store path, which for the core is
  inside the bundle (`libexec/Herdr Core.app/Contents/MacOS/herdr-core`). A
  core started through launchd keeps `--hc-launchd <socket>` as its argv, not
  `serve`, and the check matches both. A window opened from
  Finder runs the copy under `/Applications/Nix Apps`, which carries no
  version, so only a window opened as `bin/herdr-app` from a shell is judged.
- **Never run a bundle at build time.** Executing a signed bundle's binary
  makes macOS stamp the bundle with `com.apple.macl`, which the nix daemon
  can't strip (App Management protection, macOS 26; granting the daemon App
  Management didn't help). The output then fails to register with
  `clearing flags of path "…/Herdr Core.app": Operation not permitted`. So
  on darwin both packages skip `versionCheckHook` and check the version by
  reading `CFBundleShortVersionString` from the bundle's `Info.plist`, next to
  the `codesign --verify`. Linux keeps the `--version` check.

The macs' enables live in `modules/darwin/herdr.nix` (one user, one setup);
their config files come from the same `home/herdr-core` and `home/herdr-app`
stow packages as nebula's, so `keys.json` binds ctrl/alt there too, not cmd.
Only `settings.json` is per-OS (`home/herdr-app-darwin`, nebula's
`home/herdr-app-linux`), and `home/herdr-app` stow-ignores it.

## Files

- `flake.nix`: inputs, including the fork's rationale, and outputs
- `sources.json` + `update.ts`: core and app pins
- `pkgs/`:
  - `herdr-cli.nix`, `herdr-nav.{nix,sh}`
  - `herdr-core.nix`, `herdr-app.nix` (the repacks)
  - `herdr-app-wrap.nix` (the Linux telemetry and settings wrapper),
    `herdr-app-merge-settings.nix` + `merge-settings.sh` (the settings merge
    it and the darwin module share)
  - `herdr-update-check.{nix,sh}`
  - `herdr-open.{nix,sh}` (its Herdr half: `home/herdr-app/.config/herdr-app/mods/herdr-open`)
  - `herdr-askpass.{nix,sh}` (its Herdr half: `home/herdr-app/.config/herdr-app/mods/herdr-askpass`)
  - `herdr-md.nix`, `herdr-md-linux.patch` (the markdown viewer mod and `mdh`)
- `modules/`: `common.nix`, `nixos.nix`, `darwin.nix`
- `tests/herdr-open-mod.test.ts`: the herdr-open mod against simulated windows
