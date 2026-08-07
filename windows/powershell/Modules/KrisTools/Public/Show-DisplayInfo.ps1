function Show-DisplayInfo {
    <#
    .SYNOPSIS
        GPU & monitor configuration report for the current Windows machine.
    .DESCRIPTION
        Renders a styled report using Nerd Font icons. Requires Windows Terminal
        with ANSI support and a Nerd Font (e.g. JetBrainsMono Nerd Font). Pulls
        data from Win32_VideoController, WmiMonitorID, nvidia-smi, the NVIDIA
        registry, and (optionally) ~/dxdiag_report.txt.    .EXAMPLE
        Show-DisplayInfo
    .EXAMPLE
        display-info
    #>
    [CmdletBinding()]
    param()

    # display-info.ps1 - GPU & Monitor Configuration Report
    # Requires: Nerd Font, Windows Terminal with ANSI support
    
    $ESC = [char]27
    
    # -- Color palette -----------------------------------------------------------
    $Reset    = "$ESC[0m"
    $Bold     = "$ESC[1m"
    $Dim      = "$ESC[2m"
    
    $Green    = "$ESC[38;2;118;210;117m"
    $Cyan     = "$ESC[38;2;86;214;214m"
    $Yellow   = "$ESC[38;2;229;192;123m"
    $Orange   = "$ESC[38;2;209;154;102m"
    $Red      = "$ESC[38;2;224;108;117m"
    $Blue     = "$ESC[38;2;97;175;239m"
    $Purple   = "$ESC[38;2;198;120;221m"
    $White    = "$ESC[38;2;220;223;228m"
    $DimWhite = "$ESC[38;2;140;143;148m"
    $NvGreen  = "$ESC[38;2;118;185;0m"
    
    # -- Nerd Font Icons ---------------------------------------------------------
    $IconGpu      = [char]::ConvertFromUtf32(0xF108D)
    $IconMonitor  = [char]::ConvertFromUtf32(0xF0379)
    $IconRefresh  = [char]::ConvertFromUtf32(0xF046B)
    $IconCheck    = [char]::ConvertFromUtf32(0xF05E0)
    $IconDisplay  = [char]::ConvertFromUtf32(0xF0878)
    $IconChip     = [char]0xF2DB
    $IconBolt     = [char]0xF0E7
    $IconPalette  = [char]::ConvertFromUtf32(0xF03D8)
    $IconConnect  = [char]::ConvertFromUtf32(0xF0337)
    $IconInfo     = [char]0xEA74
    $IconWarning  = [char]0xF071
    $IconHdr      = [char]::ConvertFromUtf32(0xF0A60)
    $IconSync     = [char]0xF021
    $IconRotate   = [char]::ConvertFromUtf32(0xF01BB)
    $IconThermo   = [char]0xF2C9
    $IconMem      = [char]::ConvertFromUtf32(0xF035B)
    $IconDriver   = [char]0xF013
    
    # -- Box-drawing characters --------------------------------------------------
    $TL    = [char]0x256D
    $TR    = [char]0x256E
    $BL    = [char]0x2570
    $BR    = [char]0x256F
    $H     = [char]0x2500
    $V     = [char]0x2502
    $LT    = [char]0x251C
    $RT    = [char]0x2524
    $DH    = [char]0x2550
    $DV    = [char]0x2551
    $DTL   = [char]0x2554
    $DTR   = [char]0x2557
    $DBL   = [char]0x255A
    $DBR   = [char]0x255D
    $Deg   = [char]0x00B0
    
    # -- Visual Width Calculation ------------------------------------------------
    # Windows Terminal treats PUA (both BMP U+E000-U+F8FF and supplementary planes
    # 15/16) as Unicode "ambiguous" width, which defaults to narrow = 1 column.
    # So every Nerd Font icon, surrogate pair or not, counts as 1 visual column.
    function Get-VisualWidth([string]$text) {
        $stripped = $text -replace "$([char]27)\[[0-9;]*m", ""
        $w = 0
        $i = 0
        while ($i -lt $stripped.Length) {
            $ch = $stripped[$i]
            if ([char]::IsHighSurrogate($ch) -and ($i + 1) -lt $stripped.Length -and [char]::IsLowSurrogate($stripped[$i + 1])) {
                # One codepoint (surrogate pair) = 1 visual column
                $w += 1
                $i += 2
            } else {
                $w += 1
                $i++
            }
        }
        return $w
    }
    
    function PadTo([string]$text, [int]$targetWidth) {
        $vw = Get-VisualWidth $text
        $pad = $targetWidth - $vw
        if ($pad -lt 0) { $pad = 0 }
        return "$text$(' ' * $pad)"
    }
    
    # -- Box Layout --------------------------------------------------------------
    # Row format: V + space + [icon] + space + [label padded] + [value padded] + V
    # Total visual = 1 + 1 + iconW + 1 + labelTextW + valueW + 1 = W
    
    $W         = 80                    # total box width in columns
    $LabelTextW = 16                   # label text width (without icon)
    
    function BoxRow([string]$icon, [string]$label, [string]$value, [string]$labelColor, [string]$valueColor, [string]$borderColor) {
        $iconW = Get-VisualWidth $icon
        $valW  = $W - $iconW - $LabelTextW - 4   # V+sp+icon+sp+label+value+V = W
        $lbl = PadTo "$labelColor$label$Reset" $LabelTextW
        $val = PadTo "$valueColor$value$Reset" $valW
        return "$borderColor$V$Reset $labelColor$icon$Reset $lbl$val$borderColor$V$Reset"
    }
    
    function SectionHeader([string]$icon, [string]$title, [string]$color) {
        $iconW = Get-VisualWidth $icon
        $contentLen = $iconW + 1 + $title.Length   # icon + space + title
        $leftPad = 2
        $rightPad = $W - 2 - $leftPad - $contentLen - 2  # -2 for spaces around content
        if ($rightPad -lt 0) { $rightPad = 0 }
        return "$color$LT$("$H" * $leftPad)$Reset $Bold$color$icon $title$Reset $color$("$H" * $rightPad)$RT$Reset"
    }
    
    function HBar([string]$left, [string]$right, [string]$color) {
        return "$color$left$("$H" * ($W - 2))$right$Reset"
    }
    
    # -- Data Collection ---------------------------------------------------------
    Write-Host ""
    Write-Host "  $Dim${IconChip} Collecting system display information...$Reset"
    Write-Host ""
    
    # GPU info
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $gpuName = $gpu.Name
    $driverVer = $gpu.DriverVersion
    
    # nvidia-smi data
    $nvData = $null
    try {
        $nvRaw = nvidia-smi --query-gpu=name,driver_version,vbios_version,memory.total,temperature.gpu,power.draw,clocks.current.graphics,clocks.current.memory --format=csv,noheader,nounits 2>$null
        if ($nvRaw) {
            $parts = $nvRaw -split ","
            $nvData = @{
                Name     = $parts[0].Trim()
                Driver   = $parts[1].Trim()
                VBIOS    = $parts[2].Trim()
                VRAM     = $parts[3].Trim()
                Temp     = $parts[4].Trim()
                Power    = $parts[5].Trim()
                ClockGfx = $parts[6].Trim()
                ClockMem = $parts[7].Trim()
            }
        }
    } catch {}
    
    # Monitor info via WMI
    $monitors = @()
    try {
        $monIds = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction Stop
        foreach ($mon in $monIds) {
            $mfr   = ($mon.ManufacturerName | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_}) -join ''
            $model = ($mon.UserFriendlyName | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_}) -join ''
            $serial= ($mon.SerialNumberID   | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_}) -join ''
            $monitors += @{ Manufacturer = $mfr; Model = $model; Serial = $serial }
        }
    } catch {}
    
    # DxDiag data
    $dxPath = Join-Path $env:USERPROFILE "dxdiag_report.txt"
    $dxDisplays = @()
    if (Test-Path $dxPath) {
        $dxContent = Get-Content $dxPath -Raw
        $sections = $dxContent -split "(?=Display Devices)" | Select-Object -Skip 1
        foreach ($section in $sections) {
            $cardName    = if ($section -match "Card name:\s*(.+)")            { $Matches[1].Trim() } else { "Unknown" }
            $currentMode = if ($section -match "Current Mode:\s*(.+)")         { $Matches[1].Trim() } else { "Unknown" }
            $hdrSupport  = if ($section -match "HDR Support:\s*(.+)")          { $Matches[1].Trim() } else { "Unknown" }
            $monName     = if ($section -match "Monitor Model:\s*(.+)")        { $Matches[1].Trim() } else { "Unknown" }
            $outputType  = if ($section -match "Output Type:\s*(.+)")          { $Matches[1].Trim() } else { "Unknown" }
            $dedMem      = if ($section -match "Dedicated Memory:\s*(.+)")     { $Matches[1].Trim() } else { "Unknown" }
            $monCaps     = if ($section -match "Monitor Capabilities:\s*(.+)") { $Matches[1].Trim() } else { "" }
            $dxDisplays += @{
                Card = $cardName; Mode = $currentMode; HDR = $hdrSupport
                MonModel = $monName; Output = $outputType; DedMemory = $dedMem; MonCaps = $monCaps
            }
        }
    }
    
    # G-Sync registry
    $gsyncEnabled = $false
    try {
        $nvTweak = Get-ItemProperty "HKLM:\SOFTWARE\NVIDIA Corporation\Global\NVTweak" -ErrorAction SilentlyContinue
        if ($nvTweak.OverridePRR -eq 1) { $gsyncEnabled = $true }
    } catch {}
    
    # -- Render ------------------------------------------------------------------
    
    # Title banner
    $titleText = "DISPLAY CONFIGURATION REPORT"
    $bannerInner = $W - 2
    $bannerPad = [math]::Floor(($bannerInner - $titleText.Length) / 2)
    $bannerPadR = $bannerInner - $titleText.Length - $bannerPad
    
    Write-Host ""
    Write-Host "  $NvGreen$DTL$("$DH" * $bannerInner)$DTR$Reset"
    Write-Host "  $NvGreen$DV$Reset$(' ' * $bannerPad)$Bold$NvGreen$titleText$Reset$(' ' * $bannerPadR)$NvGreen$DV$Reset"
    Write-Host "  $NvGreen$DBL$("$DH" * $bannerInner)$DBR$Reset"
    Write-Host ""
    
    # -- GPU Section -------------------------------------------------------------
    Write-Host "  $(HBar $TL $TR $Green)"
    Write-Host "  $(SectionHeader $IconChip 'GPU' $Green)"
    Write-Host "  $(HBar $LT $RT $Green)"
    
    $gpuDisplayName = if ($nvData) { $nvData.Name } else { $gpuName }
    Write-Host ("  " + (BoxRow $IconChip   "Card"        $gpuDisplayName $Yellow $White $Green))
    
    $vramText = if ($nvData) { "$($nvData.VRAM) MB GDDR7" } else { "$([math]::Round($gpu.AdapterRAM / 1MB)) MB" }
    Write-Host ("  " + (BoxRow $IconMem    "VRAM"        $vramText $Yellow $White $Green))
    
    $drvText = if ($nvData) { "$($nvData.Driver) ($driverVer)" } else { $driverVer }
    Write-Host ("  " + (BoxRow $IconDriver "Driver"      $drvText $Yellow $White $Green))
    
    if ($nvData) {
        Write-Host ("  " + (BoxRow $IconInfo    "VBIOS"       $nvData.VBIOS $Yellow $DimWhite $Green))
        Write-Host ("  " + (BoxRow $IconThermo  "Temperature" "$($nvData.Temp)${Deg}C" $Yellow $Cyan $Green))
        Write-Host ("  " + (BoxRow $IconBolt    "Power Draw"  "$($nvData.Power) W" $Yellow $Cyan $Green))
        Write-Host ("  " + (BoxRow $IconRefresh "GPU Clock"   "$($nvData.ClockGfx) MHz" $Yellow $Cyan $Green))
        Write-Host ("  " + (BoxRow $IconMem     "Mem Clock"   "$($nvData.ClockMem) MHz" $Yellow $Cyan $Green))
    }
    
    Write-Host "  $(HBar $BL $BR $Green)"
    Write-Host ""
    
    # -- G-Sync Section ----------------------------------------------------------
    Write-Host "  $(HBar $TL $TR $Purple)"
    Write-Host "  $(SectionHeader $IconSync 'G-SYNC / VRR' $Purple)"
    Write-Host "  $(HBar $LT $RT $Purple)"
    
    if ($gsyncEnabled) {
        $gsyncVal = "$Green$IconCheck Enabled$Reset"
    } else {
        $gsyncVal = "$Red$IconWarning Unknown$Reset"
    }
    Write-Host ("  " + (BoxRow $IconSync    "G-Sync"       $gsyncVal $Yellow $White $Purple))
    Write-Host ("  " + (BoxRow $IconDisplay "Mode"         "Windowed + Fullscreen" $Yellow $White $Purple))
    Write-Host ("  " + (BoxRow $IconInfo    "PRR Override" "Active (OverridePRR=1)" $Yellow $DimWhite $Purple))
    
    Write-Host "  $(HBar $BL $BR $Purple)"
    Write-Host ""
    
    # -- Monitor Sections --------------------------------------------------------
    $monitorDefs = @(
        @{
            Label       = "PRIMARY MONITOR"
            Color       = $Cyan
            Rows        = @(
                ,@($IconMonitor, "Model",       "ASUS ROG Swift OLED PG34WCDM",               "$Bold$White")
                ,@($IconDisplay, "Panel",       "34`" W-OLED, 800R Curve",                     $White)
                ,@($IconRefresh, "Resolution",  "3440 x 1440 @ 240 Hz",                       $White)
                ,@($IconRotate,  "Orientation", "Landscape",                                   $White)
                ,@($IconHdr,     "HDR",         "$Green$IconCheck Supported$Reset (BT2020, PQ, TrueBlack 400)", $White)
                ,@($IconSync,    "VRR",         "G-Sync Compatible + FreeSync Premium Pro",    $White)
                ,@($IconBolt,    "VRR Range",   "40-240 Hz (LFC)",                             $White)
                ,@($IconRefresh, "Response",    "0.03 ms GTG",                                 $White)
                ,@($IconPalette, "Color",       "99% DCI-P3, 135% sRGB, 10-bit",              $White)
                ,@($IconHdr,     "Brightness",  "1300 nits peak (3% window HDR)",              $White)
                ,@($IconConnect, "Connection",  "DisplayPort 1.4 (DSC)",                       $White)
                ,@($IconInfo,    "Features",    "ELMB, Smart KVM, USB-C 90W PD",               $DimWhite)
                ,@($IconCheck,   "Status",      "$Green$IconCheck Active$Reset",               $White)
            )
        },
        @{
            Label       = "SECONDARY MONITOR"
            Color       = $Blue
            Rows        = @(
                ,@($IconMonitor, "Model",       "ASUS ROG Swift PG348Q",                       "$Bold$White")
                ,@($IconDisplay, "Panel",       "34`" IPS, 3800R Curve",                       $White)
                ,@($IconRefresh, "Resolution",  "1440 x 3440 @ 60 Hz",                        $White)
                ,@($IconRotate,  "Orientation", "$Yellow$IconRotate Portrait (90${Deg})$Reset", $White)
                ,@($IconHdr,     "HDR",         "$DimWhite$IconWarning Not Supported$Reset",   $White)
                ,@($IconSync,    "VRR",         "G-Sync (Hardware Module)",                    $White)
                ,@($IconBolt,    "VRR Range",   "30-60 Hz (degraded, was 30-100)",             $White)
                ,@($IconRefresh, "Response",    "5 ms",                                        $White)
                ,@($IconPalette, "Color",       "100% sRGB, 10-bit",                           $White)
                ,@($IconHdr,     "Brightness",  "300 nits",                                    $White)
                ,@($IconConnect, "Connection",  "DisplayPort",                                 $White)
                ,@($IconInfo,    "Features",    "Turbo Key refresh toggle",                    $DimWhite)
                ,@($IconCheck,   "Status",      "$Yellow$IconWarning Degraded$Reset (OC disabled, max 60 Hz)", $White)
            )
        }
    )
    
    foreach ($mon in $monitorDefs) {
        $c = $mon.Color
        Write-Host "  $(HBar $TL $TR $c)"
        Write-Host "  $(SectionHeader $IconMonitor $mon.Label $c)"
        Write-Host "  $(HBar $LT $RT $c)"
    
        foreach ($row in $mon.Rows) {
            Write-Host ("  " + (BoxRow $row[0] $row[1] $row[2] $Yellow $row[3] $c))
        }
    
        Write-Host "  $(HBar $BL $BR $c)"
        Write-Host ""
    }
    
    Write-Host ""}

Set-Alias -Name display-info -Value Show-DisplayInfo
