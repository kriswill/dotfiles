$Public = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)

foreach ($file in $Public) {
    . $file.FullName
}

Export-ModuleMember -Function $Public.BaseName -Alias *
