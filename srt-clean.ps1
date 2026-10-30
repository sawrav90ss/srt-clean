# srt-clean for Windows - safe cache cleaner
# https://github.com/sawrav90ss/srt-clean
#
# Finds cache folders from every app on its own and removes only what apps
# rebuild automatically: temp files, caches, crash dumps, shader and render caches.
# Skips caches of apps that are running right now.
# Never touches documents, photos, videos, projects, passwords or logins.
# Large programs, leftover installers and the Recycle Bin are only listed, never deleted.
#
# Usage (in PowerShell):
#   irm https://raw.githubusercontent.com/sawrav90ss/srt-clean/main/srt-clean.ps1 | iex
# Only show the list, delete nothing:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/sawrav90ss/srt-clean/main/srt-clean.ps1))) -DryRun

param([switch]$DryRun)

if ($env:OS -ne 'Windows_NT') {
    Write-Host 'This version is for Windows. On a Mac, use srt-clean.sh.'
    return
}

$ErrorActionPreference = 'SilentlyContinue'
$sep = [IO.Path]::DirectorySeparatorChar
$onWindows = [Environment]::OSVersion.Platform -eq 'Win32NT'
$isAdmin = $false
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {}

function Format-Size([double]$bytes) {
    if ($bytes -ge 1GB) { return ('{0:N1} GB' -f ($bytes / 1GB)) }
    return ('{0:N0} MB' -f ($bytes / 1MB))
}

function Get-FreeSpace {
    try { return ([IO.DriveInfo]([IO.Path]::GetPathRoot($env:LOCALAPPDATA))).AvailableFreeSpace } catch { return 0 }
}

function Get-Size([string]$path) {
    $item = Get-Item -LiteralPath $path -Force
    if (-not $item) { return 0 }
    if (-not $item.PSIsContainer) { return [long]$item.Length }
    $sum = (Get-ChildItem -LiteralPath $path -Recurse -Force -File | Measure-Object -Property Length -Sum).Sum
    if ($sum) { return [long]$sum }
    return 0
}

function Short([string]$path) {
    if ($env:USERPROFILE -and $path.StartsWith($env:USERPROFILE, [StringComparison]::OrdinalIgnoreCase)) {
        return '~' + $path.Substring($env:USERPROFILE.Length)
    }
    return $path
}

Write-Host '=== srt-clean: Windows cache cleanup ==='
Write-Host ('Free space now: ' + (Format-Size (Get-FreeSpace)))
Write-Host 'Scanning... (the first run can take a minute)'

# Running apps: process names and the folders they run from
$procs = @(Get-Process | ForEach-Object {
    [pscustomobject]@{ Name = $_.ProcessName.ToLower(); Path = ([string]$_.Path).ToLower() }
})

$appBases = @($env:LOCALAPPDATA, $env:APPDATA) | Where-Object { $_ }

# Does this folder belong to a running app? Takes the app folder name from
# "AppData\<App>" or "AppData\<Vendor>\<App>" and matches it against running
# process names and the folders running programs started from.
function Test-AppRunning([string]$path) {
    foreach ($base in $appBases) {
        if (-not $path.StartsWith($base + $sep, [StringComparison]::OrdinalIgnoreCase)) { continue }
        $parts = $path.Substring($base.Length + 1).Split($sep)
        $c1 = $parts[0].ToLower()
        $c2 = $null
        if ($parts.Count -ge 3) { $c2 = $parts[1].ToLower() }
        foreach ($p in $procs) {
            if ($p.Name -eq $c1 -or ($c2 -and $p.Name -eq $c2)) { return $true }
            if ($p.Name.StartsWith($c1 + ' ')) { return $true }
            if ($c2) {
                if ($p.Path.Contains($sep + $c1 + $sep + $c2 + $sep)) { return $true }
            } elseif ($p.Path.Contains($sep + $c1 + $sep)) { return $true }
        }
        return $false
    }
    return $false
}

