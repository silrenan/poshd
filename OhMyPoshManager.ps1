# Oh My Posh Manager
# Easy management tool for Oh My Posh themes and configurations

param(
    [Parameter(Position = 0)]
    [ValidateSet('install', 'update', 'uninstall', 'theme', 'list', 'show', 'default', 'backup', 'restore', 'preview', 'export', 'help')]
    [string]$Action = 'help',
    
    [Parameter(Position = 1)]
    [string]$ThemeName,
    
    [string]$BackupName = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
)

$ConfigDir = "$env:USERPROFILE\.config\ohmyposh"
$BackupDir = "$PSScriptRoot\backups"
$ThemesDir = "$env:POSH_THEMES_PATH"

function Show-Help {
    Write-Host @"
===============================================================
              Oh My Posh Manager - Help                       
===============================================================

USAGE: .\OhMyPoshManager.ps1 [action] [parameters]

ACTIONS:
  install              Install Oh My Posh and Nerd Fonts
  update               Update Oh My Posh to latest version
  uninstall            Uninstall Oh My Posh completely
  theme [name]         Set a specific theme
  list                 List all available themes
  show                 Show currently configured theme
  default              Revert to default PowerShell prompt
  preview [name]       Preview a theme (optional: specify theme)
  backup [name]        Backup current configuration
  restore [name]       Restore a backup
  export               Export current config to this directory
  help                 Show this help message

EXAMPLES:
  .\OhMyPoshManager.ps1 install
  .\OhMyPoshManager.ps1 theme agnoster
  .\OhMyPoshManager.ps1 list
  .\OhMyPoshManager.ps1 preview
  .\OhMyPoshManager.ps1 backup my-favorite-config

"@ -ForegroundColor Cyan
}

function Install-OhMyPosh {
    Write-Host "[*] Installing Oh My Posh..." -ForegroundColor Green
    
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        Write-Host "[!] Oh My Posh is already installed!" -ForegroundColor Yellow
        Write-Host "    Run '.\OhMyPoshManager.ps1 update' to update it." -ForegroundColor Gray
    } else {
        try {
            winget install JanDeDobbeleer.OhMyPosh -s winget
            Write-Host "[+] Oh My Posh installed successfully!" -ForegroundColor Green
        } catch {
            Write-Host "[-] Installation failed. Trying alternative method..." -ForegroundColor Red
            Set-ExecutionPolicy Bypass -Scope Process -Force
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))
        }
    }
    
    Write-Host "`n[*] Installing recommended Nerd Font (CascadiaCode)..." -ForegroundColor Green
    try {
        oh-my-posh font install CascadiaCode
        Write-Host "`n[+] Font installed successfully!" -ForegroundColor Green
        Write-Host "`n[!] IMPORTANT: Configure your terminal to use the font:" -ForegroundColor Yellow
        Write-Host "    1. Windows Terminal: Ctrl+, → Appearance → Font face" -ForegroundColor White
        Write-Host "       Select: CaskaydiaCove NF" -ForegroundColor Cyan
        Write-Host "    2. VS Code: Add to settings.json:" -ForegroundColor White
        Write-Host '       "terminal.integrated.fontFamily": "CaskaydiaCove NF"' -ForegroundColor Cyan
    } catch {
        Write-Host "[!] Font installation skipped. Install manually if needed." -ForegroundColor Yellow
    }
    
    Write-Host "`n[*] Setup complete! Run '.\OhMyPoshManager.ps1 theme [name]' to set a theme." -ForegroundColor Cyan
}

function Update-OhMyPosh {
    Write-Host "[*] Updating Oh My Posh..." -ForegroundColor Green
    winget upgrade JanDeDobbeleer.OhMyPosh -s winget
    Write-Host "[+] Update complete!" -ForegroundColor Green
}

