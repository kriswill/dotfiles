#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap this machine's Windows config from the dotfiles repo.

.DESCRIPTION
    Symlinks profile/terminal/git config from this repo into their expected
    Windows locations. Backs up any pre-existing file to <path>.bak-<timestamp>
    before replacing. Optionally installs apps from scoop/winget export files.

    Run from an elevated PowerShell OR enable Developer Mode
    (Settings -> Privacy & security -> For developers) so New-Item -SymbolicLink
    works without admin.

.PARAMETER InstallApps
    Also run `scoop import` and `winget import` from the exported lists.

.PARAMETER DotfilesRoot
    Path to the dotfiles checkout. Defaults to the parent of this script.
#>
[CmdletBinding()]
param(
    [switch]$InstallApps,
    [string]$DotfilesRoot = (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$WindowsDir = Join-Path $DotfilesRoot 'windows'
if (-not (Test-Path $WindowsDir)) {
    throw "Expected windows/ dir at $WindowsDir"
}

function New-Symlink {
    param(
        [Parameter(Mandatory)][string]$LinkPath,
        [Parameter(Mandatory)][string]$TargetPath
    )

    if (-not (Test-Path $TargetPath)) {
        Write-Warning "Skip: target missing $TargetPath"
        return
    }

    $parent = Split-Path -Parent $LinkPath
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (Test-Path $LinkPath) {
        $item = Get-Item $LinkPath -Force
        if ($item.LinkType -eq 'SymbolicLink' -and $item.Target -contains $TargetPath) {
            Write-Host "OK    $LinkPath -> $TargetPath" -ForegroundColor Green
            return
        }
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backup = "$LinkPath.bak-$stamp"
        Write-Host "Backup $LinkPath -> $backup" -ForegroundColor Yellow
        Move-Item -Path $LinkPath -Destination $backup -Force
    }

    New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath | Out-Null
    Write-Host "Link  $LinkPath -> $TargetPath" -ForegroundColor Cyan
}

# --- PowerShell profile (pwsh 7 and Windows PowerShell 5.1 share the same file) ---
$profileSource = Join-Path $WindowsDir 'powershell\Microsoft.PowerShell_profile.ps1'
$profileTargets = @(
    "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1",
    "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "$HOME\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1",
    "$HOME\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
)
foreach ($t in $profileTargets) {
    if (Test-Path (Split-Path -Parent $t)) {
        New-Symlink -LinkPath $t -TargetPath $profileSource
    }
}

# --- PowerShell custom modules (KrisTools, etc.) ---
# Link each module dir into the user's per-host Modules path. Both pwsh 7
# and Windows PowerShell 5.1 auto-discover modules placed there.
$moduleSource = Join-Path $WindowsDir 'powershell\Modules'
if (Test-Path $moduleSource) {
    $moduleTargets = @(
        "$HOME\Documents\PowerShell\Modules",
        "$HOME\Documents\WindowsPowerShell\Modules",
        "$HOME\OneDrive\Documents\PowerShell\Modules",
        "$HOME\OneDrive\Documents\WindowsPowerShell\Modules"
    )
    foreach ($modDir in (Get-ChildItem -Directory $moduleSource)) {
        foreach ($base in $moduleTargets) {
            if (Test-Path (Split-Path -Parent $base)) {
                New-Symlink -LinkPath (Join-Path $base $modDir.Name) -TargetPath $modDir.FullName
            }
        }
    }
}

# --- Windows Terminal ---
$wtSource = Join-Path $WindowsDir 'windows-terminal\settings.json'
$wtTarget = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path (Split-Path -Parent $wtTarget)) {
    New-Symlink -LinkPath $wtTarget -TargetPath $wtSource
}

# --- Git ---
New-Symlink -LinkPath "$HOME\.gitconfig"          -TargetPath (Join-Path $WindowsDir 'git\.gitconfig')
New-Symlink -LinkPath "$HOME\.config\git\ignore"  -TargetPath (Join-Path $WindowsDir 'git\ignore')

# --- Scoop config ---
New-Symlink -LinkPath "$HOME\.config\scoop\config.json" -TargetPath (Join-Path $WindowsDir 'scoop\config.json')

# --- Shared (cross-platform) configs from repo root ---
# Neovim, tmux, etc. live at repo root under config/ on main.
$nvimSource = Join-Path $DotfilesRoot 'config\nvim'
if (Test-Path $nvimSource) {
    New-Symlink -LinkPath "$env:LOCALAPPDATA\nvim" -TargetPath $nvimSource
}

if ($InstallApps) {
    $scoopApps = Join-Path $WindowsDir 'scoop\apps.json'
    if ((Get-Command scoop -ErrorAction SilentlyContinue) -and (Test-Path $scoopApps)) {
        Write-Host "scoop import $scoopApps" -ForegroundColor Cyan
        scoop import $scoopApps
    }

    $wingetApps = Join-Path $WindowsDir 'winget\apps.json'
    if ((Get-Command winget -ErrorAction SilentlyContinue) -and (Test-Path $wingetApps)) {
        Write-Host "winget import $wingetApps" -ForegroundColor Cyan
        winget import -i $wingetApps --accept-package-agreements --accept-source-agreements
    }
}

Write-Host "`nDone." -ForegroundColor Green