# Shared objects (not $script: variables) so this works with both "| iex" and "& { } -DryRun"
$items = New-Object System.Collections.ArrayList
$state = @{ Skipped = 0 }
$doCache = "$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
function Add-Item([string]$path, [string]$kind = 'path') {
    if (-not $path) { return }
    if ($kind -eq 'path') {
        $resolved = Get-Item -LiteralPath $path -Force
        if (-not $resolved) { return }
        $path = $resolved.FullName
        if (Test-AppRunning $path) { $state.Skipped++; return }
    }
    $size = 0
    if ($kind -eq 'do') { $size = Get-Size $doCache } else { $size = Get-Size $path }
    if ($size -le 0) { return }
    [void]$items.Add([pscustomobject]@{ Path = $path; Size = [long]$size; Kind = $kind })
}

$oneDayAgo = (Get-Date).AddDays(-1)

# 1) Temp files older than one day (newer ones may belong to an installer that's running)
if ($env:TEMP) {
    Get-ChildItem -LiteralPath $env:TEMP -Force | Where-Object { $_.LastWriteTime -lt $oneDayAgo } |
        ForEach-Object { Add-Item $_.FullName }
}

# 2) App caches in AppData: browsers, Electron apps (Discord, Slack, VS Code, Teams),
#    Adobe media cache, GPU shader caches. Found by folder type, not app name.
$cacheNames = @('Cache', 'Code Cache', 'GPUCache', 'ShaderCache', 'GrShaderCache', 'GraphiteDawnCache',
    'DawnGraphiteCache', 'DawnWebGPUCache', 'CachedData', 'cache2', 'Media Cache Files', 'Media Cache',
    'CacheClip', 'DXCache', 'GLCache', 'ComputeCache', 'DxcCache', 'VkCache', 'D3DSCache')
