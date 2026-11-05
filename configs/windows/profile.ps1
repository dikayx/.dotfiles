# PowerShell profile (linked into WindowsPowerShell\ and PowerShell\ by install.ps1)
# Counterpart of configs/unix/.zshrc. Keep this file ASCII-only (Windows PowerShell 5.1).

### Prompt (pure style: dir, git branch, arrow) ###

$script:HasPrompted = $false

function prompt {
    $esc = [char]27
    $arrow = [char]0x276F
    $dir = Split-Path -Leaf (Get-Location)
    if (-not $dir) { $dir = (Get-Location).Path }

    $gitInfo = ""
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $branch = git branch --show-current 2>$null
        if ($LASTEXITCODE -eq 0 -and $branch) {
            $flags = ""
            foreach ($line in (git status --porcelain 2>$null)) {
                if ($line.Length -lt 2) { continue }
                if ($line[0] -notin ' ', '?') { $flags += "!" }
                if ($line[1] -notin ' ', '?') { $flags += "*" }
            }
            $flags = -join ($flags.ToCharArray() | Select-Object -Unique)
            $gitInfo = " $esc[38;5;32mgit$esc[0m:($esc[38;5;11m$branch$flags$esc[0m)"
        }
    }

    $blank = ""
    if ($script:HasPrompted) { $blank = "`n" } else { $script:HasPrompted = $true }
    return "$blank$esc[38;5;14m$dir$esc[0m$gitInfo`n$esc[38;5;46m$arrow$esc[0m "
}

### Shortcuts & aliases ###

function gpgf { git pull; git fetch }
function l  { Get-ChildItem -Force @args }
function ll { Get-ChildItem -Force @args }
function bubu { winget upgrade --all --silent --accept-package-agreements --accept-source-agreements }

# Custom scripts ('chkdsk' is a built-in Windows tool, so the SSD check is called 'chkssd')
$script:ScriptsDir = Join-Path $HOME ".dotfiles\scripts"
function cleanup { & (Join-Path $script:ScriptsDir "cleanup.ps1") @args }
function chkssd  { & (Join-Path $script:ScriptsDir "chkdsk.ps1") @args }
