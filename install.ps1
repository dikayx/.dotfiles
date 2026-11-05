<#
.SYNOPSIS
    Unified installer for Windows 11 (macOS / Linux Mint: install.sh).
.DESCRIPTION
    Shared steps live in lib/common.ps1, Windows specific ones in platforms/windows/platform.ps1.
    All settings are applied by default; use the -No* switches to opt out.
.PARAMETER Hostname
    Set the computer name (needs admin rights, a UAC prompt is shown; restart required).
.PARAMETER GitUsername
    Set the global Git user name.
.PARAMETER GitEmail
    Set the global Git user email.
.PARAMETER NoTweaks
    Skip the system tweaks (dark mode, Explorer settings).
.PARAMETER NoClassicContextMenu
    Skip enabling the classic (Windows 10 style) context menu.
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
$ApplyTweaks               = -not $NoTweaks
$EnableClassicContextMenu  = -not $NoClassicContextMenu

. (Join-Path $PSScriptRoot "lib\common.ps1")
. (Join-Path $PSScriptRoot "platforms\windows\platform.ps1")

if ($Hostname -and ($Hostname -notmatch '^[A-Za-z0-9]([A-Za-z0-9-]{0,13}[A-Za-z0-9])?$')) {
    throw "Invalid hostname '$Hostname' (max. 15 characters; letters, digits and '-' only)."
}

Write-Headline "Pre-Installation Setup (windows)"
if ($Hostname) { Set-PlatformHostname -Name $Hostname }

Write-Headline "Configuration Setup"
New-Item -ItemType Directory -Path (Join-Path $HOME "Projekte") -Force | Out-Null
Install-Configs

Write-Headline "Package Installation"
Install-PlatformPackages

# Identity is set after the packages, since git itself may have just been installed
Set-GitIdentity -Name $GitUsername -Email $GitEmail

Write-Headline "Vim Setup"
Install-VimPlugins

Write-Headline "Setting Terminal Profile"
Set-PlatformTerminal

Write-Headline "Applying settings & tweaks"
$restartExplorer = $false
if ($EnableClassicContextMenu) { if (Enable-ClassicContextMenu) { $restartExplorer = $true } }
if ($ApplyTweaks) { Set-SystemTweaks; $restartExplorer = $true }
if ($restartExplorer) { Restart-Explorer }

Write-Headline "Installation finished!"
