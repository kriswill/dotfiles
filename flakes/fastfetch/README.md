# fastfetch

nixpkgs' [fastfetch](https://github.com/fastfetch-cli/fastfetch), wrapped. The
wrapper adds two things and builds nothing else:

- **A logo picked at build time.** `--logo "$HOME/.config/fastfetch/<file>"`
  beats `config.jsonc`'s `source`, so each host names its image in Nix while
  the logo type and the render box stay in the user's own `config.jsonc`.
- **A `kitten` shim**, first on fastfetch's PATH and nobody else's. Without
  it the `kitty-icat` logo draws nothing in a Herdr pane.

The images and `config.jsonc` are not in here. They live in
`~/.config/fastfetch/`, however the user puts them there (in the dotfiles
repo this came from: the `home/fastfetch` stow package).

## Outputs

| Output | What |
|---|---|
| `packages.fastfetch` (`default`) | the wrapped fastfetch with no logo chosen: `config.jsonc` decides, and the shim is the only addition |
| `packages.kitten-shim` | the shim alone, a `bin/kitten` |
| `checks.kitten-shim` | the shim against a stand-in kitten |
| `nixosModules.fastfetch` (`default`) | `programs.fastfetch.{logo,logoPaddingTop,finalPackage}` |
| `darwinModules.fastfetch` (`default`) | the same module, the same file |

Systems: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`.

`package.nix` takes `logo` (a filename under `~/.config/fastfetch/`, or
`null`) and `paddingTop`, so a logo can also be chosen with
`.override { logo = "Nebula.png"; }`.

## Why the shim

fastfetch's `kitty-icat` logo runs
`kitten icat -n --align=left --place=<w>x<h>@<x>x<y> --scale-up <file>`, and
no option changes those arguments. In a herdr-core terminal (`hc`, the Herdr
app) they fail in two ways.

- **A plain pane shows the ASCII logo.** The pty reports no pixel size
  (`TIOCGWINSZ` gives rows and columns, zero pixels:
  [herdr-app#81](https://github.com/herdrdev/herdr-app/issues/81)). kitten
  reads nothing else and quits. The terminal does answer `CSI 14 t` with the
  right size.
- **`devenv shell` shows an empty box.** devenv's own terminal layer gives
  its inner pty a pixel size, so kitten runs, detects a transfer method, is
  told files work, and hands the image over as a path under `/dev/shm`. Herdr
  refuses file media
  ([herdr-app#302](https://github.com/herdrdev/herdr-app/issues/302)), and
  fastfetch has already reserved the columns.

For `icat` with `HC_TERMINAL_ID` set, `kitten-shim.sh` asks the terminal for
`CSI 14 t` and runs the real kitten with two more arguments:

```
--transfer-mode=stream --use-window-size=<cols>,<rows>,<width px>,<height px>
```

Everything else is `exec`ed unchanged: other kitten commands, any call
outside herdr-core, a call with no terminal, and a terminal that hasn't
answered within 0.3 s. Streaming also means kitten sends no detection
queries, whose replies Herdr sends late and more than once
([herdr-app#533](https://github.com/herdrdev/herdr-app/issues/533)); the
extra reply would land in the shell as typed text.

The real kitten is not pinned. The shim runs the next `kitten` on PATH that
isn't itself, so each machine keeps the one it already has, and a machine
without one fails as it did before (exit 127, and fastfetch falls back to
ASCII). Nothing here installs kitten.

Two things to know:

- A terminal no window is showing still answers `CSI 14 t` (with a default
  10×20 cell), so the logo is sent into it too.
- Only fastfetch gets the shim. A bare `kitten icat` in a Herdr pane still
  fails on the pixel size.

The shim can go when Herdr no longer needs it: `--use-window-size` once the
pty's pixel fields are filled
([herdr-core#217](https://github.com/herdrdev/herdr-core/pull/217)),
`--transfer-mode=stream` once Herdr accepts file media or answers queries in
order.

## The module

One file, `module.nix`, for NixOS and nix-darwin.

| Option | |
|---|---|
| `programs.fastfetch.logo` | filename under `~/.config/fastfetch/`, or `null` (the default) to leave the logo to `config.jsonc` |
| `programs.fastfetch.logoPaddingTop` | blank rows above the logo, default 0 |
| `programs.fastfetch.finalPackage` | read-only: the wrapped fastfetch |

- **It wraps the host's own `pkgs.fastfetch`**, not this flake's package, so
  the fastfetch underneath is the one the rest of the system has, overlays
  included, and no second nixpkgs enters the closure.
- **It installs nothing.** Put `finalPackage` where the system's fastfetch
  comes from:

  ```nix
  # nix-darwin, or a NixOS with nothing else installing fastfetch
  environment.systemPackages = [ config.programs.fastfetch.finalPackage ];

  # a NixOS whose own module already installs fastfetch from a `package` option
  programs.fastfetch.package = config.programs.fastfetch.finalPackage;
  ```

- **It declares no `enable` or `package`**, so it can share
  `programs.fastfetch` with a module that owns those names.

## Tests

```sh
nix flake check ./flakes/fastfetch     # or: nix build .#checks.<system>.kitten-shim -L
```

`tests/kitten-shim.sh` runs the shim with a stand-in `kitten` that records
its arguments: what passes through untouched, the missing-kitten exit, a link
to the shim earlier on PATH, and, on Linux, three terminals made with
`script(1)`: one that answers with a size, one that answers something else,
and one that says nothing. The last is the case that once hung. bash's
`read -d` puts the terminal in blocking mode, which undid the `stty` timeout
the shim then relied on; the wait is `read -t` now.

It needs the build sandbox, which has no controlling terminal. What it can't
show is the image on screen. For that, run fastfetch in a real Herdr pane and
take the app's frame (`herdr-app shot`).

## Files

| File | |
|---|---|
| `package.nix` | the wrapper: `symlinkJoin` + `wrapProgram` |
| `kitten-shim.nix`, `kitten-shim.sh` | the shim (`writeShellApplication`, so ShellCheck runs at build) |
| `module.nix` | the module for both OSes |
| `tests/kitten-shim.sh` | the check |

## Consuming it

As a relative-path input, following the parent's nixpkgs and flake-parts:

```nix
inputs.fastfetch = {
  url = "./flakes/fastfetch";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-parts.follows = "flake-parts";
};
```

Import `inputs.fastfetch.nixosModules.fastfetch` or
`inputs.fastfetch.darwinModules.fastfetch`, set `programs.fastfetch.logo`,
and install `finalPackage` as above. Moving this directory to its own
repository later changes only the `url`.