$found = foreach ($base in $appBases) {
    Get-ChildItem -LiteralPath $base -Directory -Recurse -Depth 5 -Force |
        Where-Object { $cacheNames -contains $_.Name -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |
        ForEach-Object { $_.FullName }
}
# Keep only the outermost cache folder (skip "Cache\Cache_Data" when "Cache" is already listed)
$kept = @()
foreach ($f in ($found | Sort-Object Length, { $_ })) {
    $inside = $false
    foreach ($k in $kept) { if ($f.StartsWith($k + $sep, [StringComparison]::OrdinalIgnoreCase)) { $inside = $true; break } }
    if (-not $inside) { $kept += $f }
}
foreach ($f in $kept) { Add-Item $f }

# 3) Crash dumps and error reports, npm download cache
foreach ($d in @("$env:LOCALAPPDATA\CrashDumps", "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive",
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue")) {
    if (Test-Path -LiteralPath $d) { Get-ChildItem -LiteralPath $d -Force | ForEach-Object { Add-Item $_.FullName } }
}
Add-Item "$env:LOCALAPPDATA\npm-cache\_cacache"

# 4) Windows system leftovers (only when PowerShell runs as Administrator)
if ($isAdmin -and $env:SystemRoot) {
    Get-ChildItem -LiteralPath "$env:SystemRoot\Temp" -Force | Where-Object { $_.LastWriteTime -lt $oneDayAgo } |
        ForEach-Object { Add-Item $_.FullName }
    # Windows Update downloads, only while Windows Update isn't working
    if ((Get-Service wuauserv).Status -ne 'Running') {
        Get-ChildItem -LiteralPath "$env:SystemRoot\SoftwareDistribution\Download" -Force | ForEach-Object { Add-Item $_.FullName }
    }
    foreach ($d in @("$env:ProgramData\Microsoft\Windows\WER\ReportArchive", "$env:ProgramData\Microsoft\Windows\WER\ReportQueue")) {
        if (Test-Path -LiteralPath $d) { Get-ChildItem -LiteralPath $d -Force | ForEach-Object { Add-Item $_.FullName } }
    }
    # Windows Update sharing cache (Delivery Optimization), removed with Windows' own command
    if (Get-Command Delete-DeliveryOptimizationCache) { Add-Item 'Delivery Optimization cache' 'do' }
}

# --- Show the list ---
$total = ($items | Measure-Object -Property Size -Sum).Sum
Write-Host ''
if ($items.Count -eq 0) {
    Write-Host 'Nothing to clean.'
} else {
    Write-Host ('These caches can be removed ({0} items, {1} total). Largest:' -f $items.Count, (Format-Size $total))
    $items | Where-Object { $_.Size -ge 1MB } | Sort-Object Size -Descending | Select-Object -First 20 |
        ForEach-Object { Write-Host ('  {0,9}  {1}' -f (Format-Size $_.Size), (Short $_.Path)) }
}
if ($state.Skipped -gt 0) {
    Write-Host ''
    Write-Host "Skipped $($state.Skipped) items because their app is running. Quit those apps (also from the system tray) and run again to free more."
}
if (-not $isAdmin) {
    Write-Host ''
    Write-Host 'Tip: run PowerShell as Administrator to also clean Windows temp files and update leftovers.'
}

# --- Ask before deleting ---
if ($items.Count -gt 0 -and -not $DryRun) {
    Write-Host ''
    $ans = 'n'
    try {
        if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) { $ans = Read-Host 'Delete these? (y/n)' }
    } catch { $ans = 'n' }
    if ($ans -match '^[Yy]') {
        $before = Get-FreeSpace
        $inUse = 0
        foreach ($it in $items) {
            if ($it.Kind -eq 'do') { Delete-DeliveryOptimizationCache -Force; continue }
            $item = Get-Item -LiteralPath $it.Path -Force
            if (-not $item) { continue }
            if (-not $item.PSIsContainer) {
                Remove-Item -LiteralPath $it.Path -Force
                if (Test-Path -LiteralPath $it.Path) { $inUse++ }
                continue
            }
            # Rename first: Windows refuses if a program has files open inside, so
            # folders that are in use are left alone.
            $tmp = $it.Path + '.srt-clean-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
            try { [IO.Directory]::Move($it.Path, $tmp) } catch { $inUse++; continue }
            if ($onWindows) {
                # rd removes links themselves and never follows them into other folders
                cmd /c "rd /s /q `"$tmp`"" 2>$null
            } else {
                Remove-Item -LiteralPath $tmp -Recurse -Force
            }
            if (Test-Path -LiteralPath $tmp) {
                # Some files were locked: put what's left back where it was
                try { [IO.Directory]::Move($tmp, $it.Path) } catch {}
                $inUse++
            }
        }
        Write-Host ('Done! Freed: ' + (Format-Size ([math]::Max(0, (Get-FreeSpace) - $before))))
        if ($inUse -gt 0) { Write-Host "$inUse items were in use and were left alone." }
    } else {
        Write-Host 'Nothing deleted.'
    }
} elseif ($DryRun) {
    Write-Host ''
    Write-Host '(Dry run, nothing deleted)'
}

# --- Only listed, never deleted: your call ---
Write-Host ''
Write-Host 'Not deleted, review these yourself:'
$programs = foreach ($key in @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
    Get-ItemProperty $key | Where-Object { $_.DisplayName -and $_.EstimatedSize -ge 204800 } |
        ForEach-Object { [pscustomobject]@{ Name = $_.DisplayName; Size = [long]$_.EstimatedSize * 1KB } }
}
$programs | Sort-Object Name -Unique | Sort-Object Size -Descending | Select-Object -First 10 |
    ForEach-Object { Write-Host ('  Program    {0,9}  {1}' -f (Format-Size $_.Size), $_.Name) }
$installers = foreach ($d in @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop")) {
    if (-not (Test-Path -LiteralPath $d)) { continue }
    Get-ChildItem -LiteralPath $d -File -Force -Depth 1 -Recurse |
        Where-Object { @('.exe', '.msi', '.msix', '.iso') -contains $_.Extension.ToLower() -and $_.Length -ge 20MB }
}
$installers | Sort-Object Length -Descending | Select-Object -First 10 |
    ForEach-Object { Write-Host ('  Installer  {0,9}  {1}' -f (Format-Size $_.Length), (Short $_.FullName)) }
try {
    $binCount = (New-Object -ComObject Shell.Application).NameSpace(10).Items().Count
    if ($binCount -gt 0) { Write-Host "  Recycle Bin has $binCount items. Empty it yourself when you're sure." }
} catch {}
if ($env:SystemDrive -and (Test-Path -LiteralPath "$env:SystemDrive\Windows.old")) {
    Write-Host '  Windows.old (old Windows install) is still here. Remove it in Settings > System > Storage > Temporary files.'
}
Write-Host '  (Uninstall programs you don''t use in Settings > Apps. Delete old installers yourself.)'
Write-Host ''
Write-Host ('Free space now: ' + (Format-Size (Get-FreeSpace)))
