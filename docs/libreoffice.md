# LibreOffice on nebula — dark theme & XDG paths

Two LibreOffice problems were fixed on this host, each with a small auto-imported
NixOS module under `nixosModules/default/`:

| Module / package | Problem it solves |
|------------------|-------------------|
| `nixosModules/default/gtk-dark.nix` (+ `home/gtk/`) | LibreOffice (and other GTK apps) ignored the selected dark theme and rendered light. |
| `nixosModules/default/libreoffice-paths.nix` | LibreOffice wrote generated data (backups, templates, gallery, …) *inside* `~/.config` instead of the XDG `~/.local` trees. |

Both are user-layer fixes — **no `libreoffice` package override, no overlay, no
recompile**.

---

## 1. Dark theme — `gtk-dark.nix`

### Why
In Tools → Options → LibreOffice → Appearance the theme was set to **Dark** and
"Enable application theming" was on, yet the whole UI (and the document canvas)
rendered light.

### Root cause
- LibreOffice uses the **gtk3** VCL plugin (`vclplug_gtk3lo.so`), which delegates
  dark-mode detection to GTK.
- niri is a standalone Wayland compositor with **no settings daemon and no running
  `xdg-desktop-portal`** to broadcast a `color-scheme = prefer-dark` preference,
  and no GTK theme was configured. So GTK reported "light" and the gtk3 plugin
  overrode LibreOffice's own Dark theme back to light.
- The `gtk-application-prefer-dark-theme` hint (a `settings.ini` key) was **not
  enough** on NixOS — there is no separate `Adwaita-dark` theme directory for that
  hint to resolve to.

### Fix
Select Adwaita's dark variant explicitly — it is compiled into GTK itself, so it
always works — via a session variable:

```nix
# nixosModules/default/gtk-dark.nix
{ environment.sessionVariables.GTK_THEME = "Adwaita:dark"; }
```

`home/gtk/.config/gtk-3.0/settings.ini` and `gtk-4.0/settings.ini` also set
`gtk-application-prefer-dark-theme = true` as a supplementary hint (stow-managed,
auto-deployed by `dotfiles-stow.nix`).

> **Takes effect after a re-login** — session variables are read when the
> graphical session starts.

### How it was found
A throwaway LibreOffice instance launched with `GTK_THEME=Adwaita:dark` came up
dark, while the `settings.ini` hint alone did not — pinpointing the env var as
the reliable lever.

---

## 2. XDG paths — `libreoffice-paths.nix`

### Why
LibreOffice roots its writable paths at `$(userurl)`, i.e. inside the profile
`~/.config/libreoffice/4/user/<name>`. So **data** (backups, templates, gallery,
autotext, autocorrect, the user dictionary, the image dir, document themes) lived
under `~/.config`. Desired split: **settings** stay in `~/.config` (the profile),
**data/state** moves to the XDG `~/.local` trees.

Target mapping (all eight user-writable paths):

| Dialog row | New location |
|------------|--------------|
| Backups | `~/.local/state/libreoffice/backup` |
| AutoCorrect / AutoText / Gallery / Templates / Images | `~/.local/share/libreoffice/{autocorr,autotext,gallery,template,images}` |
| Dictionaries / Document Theme | `~/.local/share/libreoffice/{wordbook,themes}` |

(Backups are regenerable recovery *state* → `~/.local/state`; the rest are user
*data* → `~/.local/share`. `Temp` stays `/tmp`, `My Documents` stays `~/Documents`,
`Classification` stays on the read-only install share.)

### The trap (why the obvious fix didn't work)
LibreOffice's path config lives in `org.openoffice.Office.Paths/Paths/<name>`,
each node having `WritePath` (where new files go) and `UserPaths` (a searched
list). Overriding `WritePath` to `~/.local` correctly redirected *writes*, **but
the Tools → Options → Paths dialog still showed the old `~/.config` path** — as a
duplicate for multi-path types, and Backup ignored the override entirely. Setting
`UserPaths` (with `oor:op="fuse"` *or* `"replace"`) did not remove it either.

### Root cause (found by reading the LibreOffice source)
From `framework/source/services/pathsettings.cxx` and
`cui/source/options/optpath.cxx`:

1. The dialog's **"User Paths" column = `UserPaths` list + `";"` + `WritePath`**
   (`SvxPathTabPage::Reset`).
2. `PathSettings` merges a **legacy config node** on top of the modern one —
   `org.openoffice.Office.Common/Path/Current/<name>` — in
   `impl_mergeOldUserPaths`. That legacy node *still ships* `$(userurl)/<name>`
   as a default, and the merge:
   - **multi-path** (Template/AutoText/Gallery/AutoCorrect): **pushes** it into the
     `UserPaths` list → the stale `~/.config` entry;
   - **single-path** (Backup, Graphic): **overwrites** `WritePath` with it → why
     Backup ignored the modern override completely.
   - **Dictionary** was already clean precisely because *its* legacy default is
     internal-only (`$(insturl)/wordbook`), no `$(userurl)`.
