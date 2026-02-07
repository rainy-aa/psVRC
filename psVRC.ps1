# psVRC - VRChat Profile Manager TUI

$ConfigPath = Join-Path $PSScriptRoot "profiles.json"

function Load-Config {
    if (Test-Path $ConfigPath) {
        return Get-Content $ConfigPath -Raw | ConvertFrom-Json
    }
    return $null
}

function Save-Config {
    param($Config)
    $Config | ConvertTo-Json -Depth 4 | Set-Content $ConfigPath -Encoding UTF8
}

function Detect-ProfileCount {
    $logDir = Join-Path $env:APPDATA "..\LocalLow\VRChat\VRChat"
    $oscDir = Join-Path $logDir "OSC"
    if (Test-Path $oscDir) {
        $userDirs = @(Get-ChildItem $oscDir -Directory -Filter "usr_*" -ErrorAction SilentlyContinue)
        return $userDirs.Count
    }
    return 0
}

function New-DefaultConfig {
    $count = Detect-ProfileCount
    $profileList = @()
    for ($i = 0; $i -lt $count; $i++) {
        $profileList += [PSCustomObject]@{
            id = $i; name = "Account $i"; isVR = $false
            watchAvatars = $false; watchWorlds = $false; selected = $false
        }
    }

    return [PSCustomObject]@{
        vrchatPath = ""
        profiles   = $profileList
    }
}

function Find-VRChatDir {
    $logDir = Join-Path $env:APPDATA "..\LocalLow\VRChat\VRChat"
    if (Test-Path $logDir) {
        $logFiles = Get-ChildItem $logDir -Filter "output_log_*.txt" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 3
        foreach ($log in $logFiles) {
            $head = Get-Content $log.FullName -TotalCount 15 -ErrorAction SilentlyContinue
            foreach ($line in $head) {
                if ($line -match 'Arg:\s*(.+)[\\/]VRChat\.exe\s*$') {
                    $dir = $Matches[1].Trim()
                    if (Test-Path (Join-Path $dir "launch.exe")) {
                        return $dir
                    }
                }
            }
        }
    }

    $steamPaths = @(
        "C:\Program Files (x86)\Steam",
        "C:\Program Files\Steam",
        "D:\SteamLibrary",
        "E:\SteamLibrary"
    )

    foreach ($base in @("C:\Program Files (x86)\Steam", "C:\Program Files\Steam")) {
        $vdfPath = Join-Path $base "steamapps\libraryfolders.vdf"
        if (Test-Path $vdfPath) {
            $content = Get-Content $vdfPath -Raw
            $vdfMatches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($m in $vdfMatches) {
                $libPath = $m.Groups[1].Value -replace '\\\\', '\'
                if ($steamPaths -notcontains $libPath) {
                    $steamPaths += $libPath
                }
            }
        }
    }

    foreach ($steamPath in $steamPaths) {
        $vrchatDir = Join-Path $steamPath "steamapps\common\VRChat"
        if (Test-Path (Join-Path $vrchatDir "launch.exe")) {
            return $vrchatDir
        }
    }

    return $null
}

