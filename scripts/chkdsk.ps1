# Check SSD wear/health on Windows (requires smartmontools, assumes an NVMe SSD).
# Counterpart of chkdsk.sh. Needs an elevated shell. Usage: chkssd [-Device /dev/nvme0]
#
# Exit codes: 0 healthy/warning, 1 critical wear, 2 SMART critical warning, 3 no wear data

param([string]$Device = "/dev/nvme0")

if (-not (Get-Command smartctl -ErrorAction SilentlyContinue)) {
    Write-Error "smartctl not found. Install it with: winget install smartmontools.smartmontools"
    exit 3
}

$output = (smartctl -A $Device 2>&1) -join "`n"

$used = [regex]::Match($output, 'Percentage Used:\s+(\d+)')
if (-not $used.Success) {
    Write-Error "Could not read wear data for $Device. Run from an elevated shell, or pass another device (e.g. /dev/sda). Raw output:`n$output"
    exit 3
}
$remaining = 100 - [int]$used.Groups[1].Value

$warning = [regex]::Match($output, 'Critical Warning:\s+(0x[0-9a-fA-F]+)')
if ($warning.Success -and $warning.Groups[1].Value -ne "0x00") {
    Write-Host "SSD FAILED ($remaining% remaining, critical warning $($warning.Groups[1].Value)) - back up your data and replace the drive immediately"
    exit 2
} elseif ($remaining -le 10) {
    Write-Host "SSD Critical ($remaining% remaining) - consider replacing the drive soon"
    exit 1
} elseif ($remaining -le 30) {
    Write-Host "SSD Warning ($remaining% remaining)"
} else {
    Write-Host "SSD Healthy ($remaining% remaining)"
}
