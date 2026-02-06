# creates a Start Menu shortcut that can be pinned to the taskbar

$startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
$shortcutPath = Join-Path $startMenuDir "psVRC.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$PSScriptRoot\psVRC.ps1`""
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.Description = "VRChat Profile Manager"

$iconPath = Join-Path $PSScriptRoot "psVRC.ico"
if (Test-Path $iconPath) {
    $shortcut.IconLocation = $iconPath
}

$shortcut.Save()

Write-Host ""
Write-Host "  Shortcut created at:" -ForegroundColor Green
Write-Host "  $shortcutPath" -ForegroundColor White
Write-Host ""
Write-Host "  To pin to taskbar:" -ForegroundColor Cyan
Write-Host "  1. Open Start Menu and search 'psVRC'" -ForegroundColor Gray
Write-Host "  2. Right-click it and select 'Pin to taskbar'" -ForegroundColor Gray
Write-Host ""
if (-not (Test-Path $iconPath)) {
    Write-Host "  Optional: place a psVRC.ico file in $PSScriptRoot" -ForegroundColor DarkGray
    Write-Host "  and re-run this script to set a custom icon." -ForegroundColor DarkGray
    Write-Host ""
}
