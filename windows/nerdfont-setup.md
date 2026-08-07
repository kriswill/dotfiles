# Nerd Font setup on Windows (PowerShell only)

End state: PowerShell 7 installed, `JetBrainsMono Nerd Font` installed, Windows Terminal using it as default with a PowerShell 7 profile as default.

## 1. Install PowerShell 7

From **Windows PowerShell 5.1** (run as your user, not admin):

```powershell
winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements
```

Alternative if you use scoop:

```powershell
scoop install pwsh
```

Close this shell. Everything from here on runs in **pwsh** (PowerShell 7).

## 2. Launch pwsh and bootstrap PSGallery

Open a new `pwsh` session:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```

Notes:
- The `NerdFonts` module uses PowerShell 7.3+ syntax (`clean {}` block). It will **not** load under Windows PowerShell 5.1 despite what its manifest claims. That's why step 1 installs pwsh first.

## 3. Install the NerdFonts module

```powershell
Install-Module -Name NerdFonts -Scope CurrentUser -Force
Import-Module NerdFonts
Get-Command -Module NerdFonts   # should show Get-NerdFont, Install-NerdFont
```

## 4. Install JetBrainsMono Nerd Font

```powershell
Get-NerdFont | Where-Object Name -like 'JetBrains*'   # confirm name
Install-NerdFont -Name 'JetBrainsMono'
```

Use `-Scope AllUsers` (admin required) to install system-wide instead of per-user. Verify:

```powershell
(New-Object System.Drawing.Text.InstalledFontCollection).Families |
    Where-Object Name -like '*JetBrains*'
```

You should see `JetBrainsMono Nerd Font` (and possibly `JetBrainsMono Nerd Font Mono`, `…Propo`).

## 5. Auto-import on future sessions (optional)

Create the pwsh profile:

```powershell
New-Item -ItemType File -Path $PROFILE -Force
@'
if (-not (Get-Module -ListAvailable -Name NerdFonts)) {
    Install-Module -Name NerdFonts -Scope CurrentUser -Force -ErrorAction SilentlyContinue
}
Import-Module NerdFonts -ErrorAction SilentlyContinue
'@ | Set-Content -Path $PROFILE -Encoding UTF8
```

## 6. Configure Windows Terminal

Locate settings.json:

```powershell
$wtSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
```

Open it in your editor and:

**a.** Set the font for all profiles — add a `font.face` entry inside `profiles.defaults`:

```json
"defaults": {
    "font": { "face": "JetBrainsMono Nerd Font" }
}
```

**b.** Add a PowerShell 7 profile to `profiles.list` (adjust `commandline` if pwsh is not on PATH — e.g. scoop installs at `%USERPROFILE%\scoop\apps\pwsh\current\pwsh.exe`):

```json
{
    "guid": "{2d8e4a3f-7c91-4e5b-a6f2-8b1c5d9e3a7b}",
    "name": "PowerShell 7",
    "commandline": "pwsh.exe -NoLogo",
    "startingDirectory": "%USERPROFILE%",
    "hidden": false
}
```

Generate your own GUID with `[guid]::NewGuid()` if you prefer.

**c.** Set it as default — change the top-level `defaultProfile` to match the GUID above:

```json
"defaultProfile": "{2d8e4a3f-7c91-4e5b-a6f2-8b1c5d9e3a7b}"
```

Open a new Windows Terminal tab — it should launch pwsh 7 with JetBrainsMono Nerd Font.

## Troubleshooting

- **`Get-NerdFont` not found** — module didn't install. Re-run step 2, then `Install-Module NerdFonts -Force -Verbose` and read the error.
- **Font not showing in Terminal** — face name mismatch. Run the `InstalledFontCollection` check above and use the exact `Name` value.
- **`clean {}` parser error** — you're in Windows PowerShell 5.1. Switch to pwsh.
- **OneDrive-redirected Documents** — `$PROFILE` will resolve to `…\OneDrive\Documents\PowerShell\…`. That's fine; `Install-Module` installs to `…\Documents\PowerShell\Modules\` (same root), so pwsh finds it.
