# Windows 11 platform module - dot-sourced by install.ps1.
# Keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI).

$script:WindowsDir = Join-Path $script:DotfilesDir "platforms\windows"

function Set-PlatformHostname {
    param([string]$Name)

    Write-Info "Setting hostname to '$Name'..."
    $registryName = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName").ComputerName
    if ($registryName -ieq $Name) { Write-Info "Hostname is already '$Name'."; return }

    try {
        if (Test-IsAdmin) {
            Rename-Computer -NewName $Name -Force -ErrorAction Stop
        } else {
            # Only this one step needs admin rights: elevate just for it and carry on afterwards
            Write-Info "Requesting administrator rights for the rename (UAC prompt) ..."
            Start-Process powershell -Verb RunAs -Wait -ArgumentList @(
                "-NoProfile", "-ExecutionPolicy", "Bypass",
                "-Command", "Rename-Computer -NewName '$Name' -Force"
            )
        }
        $registryName = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName").ComputerName
        if ($registryName -ieq $Name) {
            Write-Warn "You must restart your computer for the hostname change to take effect."
        } else {
            Write-Err "Hostname was not changed (UAC declined or the name is invalid)."
        }
    } catch {
        Write-Err "Failed to set hostname. Error: $_"
    }
}

function Install-PlatformPackages {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Err "winget not found. Install 'App Installer' from the Microsoft Store and re-run."
        return
    }
    if (Test-IsAdmin) {
        Write-Warn "Running elevated: some installers (e.g. Spotify) refuse to install from an admin shell."
    }

    foreach ($id in Get-ListEntries (Join-Path $script:WindowsDir "packages.txt")) {
        winget list --id $id --exact --accept-source-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Info "$id already installed, skipping."; continue }

        Write-Info "Installing $id ..."
        winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Write-Warn "Could not install $id (exit code $LASTEXITCODE)." }
    }
    Update-SessionPath
}

# Windows Terminal: register the Predawn color scheme (settings fragment) and make it the default
function Set-PlatformTerminal {
    $fragmentDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\dotfiles"
    New-Item -ItemType Directory -Path $fragmentDir -Force | Out-Null
    Copy-Item (Join-Path $script:WindowsDir "predawn.scheme.json") (Join-Path $fragmentDir "predawn.json") -Force
    Write-Info "Registered the Predawn color scheme for Windows Terminal."

    $settingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path $settingsPath)) {
        Write-Warn "Windows Terminal settings not found - pick the 'Predawn' scheme manually."
        return
    }

    try {
        # Fails on files with comments in Windows PowerShell 5.1 - then we leave the settings untouched
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json -ErrorAction Stop
        if (-not $settings.profiles.PSObject.Properties["defaults"]) {
            $settings.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{})
        }
        $defaults = $settings.profiles.defaults
        if ($defaults.PSObject.Properties["colorScheme"]) { $defaults.colorScheme = "Predawn" }
        else { $defaults | Add-Member -NotePropertyName colorScheme -NotePropertyValue "Predawn" }

        Copy-Item $settingsPath "$settingsPath.bak" -Force
        $settings | ConvertTo-Json -Depth 32 | Set-Content $settingsPath -Encoding UTF8
        Write-Info "Predawn is now the default Windows Terminal color scheme (backup: settings.json.bak)."
    } catch {
        Write-Warn "Could not edit Windows Terminal settings automatically - pick the 'Predawn' scheme in Settings > Appearance."
    }
}

function Set-RegistryDword {
    param([string]$Path, [string]$Name, [int]$Value)
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord
}

function Restart-Explorer {
    Write-Info "Restarting explorer.exe..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    # Windows normally restarts the shell on its own - only start it if that did not happen
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

# Returns $true when a change requires an Explorer restart
function Enable-ClassicContextMenu {
    Write-Info "Enabling classic context menu..."

    $clsid = "{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
    if (Test-Path "HKCU:\Software\Classes\CLSID\$clsid\InprocServer32") {
        Write-Info "Classic context menu is already enabled."
        return $false
    }
    reg.exe add "HKCU\Software\Classes\CLSID\$clsid\InprocServer32" /f /ve | Out-Null
    Write-Info "Classic context menu enabled."
    return $true
}

function Set-SystemTweaks {
    Write-Info "Applying tweaks..."
    $personalize = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $advanced    = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $sessionInfo = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo"

    # Enable the system dark mode
    Set-RegistryDword $personalize "AppsUseLightTheme" 0
    Set-RegistryDword $personalize "SystemUsesLightTheme" 0

    # Explorer tweaks
    Set-RegistryDword $advanced "HideFileExt" 0
    Set-RegistryDword $advanced "Hidden" 1
    Set-RegistryDword $advanced "FullPathAddressBar" 1
    Set-RegistryDword $sessionInfo "RestorePreviousFolder" 1
}
