# Shared helpers for install.ps1 and platforms/windows/platform.ps1.
# Dot-sourced, never executed. Keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI).

$script:DotfilesDir = Join-Path $HOME ".dotfiles"
$script:ConfigDir   = Join-Path $script:DotfilesDir "configs"

function Write-Headline($Text) { Write-Host "* $Text" -ForegroundColor Green }
function Write-Info($Text)     { Write-Host "  $Text" }
function Write-Warn($Text)     { Write-Host "  $Text" -ForegroundColor Yellow }
function Write-Err($Text)      { Write-Host "  $Text" -ForegroundColor Red }

function Test-IsAdmin {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Picks up PATH changes made by installers during this session
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

# Entries of a manifest file (one per line, '#' starts a comment)
function Get-ListEntries($Path) {
    Get-Content $Path | ForEach-Object { ($_ -replace '#.*', '').Trim() } | Where-Object { $_ }
}

# Creates a symlink; falls back to a copy when symlinks are not allowed
# (needs Developer Mode or an elevated shell). Real files are backed up, not destroyed.
function New-DotfileLink {
    param([string]$Source, [string]$Destination)

    $parent = Split-Path $Destination -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    $existing = Get-Item $Destination -Force -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.LinkType -eq 'SymbolicLink') {
            Remove-Item $Destination -Force
        } else {
            Move-Item $Destination "$Destination.bak" -Force
            Write-Info "Backed up existing $Destination -> $Destination.bak"
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Destination -Target $Source -ErrorAction Stop | Out-Null
        Write-Info "Linked $Destination -> $Source"
    } catch {
        Copy-Item $Source $Destination -Force
        Write-Warn "Symlink not permitted (enable Developer Mode), copied $Destination instead. Re-run the installer after changing the repo."
    }
}

# Links configs/common/* and configs/windows/*.os-style dotfiles into $HOME
function Install-Configs {
    # Windows Vim looks for _vimrc, everything else keeps its name
    $rename = @{ ".vimrc" = "_vimrc" }
    foreach ($dir in "common", "windows") {
        $path = Join-Path $script:ConfigDir $dir
        if (-not (Test-Path $path)) { continue }
        Get-ChildItem $path -File -Force -Filter ".*" | ForEach-Object {
            $name = $_.Name
            if ($rename.ContainsKey($name)) { $name = $rename[$name] }
            New-DotfileLink -Source $_.FullName -Destination (Join-Path $HOME $name)
        }
    }

    # PowerShell profile (Windows PowerShell 5.1 and PowerShell 7 use different folders)
    $docs = [Environment]::GetFolderPath("MyDocuments")
    $profileSource = Join-Path $script:ConfigDir "windows\profile.ps1"
    foreach ($folder in "WindowsPowerShell", "PowerShell") {
        New-DotfileLink -Source $profileSource -Destination (Join-Path $docs "$folder\profile.ps1")
    }
}

# Identity goes to the untracked ~/.gitconfig.local (included by .gitconfig),
# so the tracked config in this repo never gets modified.
function Set-GitIdentity {
    param([string]$Name, [string]$Email)
    $localCfg = Join-Path $HOME ".gitconfig.local"
    if ($Name)  { Write-Info "Setting Git username to '$Name'...";  git config --file $localCfg user.name  $Name }
    if ($Email) { Write-Info "Setting Git email to '$Email'...";    git config --file $localCfg user.email $Email }
}

function Install-VimPlugins {
    $plugFile = Join-Path $HOME "vimfiles\autoload\plug.vim"
    if (-not (Test-Path $plugFile)) {
        Write-Info "Installing vim plugin manager ..."
        New-Item -ItemType Directory -Path (Split-Path $plugFile) -Force | Out-Null
        try {
            Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" -OutFile $plugFile
            Write-Info "Vim plugin manager installed."
        } catch {
            Write-Err "Failed to install vim plugin manager: $_"
            return
        }
    } else {
        Write-Info "Vim plugin manager already installed, skipping."
    }

    Update-SessionPath
    $vim = Get-Command vim -ErrorAction SilentlyContinue
    if ($vim) { $vimExe = $vim.Source } else {
        $found = Get-ChildItem "$env:ProgramFiles\Vim\vim*\vim.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $vimExe = $found.FullName }
    }
    if (-not $vimExe) { Write-Warn "vim not found - run :PlugInstall manually later."; return }

    Write-Info "Installing Vim plugins ..."
    & $vimExe -es -u (Join-Path $script:ConfigDir "common\.vimrc") +PlugInstall +qall 2>$null
}
