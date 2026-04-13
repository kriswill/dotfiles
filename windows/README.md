# Windows configuration

Live on the `windows` branch. Branches from `main`, so shared configs under
`config/` (nvim, tmux, etc.) are reusable — `setup.ps1` symlinks them into
their Windows locations.

## Layout

```
windows/
├── powershell/
│   ├── Microsoft.PowerShell_profile.ps1   # used by both pwsh 7 and PS 5.1
│   └── Modules/
│       └── KrisTools/                     # personal cmdlets (see below)
├── windows-terminal/
│   └── settings.json
├── git/
│   ├── .gitconfig
│   └── ignore                             # global gitignore
├── scoop/
│   ├── config.json
│   └── apps.json                          # `scoop export`
├── winget/
│   └── apps.json                          # `winget export`
└── setup.ps1
```

## Bootstrap a new machine

1. Install [scoop](https://scoop.sh) and/or ensure winget is present.
2. Install git and pwsh:
   ```powershell
   scoop install git pwsh
   ```
3. Clone:
   ```powershell
   git clone -b windows https://github.com/kriswill/dotfiles "$HOME\src\dotfiles"
   cd "$HOME\src\dotfiles"
   ```
4. Allow symlink creation via **one** of:
   - **Elevated shell** (simplest on a fresh box): right-click Windows
     Terminal / PowerShell → *Run as administrator*. Works from either
     Windows PowerShell 5.1 or pwsh 7 — confirmed working on Win11.
   - **Developer Mode on** (no admin needed per run): Settings → Privacy
     & security → For developers → **Developer Mode = On**.
5. Run setup (from the elevated shell, if you went that route):
   ```powershell
   pwsh -ExecutionPolicy Bypass -File .\windows\setup.ps1 -InstallApps
   ```
   If pwsh isn't installed yet, the script also runs fine under Windows
   PowerShell 5.1:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1 -InstallApps
   ```

`setup.ps1` backs up any existing file to `<path>.bak-<timestamp>` before
replacing it with a symlink. Safe to re-run.

## Custom commands (KrisTools module)

Personal utilities are packaged as a PowerShell module rather than a
`bin/` directory of loose scripts — it's the idiomatic Windows answer:
approved verbs, `Get-Help`, tab completion, in-process invocation, no
`PATHEXT` tricks.

Layout:

```
powershell/Modules/KrisTools/
├── KrisTools.psd1                 # manifest
├── KrisTools.psm1                 # loader (dot-sources Public/*.ps1)
└── Public/
    └── Show-DisplayInfo.ps1       # function + Set-Alias display-info
```

`setup.ps1` symlinks the `KrisTools` directory into the user's
`Documents\PowerShell\Modules\` (and the 5.1 and OneDrive-redirected
variants). PowerShell auto-discovers modules on `$env:PSModulePath` so
no config changes are needed beyond `Import-Module KrisTools` in the
profile.

### Adding a new command

1. Create `powershell/Modules/KrisTools/Public/Verb-Noun.ps1` using an
   [approved verb](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands):
   ```powershell
   function Verb-Noun {
       [CmdletBinding()]
       param()
       # ...
   }
   Set-Alias -Name short-name -Value Verb-Noun
   ```
2. That's it — `KrisTools.psm1` auto-loads every `Public\*.ps1` on
   `Import-Module`, and the manifest exports all functions and aliases.
3. Re-run `setup.ps1` only if you added a *new module directory*.

### Current commands

| Command         | Alias          | What it does                       |
| --------------- | -------------- | ---------------------------------- |
| `Show-DisplayInfo` | `display-info` | Styled GPU & monitor report       |

## Related guides

- [nerdfont-setup.md](./nerdfont-setup.md) — install pwsh 7, the
  `NerdFonts` PSGallery module, JetBrainsMono Nerd Font, and wire it into
  Windows Terminal as the default profile + font.

## Capturing changes back to the repo

Because targets are symlinks, edits made in Windows Terminal / PowerShell
/ `.gitconfig` land directly in the repo — just `git add` + commit.

Refresh app lists after installing something new:

```powershell
scoop export        > windows\scoop\apps.json
winget export -o    windows\winget\apps.json
```