function Uninstall-OhMyPosh {
    Write-Host "[*] Uninstalling Oh My Posh..." -ForegroundColor Yellow
    
    # Confirm uninstallation
    $confirmation = Read-Host "Are you sure you want to uninstall Oh My Posh? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "[!] Uninstallation cancelled." -ForegroundColor Gray
        return
    }
    
    # Remove from PowerShell profile
    if (Test-Path $PROFILE) {
        Write-Host "[*] Removing Oh My Posh from PowerShell profile..." -ForegroundColor Yellow
        $currentContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
        if ($currentContent -match 'oh-my-posh init') {
            $newContent = $currentContent -replace '(?m)^.*oh-my-posh init.*$(\r?\n)?', ''
            $newContent = $newContent -replace '(?m)^# Oh My Posh Configuration$(\r?\n)?', ''
            Set-Content -Path $PROFILE -Value $newContent.TrimEnd()
            Write-Host "[+] Removed from profile" -ForegroundColor Green
        }
    }
    
    # Uninstall via winget
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        try {
            Write-Host "[*] Uninstalling Oh My Posh package..." -ForegroundColor Yellow
            winget uninstall JanDeDobbeleer.OhMyPosh
            Write-Host "[+] Oh My Posh uninstalled successfully!" -ForegroundColor Green
        } catch {
            Write-Host "[-] Failed to uninstall via winget. You may need to uninstall manually." -ForegroundColor Red
        }
    } else {
        Write-Host "[!] Oh My Posh is not installed or already removed." -ForegroundColor Yellow
    }
    
    Write-Host "`n[*] Uninstallation complete! Restart your terminal to apply changes." -ForegroundColor Cyan
}

function Get-Themes {
    # Check for local themes first
    if ($env:POSH_THEMES_PATH -and (Test-Path $env:POSH_THEMES_PATH)) {
        $script:ThemesDir = $env:POSH_THEMES_PATH
        return Get-ChildItem -Path $ThemesDir -Filter "*.omp.json" | Sort-Object Name
    }
    
    # Try default local path
    $defaultPath = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes"
    if (Test-Path $defaultPath) {
        $script:ThemesDir = $defaultPath
        return Get-ChildItem -Path $ThemesDir -Filter "*.omp.json" | Sort-Object Name
    }
    
    # If no local themes, fetch from GitHub
    try {
        Write-Host "[*] Fetching themes from Oh My Posh repository..." -ForegroundColor Yellow
        $repoUrl = "https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/contents/themes"
        $response = Invoke-RestMethod -Uri $repoUrl -Headers @{ "User-Agent" = "OhMyPoshManager" }
        $themes = $response | Where-Object { $_.name -like "*.omp.json" } | Sort-Object name
        
        # Return custom objects that mimic FileInfo
        return $themes | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.name
                BaseName = $_.name -replace '\.omp\.json$', ''
                FullName = $_.download_url
                IsRemote = $true
            }
        }
    }
    catch {
        Write-Host "[-] Failed to fetch themes. Is Oh My Posh installed?" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor DarkGray
        return @()
    }
}

function Show-ThemesList {
    Write-Host "`n[*] Available Oh My Posh Themes:" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Gray
    
    $themes = Get-Themes
    if ($themes.Count -eq 0) {
        Write-Host "No themes found." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Total: $($themes.Count) themes" -ForegroundColor Gray
    if ($themes[0].PSObject.Properties['IsRemote'] -and $themes[0].IsRemote) {
        Write-Host "[*] Using remote themes from GitHub" -ForegroundColor DarkGray
    }
    Write-Host "`nPreview themes at: https://ohmypo.sh/docs/themes" -ForegroundColor Cyan
    Write-Host "Use: .\OhMyPoshManager.ps1 theme [name]" -ForegroundColor DarkGray
}

function Set-Theme {
    param([string]$Theme)
    
    if (-not $Theme) {
        Write-Host "[-] Please specify a theme name." -ForegroundColor Red
        Write-Host "    Use '.\OhMyPoshManager.ps1 list' to see available themes." -ForegroundColor Gray
        return
    }
    
    $themes = Get-Themes
    $themeFile = $themes | Where-Object { $_.BaseName -like "*$Theme*" } | Select-Object -First 1
    
    if (-not $themeFile) {
        Write-Host "[-] Theme '$Theme' not found." -ForegroundColor Red
        Write-Host "    Use '.\OhMyPoshManager.ps1 list' to see available themes." -ForegroundColor Gray
        return
    }
    
    $themePath = $themeFile.FullName
    
    # Create local profile in workspace
    $localProfile = Join-Path $PSScriptRoot "OhMyPoshProfile.ps1"
    
    # Update PowerShell profile
    $profileContent = @"
# Oh My Posh Configuration
oh-my-posh init pwsh --config '$themePath' | Invoke-Expression
"@
    
    # Save to local workspace profile
    Set-Content -Path $localProfile -Value $profileContent
    
    # Also update the user's PowerShell profile
    if (-not (Test-Path $PROFILE)) {
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    }
    
    # Remove old oh-my-posh initialization
    $currentContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($currentContent)) {
        $currentContent = ""
    }
    
    if ($currentContent -match 'oh-my-posh init') {
        $currentContent = $currentContent -replace '(?m)^.*oh-my-posh init.*$(\r?\n)?', ''
        $currentContent = $currentContent -replace '(?m)^# Oh My Posh Configuration$(\r?\n)?', ''
    }
    
    # Add new initialization
    if ($currentContent) {
        $newContent = $currentContent.TrimEnd() + "`n`n" + $profileContent
    } else {
        $newContent = $profileContent
    }
    Set-Content -Path $PROFILE -Value $newContent
    
    Write-Host "[+] Theme set to: $($themeFile.BaseName)" -ForegroundColor Green
    Write-Host "    Theme saved to:" -ForegroundColor Gray
    Write-Host "    - Local: $localProfile" -ForegroundColor White
    Write-Host "    - Profile: $PROFILE" -ForegroundColor White
    Write-Host "`n    Restart your terminal to apply the theme" -ForegroundColor Cyan
}