function Prompt-VRChatPath {
    Clear-Host
    Write-Host ""
    Write-Host "  psVRC - First Run Setup" -ForegroundColor Cyan
    Write-Host "  ========================" -ForegroundColor DarkGray
    Write-Host ""

    $detected = Find-VRChatDir
    if ($detected) {
        Write-Host "  Detected VRChat at:" -ForegroundColor Green
        Write-Host "  $detected" -ForegroundColor White
        Write-Host ""
        Write-Host "  Press ENTER to use this path, or type a custom path:" -ForegroundColor Gray
    }
    else {
        Write-Host "  Could not auto-detect VRChat install folder." -ForegroundColor Yellow
        Write-Host "  Enter the VRChat folder (containing launch.exe):" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "  > " -NoNewline -ForegroundColor Cyan

    $userInput = Read-Host
    if ([string]::IsNullOrWhiteSpace($userInput) -and $detected) {
        return $detected
    }
    elseif (-not [string]::IsNullOrWhiteSpace($userInput)) {
        $trimmed = $userInput.Trim('"', "'", ' ')
        if (Test-Path (Join-Path $trimmed "launch.exe")) {
            return $trimmed
        }
        else {
            Write-Host ""
            Write-Host "  launch.exe not found in: $trimmed" -ForegroundColor Red
            Write-Host "  Press any key to try again..." -ForegroundColor Gray
            [System.Console]::ReadKey($true) | Out-Null
            return Prompt-VRChatPath
        }
    }
    else {
        Write-Host ""
        Write-Host "  No path provided." -ForegroundColor Red
        Write-Host "  Press any key to try again..." -ForegroundColor Gray
        [System.Console]::ReadKey($true) | Out-Null
        return Prompt-VRChatPath
    }
}

function Draw-Screen {
    param($Config, $CursorPos, $StatusMsg)

    Clear-Host
    $profiles = @($Config.profiles)

    Write-Host ""
    Write-Host "  psVRC - VRChat Profile Manager" -ForegroundColor Cyan
    Write-Host "  $([char]0x2500)" -NoNewline -ForegroundColor DarkGray
    for ($i = 0; $i -lt 40; $i++) { Write-Host "$([char]0x2500)" -NoNewline -ForegroundColor DarkGray }
    Write-Host ""
    Write-Host ""

    if ($profiles.Count -eq 0) {
        Write-Host "  No profiles. Press A to add one." -ForegroundColor DarkGray
    }

    for ($i = 0; $i -lt $profiles.Count; $i++) {
        $p = $profiles[$i]
        $isCursor = ($i -eq $CursorPos)

        if ($isCursor -and $p.selected) {
            $indicator = "[>*]"
            $indicatorColor = "Yellow"
        }
        elseif ($isCursor) {
            $indicator = "[>]"
            $indicatorColor = "Yellow"
        }
        elseif ($p.selected) {
            $indicator = "[*]"
            $indicatorColor = "Green"
        }
        else {
            $indicator = "[ ]"
            $indicatorColor = "DarkGray"
        }

        $indicator = $indicator.PadRight(5)

        Write-Host "  " -NoNewline
        Write-Host $indicator -NoNewline -ForegroundColor $indicatorColor
        Write-Host "$($p.id)  " -NoNewline -ForegroundColor DarkGray

        $nameStr = "$($p.name)".PadRight(12)
        if ($isCursor) {
            Write-Host $nameStr -NoNewline -ForegroundColor White
        }
        else {
            Write-Host $nameStr -NoNewline -ForegroundColor Gray
        }

        if ($p.isVR) {
            Write-Host "VR     " -NoNewline -ForegroundColor Cyan
        }
        else {
            Write-Host "Desktop" -NoNewline -ForegroundColor DarkGray
        }

        Write-Host "  " -NoNewline

        if ($p.watchAvatars) {
            Write-Host "[x] Watch" -ForegroundColor Magenta
        }
        else {
            Write-Host "[ ] Watch" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "  $([char]0x2500)" -NoNewline -ForegroundColor DarkGray
    for ($i = 0; $i -lt 40; $i++) { Write-Host "$([char]0x2500)" -NoNewline -ForegroundColor DarkGray }
    Write-Host ""

    Write-Host "  SPACE" -NoNewline -ForegroundColor White
    Write-Host "  Select/Deselect    " -NoNewline -ForegroundColor DarkGray
    Write-Host "V" -NoNewline -ForegroundColor White
    Write-Host "  Toggle VR/Desktop" -ForegroundColor DarkGray

    Write-Host "  W" -NoNewline -ForegroundColor White
    Write-Host "      Toggle Watch       " -NoNewline -ForegroundColor DarkGray
    Write-Host "ENTER" -NoNewline -ForegroundColor White
    Write-Host "  Launch" -ForegroundColor DarkGray

    Write-Host "  A" -NoNewline -ForegroundColor White
    Write-Host "      Add Profile        " -NoNewline -ForegroundColor DarkGray
    Write-Host "E" -NoNewline -ForegroundColor White
    Write-Host "  Edit Name" -ForegroundColor DarkGray

    Write-Host "  D" -NoNewline -ForegroundColor White
    Write-Host "      Delete Profile     " -NoNewline -ForegroundColor DarkGray
    Write-Host "Q" -NoNewline -ForegroundColor White
    Write-Host "  Quit" -ForegroundColor DarkGray

    if ($StatusMsg) {
        Write-Host ""
        Write-Host "  $StatusMsg" -ForegroundColor Yellow
    }
}

function Launch-Profiles {
    param($Config, $CursorPos)

    $profiles = @($Config.profiles)
    $selected = @($profiles | Where-Object { $_.selected })

    if ($selected.Count -eq 0 -and $profiles.Count -gt 0) {
        $selected = @($profiles[$CursorPos])
    }

    if ($selected.Count -eq 0) {
        return "No profiles to launch."
    }

    $vrchatDir = $Config.vrchatPath
    if ([string]::IsNullOrWhiteSpace($vrchatDir) -or -not (Test-Path $vrchatDir)) {
        return "VRChat path not set or invalid. Restart to reconfigure."
    }

    $launchExe = Join-Path $vrchatDir "launch.exe"
    if (-not (Test-Path $launchExe)) {
        return "launch.exe not found in $vrchatDir"
    }

    $launchedNames = @()

    foreach ($p in $selected) {
        try {
            $launchArgs = @("--profile=$($p.id)")
            if (-not $p.isVR) {
                $launchArgs += "--no-vr"
            }
            if ($p.watchAvatars) {
                $launchArgs += "--watch-avatars"
                $launchArgs += "--watch-worlds"
            }
            $argString = $launchArgs -join ' '
            Start-Process -FilePath $launchExe -WorkingDirectory $vrchatDir -ArgumentList $argString
            $launchedNames += $p.name
        }
        catch {
            return "Failed to launch $($p.name): $_"
        }

        if ($selected.Count -gt 1) {
            Start-Sleep -Seconds 2
        }
    }

    return "Launched: $($launchedNames -join ', ')"
}

function Inline-Prompt {
    param([string]$PromptText)

    Write-Host ""
    Write-Host "  $PromptText" -NoNewline -ForegroundColor Cyan
    Write-Host " > " -NoNewline -ForegroundColor White
    return Read-Host
}

# ─── Main ───

$firstRun = $false
$config = Load-Config
if (-not $config) {
    $config = New-DefaultConfig
    $firstRun = $true
}

foreach ($p in @($config.profiles)) {
    if (-not (Get-Member -InputObject $p -Name "selected" -MemberType NoteProperty)) {
        $p | Add-Member -MemberType NoteProperty -Name "selected" -Value $false
    }
}

$launchCheck = if ($config.vrchatPath) { Join-Path $config.vrchatPath "launch.exe" } else { "" }
if ([string]::IsNullOrWhiteSpace($config.vrchatPath) -or -not (Test-Path $launchCheck)) {
    $config.vrchatPath = Prompt-VRChatPath
    Save-Config $config
}

$cursorPos = 0
$statusMsg = ""
$running = $true

if ($firstRun) {
    $count = @($config.profiles).Count
    if ($count -gt 0) {
        $statusMsg = "Detected $count account(s). Press E to rename, A to add more."
    }
    else {
        $statusMsg = "No accounts detected. Press A to add a profile."
    }
}

while ($running) {
    $profiles = @($config.profiles)

    if ($profiles.Count -eq 0) {
        $cursorPos = 0
    }
    elseif ($cursorPos -ge $profiles.Count) {
        $cursorPos = $profiles.Count - 1
    }
    elseif ($cursorPos -lt 0) {
        $cursorPos = 0
    }

    Draw-Screen -Config $config -CursorPos $cursorPos -StatusMsg $statusMsg
    $statusMsg = ""

    $key = [System.Console]::ReadKey($true)

    if ($key.Key -eq [ConsoleKey]::UpArrow) {
        if ($cursorPos -gt 0) { $cursorPos-- }
    }
    elseif ($key.Key -eq [ConsoleKey]::DownArrow) {
        if ($cursorPos -lt ($profiles.Count - 1)) { $cursorPos++ }
    }
    elseif ($key.Key -eq [ConsoleKey]::Spacebar) {
        if ($profiles.Count -gt 0) {
            $profiles[$cursorPos].selected = -not $profiles[$cursorPos].selected
        }
    }
    elseif ($key.Key -eq [ConsoleKey]::Enter) {
        $statusMsg = Launch-Profiles -Config $config -CursorPos $cursorPos
    }
    else {
        switch ([char]::ToLower($key.KeyChar)) {
            'q' {
                foreach ($p in $profiles) {
                    $p.selected = $false
                }
                Save-Config $config
                $running = $false
            }
            'v' {
                if ($profiles.Count -gt 0) {
                    $current = $profiles[$cursorPos]
                    if ($current.isVR) {
                        $current.isVR = $false
                    }
                    else {
                        foreach ($p in $profiles) {
                            $p.isVR = $false
                        }
                        $current.isVR = $true
                    }
                    Save-Config $config
                }
            }
            'w' {
                if ($profiles.Count -gt 0) {
                    $current = $profiles[$cursorPos]
                    $newVal = -not $current.watchAvatars
                    $current.watchAvatars = $newVal
                    $current.watchWorlds = $newVal
                    Save-Config $config
                }
            }
            'a' {
                $name = Inline-Prompt "Profile name:"
                if (-not [string]::IsNullOrWhiteSpace($name)) {
                    $maxId = -1
                    foreach ($p in $profiles) {
                        if ($p.id -gt $maxId) { $maxId = $p.id }
                    }
                    $newId = $maxId + 1

                    $newProfile = [PSCustomObject]@{
                        id           = $newId
                        name         = $name.Trim()
                        isVR         = $false
                        watchAvatars = $false
                        watchWorlds  = $false
                        selected     = $false
                    }
                    $config.profiles = @($profiles) + @($newProfile)
                    Save-Config $config
                    $statusMsg = "Added profile '$($name.Trim())' (ID $newId)"
                }
                else {
                    $statusMsg = "Add cancelled."
                }
            }
            'e' {
                if ($profiles.Count -gt 0) {
                    $current = $profiles[$cursorPos]
                    $newName = Inline-Prompt "New name for '$($current.name)':"
                    if (-not [string]::IsNullOrWhiteSpace($newName)) {
                        $current.name = $newName.Trim()
                        Save-Config $config
                        $statusMsg = "Renamed to '$($newName.Trim())'"
                    }
                    else {
                        $statusMsg = "Edit cancelled."
                    }
                }
            }
            'd' {
                if ($profiles.Count -gt 0) {
                    $current = $profiles[$cursorPos]
                    Draw-Screen -Config $config -CursorPos $cursorPos -StatusMsg "Delete '$($current.name)'? (y/n)"
                    $confirm = [System.Console]::ReadKey($true)
                    if ($confirm.KeyChar -eq 'y') {
                        $config.profiles = @($profiles | Where-Object { $_.id -ne $current.id })
                        Save-Config $config
                        $statusMsg = "Deleted '$($current.name)'"
                    }
                    else {
                        $statusMsg = "Delete cancelled."
                    }
                }
            }
        }
    }
}

Clear-Host
Write-Host "  psVRC exited. Config saved." -ForegroundColor DarkGray
Write-Host ""
