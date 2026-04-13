if (-not (Get-Module -ListAvailable -Name NerdFonts)) {
    try {
        Install-Module -Name NerdFonts -Scope CurrentUser -Force -AcceptLicense -ErrorAction Stop
    } catch {
        Write-Warning "Failed to install NerdFonts module: $_"
    }
}
Import-Module NerdFonts -ErrorAction SilentlyContinue
