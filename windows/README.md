# Windows configuration

Live on the `windows` branch. Branches from `main`, so shared configs under
`config/` (nvim, tmux, etc.) are reusable — `setup.ps1` symlinks them into
their Windows locations.

## Layout

```
windows/
├── powershell/
│   └── Microsoft.PowerShell_profile.ps1   # used by both pwsh 7 and PS 5.1
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
4. Enable symlinks without admin: Settings → Privacy & security → For
   developers → **Developer Mode = On**. (Or run the next step from an
   elevated shell.)
5. Run setup:
   ```powershell
   pwsh -ExecutionPolicy Bypass -File .\windows\setup.ps1 -InstallApps
   ```

`setup.ps1` backs up any existing file to `<path>.bak-<timestamp>` before
replacing it with a symlink. Safe to re-run.

## Capturing changes back to the repo

Because targets are symlinks, edits made in Windows Terminal / PowerShell
/ `.gitconfig` land directly in the repo — just `git add` + commit.

Refresh app lists after installing something new:

```powershell
scoop export        > windows\scoop\apps.json
winget export -o    windows\winget\apps.json
```
