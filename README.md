# Oh My Posh Manager

PowerShell script for managing Oh My Posh themes.

## Installation

```powershell
.\OhMyPoshManager.ps1 install
```

Installs Oh My Posh via winget. Installs CascadiaCode Nerd Font. Configures terminal font in Windows Terminal or VS Code settings.

## Commands

### install
Installs Oh My Posh and CascadiaCode Nerd Font. Skips if already installed.

### update
Updates Oh My Posh to latest version via winget.

### uninstall
Removes Oh My Posh from system and PowerShell profile. Requires confirmation.

### theme \<name\>
Sets specified theme. Updates both local `OhMyPoshProfile.ps1` and `$PROFILE`. Restart terminal to apply. Use `list` to see available themes.

```powershell
.\OhMyPoshManager.ps1 theme agnoster
.\OhMyPoshManager.ps1 theme paradox
```

### list
Displays all available Oh My Posh themes. Fetches from local installation or GitHub repository.

### show
Displays current theme configuration. Shows profile path and local profile if present.

### default
Removes Oh My Posh from profile. Reverts to PowerShell default prompt. Restart terminal to apply.

### preview [\<name\>]
Previews theme rendering. Without argument, shows 10 random themes interactively. With theme name, shows single theme preview.

```powershell
.\OhMyPoshManager.ps1 preview           # Random themes
.\OhMyPoshManager.ps1 preview agnoster  # Specific theme
```

### backup [\<name\>]
Copies current `$PROFILE` to `backups/` directory. Auto-generates timestamp name if not provided.

```powershell
.\OhMyPoshManager.ps1 backup
.\OhMyPoshManager.ps1 backup my-config
```

### restore \<name\>
Restores backup from `backups/` directory to `$PROFILE`. Lists available backups if name not found.

### export
Copies current `$PROFILE` to `my-ohmyposh-config.ps1` in project directory.

### help
Displays usage information.

## Behavior

Setting a theme:
1. Creates/updates `OhMyPoshProfile.ps1` in project directory
2. Updates `$PROFILE` with theme initialization
3. Requires terminal restart to apply

Theme sources:
- Fetches from `$env:POSH_THEMES_PATH` if available
- Falls back to `$env:LOCALAPPDATA\Programs\oh-my-posh\themes`
- Downloads from GitHub repository if local themes not found

Backups stored in `backups/` directory with `.ps1` extension.

## Requirements

Windows with winget. PowerShell 5.1 or later. Nerd Font for proper icon rendering.
- Install a Nerd Font: `.\OhMyPoshManager.ps1 install`
- Set the font in your terminal settings

**Script execution error?**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Configuration Location

- **Profile**: `$PROFILE` (usually `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`)
- **Themes**: `$env:POSH_THEMES_PATH`
- **Backups**: `.\backups\`

---

Created for easier shell customization
