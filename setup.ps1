<#
.SYNOPSIS
    Bootstrap for Windows 11: installs git, clones the repo and runs install.ps1.
.EXAMPLE
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/dikayx/.dotfiles/main/setup.ps1))) -Hostname "My-PC" -GitUsername "John Doe" -GitEmail "me@example.com"
#>
[CmdletBinding()]
param(
    [string]$Hostname,
    [string]$GitUsername,
    [string]$GitEmail,
    [switch]$NoTweaks,
    [switch]$NoClassicContextMenu
)

$ErrorActionPreference = "Stop"
# Fresh Windows installs block running .ps1 files - allow it for this session only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

function Write-Headline($Text) { Write-Host "* $Text" -ForegroundColor Green }
function Write-Info($Text)     { Write-Host "  $Text" }

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

Write-Headline "Checking Prerequisites"

if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Info "Git is already installed."
} else {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found. Install 'App Installer' from the Microsoft Store and re-run."
    }
    Write-Info "Git not found. Installing via winget ..."
    winget install --id Git.Git --exact --silent --accept-package-agreements --accept-source-agreements
    Update-SessionPath
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git installation failed." }
}

Write-Headline "Repository Setup"

$dotfilesDir = Join-Path $HOME ".dotfiles"
if (Test-Path $dotfilesDir) {
    Write-Info "Dotfiles directory already exists at $dotfilesDir."
    Write-Info "Pulling latest changes ..."
    git -C $dotfilesDir pull
} else {
    Write-Info "Cloning dotfiles repository to $dotfilesDir ..."
    git clone https://github.com/dikayx/.dotfiles.git $dotfilesDir
}

Write-Headline "Bootstrap Execution"
Write-Info "Handing over to install.ps1 ..."

& (Join-Path $dotfilesDir "install.ps1") @PSBoundParameters
