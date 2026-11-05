# My DIY 'Clean your PC' - Windows counterpart of cleanup.sh
# Deletes files older than $PruneDays from known cache / log locations.

param([int]$PruneDays = 10)

$ErrorActionPreference = "SilentlyContinue"

$targetDirs = @(
    "$env:LOCALAPPDATA\Temp",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
    "$env:LOCALAPPDATA\CrashDumps",
    "$env:LOCALAPPDATA\Spotify\Storage",
    "$env:APPDATA\discord\Cache\Cache_Data"
)

Write-Host "Pruning files older than $PruneDays days...`n"

$cutoff = (Get-Date).AddDays(-$PruneDays)
$total = 0

foreach ($dir in $targetDirs) {
    if (-not (Test-Path $dir)) { Write-Host "Skipping missing directory: $dir"; continue }

    $bytes = 0
    Get-ChildItem $dir -Recurse -File -Force | Where-Object { $_.LastWriteTime -lt $cutoff } | ForEach-Object {
        $size = $_.Length
        Remove-Item $_.FullName -Force
        if (-not (Test-Path $_.FullName)) { $bytes += $size }   # only count what was really deleted (files in use stay)
    }
    Write-Host ("{0} -> {1:N2} MB deleted" -f $dir, ($bytes / 1MB))
    $total += $bytes
}

Write-Host ("`nCleanup complete. Total deleted: {0:N2} MB" -f ($total / 1MB))