3. Two helpful behaviors make the fix possible: the merge **skips** a legacy value
   that already equals `WritePath`, and `PathSettings` **drops** `WritePath` from
   the `UserPaths` list before display.

### Fix
Set **both** the modern `WritePath` **and** the legacy
`Common/Path/Current/<name>` to the same XDG URL. Then the legacy value matches
WritePath → the merge skips it → `UserPaths` ends up empty → the row shows only
the XDG path.

Per path the module emits:
- **modern** `…/Paths/Paths/<name>` → `WritePath` (always); plus `UserPaths`
  (== WritePath, so it's dropped) only for **Template**, which is the one node
  that ships a modern `UserPaths` default on unix;
- **legacy** `…/Common/Path/Current/<name>` → same URL (a plain string for the
  single-path Backup/Graphic, a `<value><it>…</it></value>` list otherwise) for
  every path whose legacy default contains `$(userurl)` (i.e. all but Dictionary
  and DocumentTheme, whose legacy defaults are internal-only).

### How it's deployed
`registrymodifications.xcu` is the only writable layer in LibreOffice's
`CONFIGURATION_LAYERS` (without wrapping the package), so the module **seeds the
overrides into it** — mirroring the `dotfiles-stow.nix` "make the live home match
the repo" idiom:

- `systemd.tmpfiles.rules` pre-creates the `~/.local/...` target dirs (owned by
  the user).
- A `system.activationScripts` snippet idempotently inserts the `<item>`s into
  `~/.config/libreoffice/4/user/registrymodifications.xcu`:
  - skips if `soffice.bin` is running (LibreOffice rewrites the file on exit and
    would clobber the edit);
  - skips if already seeded (greps a sentinel `oor:path` that survives LibreOffice's
    normalize/rewrite — a comment marker would be stripped);
  - otherwise creates the file (fresh profile) or inserts before `</oor:items>`.

The exact `<item>` XML was verified to round-trip through a real `soffice` launch:
configmgr accepts valid entries and re-serialises them, **silently dropping
invalid `oor:path`s — so survival == correctness**.

---

## Tools used to figure it out

- **LibreOffice source clone** (`~/src/libreoffice/core`) — the decisive ground
  truth. Key files:
  - `framework/source/services/pathsettings.cxx` — `impl_mergeOldUserPaths`,
    `impl_readOldFormat` (revealed the legacy `Common/Path/Current` node).
  - `cui/source/options/optpath.cxx` — `SvxPathTabPage::Reset` / `GetPathList`
    (revealed the display = `UserPaths;WritePath`).
  - `officecfg/registry/{schema,data}/org/openoffice/Office/{Paths,Common}.{xcs,xcu}`
    — the shipped defaults (which nodes pin `$(userurl)`, single vs multi-path).
- **`grim`** — screenshots of the right monitor / Paths dialog (`grim -o DP-2`,
  and `-g "<geom>"` crops).
- **`niri msg outputs` / `niri msg windows`** — locate the monitor (`DP-2`) and
  the `libreoffice-calc` window.
- **`wtype`** (run on demand via `nix run nixpkgs#wtype`) — drove the GUI to open
  and screenshot the Paths dialog for verification: `Alt`+`F12` opens Options
  focused in the search box, type `paths`, `Enter`.
- **Round-trip validation** — launch `soffice`, let it normalize/validate
  `registrymodifications.xcu`, read it back; durable entries == accepted config.
- **`nix run nixpkgs#libxml2 -c xmllint --noout`** — well-formedness check on the
  edited profile before launching LibreOffice.
- **`nix eval` / `nixos-rebuild build`** — typecheck the module and confirm the
  generated `<item>`s.
- An **Explore subagent** to fan out across the large LibreOffice source tree.

## Gotchas worth remembering

- **`nixos-rebuild` reads the committed git tree.** Run as root (`sudo`) against a
  dirty tree owned by the user, Nix falls back to committed `HEAD` — so modules
  must be **committed** before a `switch`, not merely staged. (A switch from an
  uncommitted tree silently built the old config during development.)
- **LibreOffice owns `registrymodifications.xcu`** and rewrites it from memory on
  exit. Edit it only while LibreOffice is closed; valid entries survive its
  rewrite, comments do not.
- The activation script is **seed-once** (sentinel grep). It will not re-edit an
  already-seeded profile on later rebuilds — intentional, so LibreOffice's own
  edits aren't fought. A fresh profile gets the full correct set.