function Show-Preview {
    param([string]$Theme)
    
    if ($Theme) {
        $themes = Get-Themes
        $themeFile = $themes | Where-Object { $_.BaseName -like "*$Theme*" } | Select-Object -First 1
        
        if ($themeFile) {
            Write-Host "`n[*] Previewing theme: $($themeFile.BaseName)" -ForegroundColor Cyan
            Write-Host "=======================================" -ForegroundColor Gray
            oh-my-posh print primary --config $themeFile.FullName
            Write-Host "`n[*] To apply this theme, run:" -ForegroundColor DarkGray
            Write-Host "    .\OhMyPoshManager.ps1 theme $($themeFile.BaseName)" -ForegroundColor White
        } else {
            Write-Host "[-] Theme '$Theme' not found." -ForegroundColor Red
        }
    } else {
        Write-Host "`n[*] Previewing random themes (Ctrl+C to stop)..." -ForegroundColor Cyan
        Write-Host "    Press any key to see next theme...`n" -ForegroundColor Gray
        
        $themes = Get-Themes
        if ($themes.Count -eq 0) {
            Write-Host "[-] No themes available for preview." -ForegroundColor Red
            return
        }
        
        $selectedThemes = $themes | Get-Random -Count ([Math]::Min(10, $themes.Count))
        $first = $true
        foreach ($themeFile in $selectedThemes) {
            if (-not $first) {
                Clear-Host
            }
            $first = $false
            
            Write-Host "=======================================" -ForegroundColor Gray
            Write-Host "Theme: $($themeFile.BaseName)" -ForegroundColor Yellow
            Write-Host "=======================================" -ForegroundColor Gray
            oh-my-posh print primary --config $themeFile.FullName
            Write-Host "`nPress any key for next theme (Ctrl+C to exit)..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        Write-Host "`n[*] Preview complete!" -ForegroundColor Green
    }
}

function Backup-Config {
    param([string]$Name)
    
    if (-not (Test-Path $BackupDir)) {
        New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
    }
    
    $backupPath = Join-Path $BackupDir "$Name.ps1"
    
    if (Test-Path $PROFILE) {
        Copy-Item $PROFILE -Destination $backupPath -Force
        Write-Host "[+] Backup created: $Name" -ForegroundColor Green
        Write-Host "    Location: $backupPath" -ForegroundColor Gray
    } else {
        Write-Host "[-] No profile found to backup." -ForegroundColor Red
    }
}

function Restore-Config {
    param([string]$Name)
    
    $backupPath = Join-Path $BackupDir "$Name.ps1"
    
    if (Test-Path $backupPath) {
        Copy-Item $backupPath -Destination $PROFILE -Force
        Write-Host "[+] Configuration restored: $Name" -ForegroundColor Green
        Write-Host "    Reload with: . `$PROFILE" -ForegroundColor Gray
    } else {
        Write-Host "[-] Backup not found: $Name" -ForegroundColor Red
        Write-Host "    Available backups:" -ForegroundColor Gray
        Get-ChildItem -Path $BackupDir -Filter "*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "    - $($_.BaseName)" -ForegroundColor White
        }
    }
}

function Show-CurrentTheme {
    Write-Host "`n[*] Current Oh My Posh Configuration:" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Gray
    
    # Check profile configuration
    $configuredTheme = $null
    if (Test-Path $PROFILE) {
        $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
        if ($profileContent -match 'oh-my-posh init.*--config\s+[''"](.*?)[''"\s]') {
            $configuredTheme = $matches[1]
            $configuredName = if ($configuredTheme -match '([^\/\\]+)\.omp\.json$') {
                $matches[1]
            } else {
                "Custom"
            }
            Write-Host "`nProfile Theme: " -NoNewline -ForegroundColor White
            Write-Host $configuredName -ForegroundColor Green
            Write-Host "Profile Path:  $PROFILE" -ForegroundColor Gray
        }
    }
    
    if (-not $configuredTheme) {
        Write-Host "`nProfile Theme: " -NoNewline -ForegroundColor White
        Write-Host "DEFAULT (PowerShell default prompt)" -ForegroundColor Yellow
        Write-Host "Profile Path:  $PROFILE" -ForegroundColor Gray
    }
    
    # Check local profile
    $localProfile = Join-Path $PSScriptRoot "OhMyPoshProfile.ps1"
    if (Test-Path $localProfile) {
        Write-Host "`nLocal Profile: $localProfile" -ForegroundColor White
    }
    
    # Check if currently active
    if ($env:POSH_THEME) {
        Write-Host "`n[*] Oh My Posh is active in current session" -ForegroundColor DarkGray
    } else {
        Write-Host "`n[*] Restart terminal to apply profile theme" -ForegroundColor DarkGray
    }
    
    Write-Host ""
}

function Set-DefaultTheme {
    Write-Host "`n[*] Reverting to default PowerShell prompt..." -ForegroundColor Cyan
    
    # Remove local profile
    $localProfile = Join-Path $PSScriptRoot "OhMyPoshProfile.ps1"
    if (Test-Path $localProfile) {
        Remove-Item $localProfile -Force
        Write-Host "[+] Removed local profile: $localProfile" -ForegroundColor Green
    }
    
    # Remove Oh My Posh from PowerShell profile
    if (Test-Path $PROFILE) {
        $currentContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
        if ($currentContent -match 'oh-my-posh init') {
            $newContent = $currentContent -replace '(?m)^.*oh-my-posh init.*$(
?
)?', ''
            $newContent = $newContent -replace '(?m)^# Oh My Posh Configuration$(
?
)?', ''
            $newContent = $newContent.TrimEnd()
            
            if ([string]::IsNullOrWhiteSpace($newContent)) {
                Remove-Item $PROFILE -Force
                Write-Host "[+] Removed empty profile: $PROFILE" -ForegroundColor Green
            } else {
                Set-Content -Path $PROFILE -Value $newContent
                Write-Host "[+] Removed Oh My Posh from profile: $PROFILE" -ForegroundColor Green
            }
        } else {
            Write-Host "[!] No Oh My Posh configuration found in profile" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[!] No PowerShell profile found" -ForegroundColor Yellow
    }
    
    Write-Host "`n[*] Restart your terminal to use default PowerShell prompt" -ForegroundColor Cyan
}

function Export-CurrentConfig {
    $exportPath = Join-Path $PSScriptRoot "my-ohmyposh-config.ps1"
    
    if (Test-Path $PROFILE) {
        Copy-Item $PROFILE -Destination $exportPath -Force
        Write-Host "[+] Configuration exported to: $exportPath" -ForegroundColor Green
    } else {
        Write-Host "[-] No profile found to export." -ForegroundColor Red
    }
}

# Main execution
switch ($Action) {
    'install' { Install-OhMyPosh }
    'update' { Update-OhMyPosh }
    'uninstall' { Uninstall-OhMyPosh }
    'theme' { Set-Theme -Theme $ThemeName }
    'list' { Show-ThemesList }
    'show' { Show-CurrentTheme }
    'default' { Set-DefaultTheme }
    'preview' { Show-Preview -Theme $ThemeName }
    'backup' { Backup-Config -Name $BackupName }
    'restore' { Restore-Config -Name $ThemeName }
    'export' { Export-CurrentConfig }
    'help' { Show-Help }
    default { Show-Help }
}
