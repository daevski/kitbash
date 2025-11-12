# Kitbash Uninstall Framework Proposal

**Date**: 2025-11-12
**Status**: Design Proposal
**Author**: Analysis by Claude (Sonnet 4.5)

---

## Executive Summary

This document proposes a standardized install/uninstall framework for kitbash based on comprehensive analysis of all 27 existing modules. The framework introduces state tracking, type-based operations, and safe removal capabilities while maintaining kitbash's "get shit done" philosophy.

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Installation Pattern Categories](#installation-pattern-categories)
3. [Proposed Framework Architecture](#proposed-framework-architecture)
4. [Implementation Phases](#implementation-phases)
5. [Uninstallation Complexity Matrix](#uninstallation-complexity-matrix)
6. [Shared Resource Management](#shared-resource-management)
7. [API Design](#api-design)
8. [Safety and Rollback](#safety-and-rollback)

---

## Current State Analysis

### Module Inventory

- **Total Modules**: 27
- **Installation Methods**: 12 distinct patterns
- **Primary Package Manager**: DNF (Fedora)
- **Current Uninstall Support**: None

### Key Insight

Modules can be grouped into 12 distinct installation patterns, each creating different types of resources. By categorizing modules by type and tracking what resources they create, we can implement type-specific uninstallation logic.

---

## Installation Pattern Categories

### 1. DNF Package Installation (Simple)

**Modules**: `alacritty`, `jq`, `copyq`

**Pattern**:
```bash
# Idempotency check
if command -v <binary> >/dev/null 2>&1; then
    exit 0
fi

# Install
sudo dnf install -y <package>
```

**Resources Created**:
- Binary in `/usr/bin/`
- DNF package database entry
- Desktop files (for GUI apps)
- Man pages
- Shared libraries in `/usr/lib64/`

**Uninstall Strategy**:
```bash
sudo dnf remove -y <package>
```

**Complexity**: Low | **Can Fully Remove**: Yes

---

### 2. Third-Party Repository Setup + Package

#### 2a. DNF Config Manager

**Module**: `google_chrome`

**Pattern**:
```bash
sudo dnf config-manager addrepo --id=google-chrome ...
sudo dnf install -y google-chrome-stable
```

**Resources Created**:
- Repository in DNF database (no file)
- Package in DNF db
- Binary in `/usr/bin/`

**Uninstall Strategy**:
```bash
sudo dnf remove -y google-chrome-stable
sudo dnf config-manager --set-disabled google-chrome
# Or: sudo dnf config-manager --remove-repo google-chrome
```

**Complexity**: Low-Medium | **Can Fully Remove**: Yes

---

#### 2b. Manual Repo File

**Module**: `vscode`

**Pattern**:
```bash
sudo rpm --import <gpg-key>
echo "repo config" | sudo tee /etc/yum.repos.d/vscode.repo
sudo dnf install -y code
```

**Resources Created**:
- `/etc/yum.repos.d/vscode.repo` (file)
- GPG key in RPM database
- Package in DNF db
- Binary in `/usr/bin/code`

**Uninstall Strategy**:
```bash
sudo dnf remove -y code
sudo rm /etc/yum.repos.d/vscode.repo
# Optional: remove GPG key
```

**Complexity**: Medium | **Can Fully Remove**: Yes

---

#### 2c. COPR Repository

**Modules**: `synology`, `niri`, `hyprland`

**Pattern**:
```bash
sudo dnf copr enable -y owner/project
sudo dnf install -y <package>
```

**Resources Created**:
- `/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:owner:project.repo`
- Package in DNF db
- Binaries in `/usr/bin/`

**Uninstall Strategy**:
```bash
sudo dnf remove -y <package>
sudo dnf copr disable owner/project
# Optionally: rm repo file
```

**Complexity**: Medium | **Can Fully Remove**: Yes

---

#### 2d. Docker Repository

**Module**: `docker`

**Pattern**:
```bash
sudo dnf config-manager addrepo --from-repofile="https://download.docker.com/linux/fedora/docker-ce.repo"
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo groupadd docker
sudo usermod -aG docker $USER
```

**Resources Created**:
- Repository file
- Multiple packages (docker-ce, containerd, plugins)
- Systemd service: `/usr/lib/systemd/system/docker.service`
- Docker group
- User added to docker group
- Docker data in `/var/lib/docker/`

**Uninstall Strategy**:
```bash
sudo systemctl stop docker
sudo systemctl disable docker
sudo dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo gpasswd -d $USER docker
# Optional (careful): sudo groupdel docker
# Optional (data loss): sudo rm -rf /var/lib/docker
sudo rm /etc/yum.repos.d/docker-ce.repo
```

**Complexity**: Medium-High | **Can Fully Remove**: Yes (with data loss option)

---

#### 2e. RPM Fusion Repository

**Modules**: `steam`, `discord`

**Pattern**:
```bash
sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf install -y steam|discord
```

**Resources Created**:
- Repository packages: `rpmfusion-free-release`, `rpmfusion-nonfree-release`
- Multiple repo files in `/etc/yum.repos.d/`
- Application packages
- Desktop entries

**Uninstall Strategy**:
```bash
sudo dnf remove -y steam  # or discord
# Consider: Keep RPM Fusion (shared resource, other apps may depend)
# If no other modules need RPM Fusion:
# sudo dnf remove -y rpmfusion-*-release
```

**Complexity**: Medium | **Can Fully Remove**: Yes (but shared repo consideration)

**Note**: RPM Fusion is a shared resource. Requires reference counting.

---

### 3. Binary Download + Manual Extraction

**Module**: `ollama`

**Pattern**:
```bash
curl -LO https://ollama.com/download/ollama-linux-amd64.tgz
sudo tar -C /usr -xzf ollama-linux-amd64.tgz
sudo useradd -r -s /bin/false -U -m -d /usr/share/ollama ollama
sudo tee /etc/systemd/system/ollama.service > /dev/null << 'EOF'
[Unit]
Description=Ollama Service
...
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now ollama
```

**Resources Created**:
- `/usr/bin/ollama` (binary)
- `/usr/lib/ollama/` (libraries)
- System user: `ollama`
- System group: `ollama`
- User home: `/usr/share/ollama`
- Systemd service: `/etc/systemd/system/ollama.service`
- Service enabled and started

**Uninstall Strategy**:
```bash
sudo systemctl stop ollama
sudo systemctl disable ollama
sudo rm /etc/systemd/system/ollama.service
sudo rm /usr/bin/ollama
sudo rm -rf /usr/lib/ollama/
sudo rm -rf /usr/share/ollama/
sudo userdel ollama
sudo groupdel ollama
sudo systemctl daemon-reload
```

**Complexity**: Medium | **Can Fully Remove**: Yes

---

### 4. Binary Download + Installer Script

**Module**: `awscli`

**Pattern**:
```bash
curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip
sudo ./aws/install --update
```

**Resources Created**:
- `/usr/local/bin/aws` (symlink)
- `/usr/local/bin/aws_completer` (symlink)
- `/usr/local/aws-cli/` (installation directory)
- Man pages in `/usr/local/share/man/`
- User data in `~/.aws/` (credentials, config)

**Uninstall Strategy**:
```bash
sudo rm /usr/local/bin/aws*
sudo rm -rf /usr/local/aws-cli/
sudo rm /usr/local/share/man/man1/aws*
# Optional (preserve user credentials):
# rm -rf ~/.aws/
```

**Complexity**: Medium | **Can Fully Remove**: Yes

---

### 5. AppImage Installation

**Module**: `obsidian`

**Pattern**:
```bash
# Install FUSE2 dependency
sudo dnf install -y fuse-libs

# Download and install
curl -L -o Obsidian.AppImage "$URL"
chmod +x Obsidian.AppImage
sudo mv Obsidian.AppImage /usr/local/bin/obsidian

# Create desktop entry
sudo tee /usr/share/applications/obsidian.desktop > /dev/null << EOF
...
EOF

# Extract and install icon
/usr/local/bin/obsidian --appimage-extract obsidian.png
sudo cp squashfs-root/obsidian.png /usr/share/icons/hicolor/512x512/apps/
sudo update-desktop-database /usr/share/applications
```

**Resources Created**:
- `/usr/local/bin/obsidian` (AppImage executable)
- `/usr/share/applications/obsidian.desktop` (desktop entry)
- `/usr/share/icons/hicolor/512x512/apps/obsidian.png` (icon)
- Dependency package: `fuse-libs` (DNF)
- User data in `~/.config/obsidian/` (created on first run)

**Uninstall Strategy**:
```bash
sudo rm /usr/local/bin/obsidian
sudo rm /usr/share/applications/obsidian.desktop
sudo rm /usr/share/icons/hicolor/512x512/apps/obsidian.png
sudo update-desktop-database /usr/share/applications
# Optional (preserve user data):
# rm -rf ~/.config/obsidian/
# Note: Keep fuse-libs (shared dependency for other AppImages)
```

**Complexity**: Low-Medium | **Can Fully Remove**: Yes

---

### 6. Git Repository Clone + Build Script

**Module**: `theme`

**Pattern**:
```bash
# Install dependencies
sudo dnf install -y sassc gtk-murrine-engine gnome-themes-extra

# Clone and install
git clone https://github.com/Fausto-Korpsvart/Catppuccin-GTK-Theme.git
cd Catppuccin-GTK-Theme
./install.sh -c dark -l

# Apply theme
gsettings set org.gnome.desktop.interface gtk-theme "Catppuccin-GTK-Dark"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
```

**Resources Created**:
- `~/.themes/Catppuccin-GTK-Dark/` or `~/.local/share/themes/Catppuccin-GTK-Dark/`
- GTK4 libadwaita symlink (via `-l` flag)
- GSettings entries:
  - `org.gnome.desktop.interface gtk-theme`
  - `org.gnome.desktop.interface color-scheme`
- Dependencies: `sassc`, `gtk-murrine-engine`, `gnome-themes-extra` packages

**Uninstall Strategy**:
```bash
# Reset theme
gsettings reset org.gnome.desktop.interface gtk-theme
gsettings reset org.gnome.desktop.interface color-scheme

# Remove theme files
rm -rf ~/.themes/Catppuccin-GTK-Dark
rm -rf ~/.local/share/themes/Catppuccin-GTK-Dark

# Optional: Remove dependencies (only if no other themes need them)
# sudo dnf remove sassc gtk-murrine-engine gnome-themes-extra
```

**Complexity**: Medium | **Can Fully Remove**: Yes

---

### 7. Font Installation (Download + Extract)

**Module**: `font`

**Pattern**:
```bash
# For each font in _font_definitions:
wget "$font_url" -O font.zip
unzip font.zip -d extracted/
mkdir -p ~/.local/share/fonts/
cp extracted/*.{ttf,otf} ~/.local/share/fonts/
fc-cache -fv
```

**Resources Created**:
- `~/.local/share/fonts/<FontName>*.{ttf,otf}` (font files)
- Font cache updated: `~/.cache/fontconfig/`
- Multiple fonts from `_font_definitions` array

**Uninstall Strategy**:
```bash
# Challenge: Identifying which fonts were installed by kitbash
# Solution: Track font filenames in state file

# For each tracked font file:
rm ~/.local/share/fonts/<tracked-font-file>

# Rebuild font cache
fc-cache -fv
```

**Complexity**: Medium | **Can Fully Remove**: Yes (if tracked)

**Note**: Requires accurate tracking of installed font filenames in state file.

---

### 8. Configuration-Only Modules

#### 8a. Hostname

**Module**: `hostname`

**Pattern**:
```bash
sudo hostnamectl hostname "$new_hostname"
```

**Resources Modified**:
- System hostname (kernel setting)
- `/etc/hostname` (file)

**Uninstall Strategy**:
```bash
# Restore to original hostname (must be tracked)
sudo hostnamectl hostname "$original_hostname"
```

**Complexity**: Low | **Can Fully Remove**: Partial (revert to original)

**Note**: Requires tracking original hostname before change.

---

#### 8b. Power Never Sleep

**Module**: `power_never_sleep`

**Pattern**:
```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/no-auto-sleep.conf << EOF
[Login]
IdleAction=ignore
EOF

sudo mkdir -p /etc/systemd/sleep.conf.d
sudo tee /etc/systemd/sleep.conf.d/no-auto-sleep.conf << EOF
[Sleep]
AllowSuspend=no
AllowHibernation=no
EOF
```

**Resources Created**:
- `/etc/systemd/logind.conf.d/no-auto-sleep.conf`
- `/etc/systemd/sleep.conf.d/no-auto-sleep.conf`

**Uninstall Strategy**:
```bash
sudo rm /etc/systemd/logind.conf.d/no-auto-sleep.conf
sudo rm /etc/systemd/sleep.conf.d/no-auto-sleep.conf
sudo systemctl restart systemd-logind
```

**Complexity**: Low | **Can Fully Remove**: Yes

---

#### 8c. Default Editor

**Module**: `editor`

**Pattern**:
```bash
# Set environment variables
echo "export EDITOR=\"$editor\"" >> ~/.profile
git config --global core.editor "$editor"
systemctl --user set-environment EDITOR="$editor"
```

**Resources Modified**:
- `~/.profile` (or `~/.config/environment.d/editor.conf`)
- `~/.gitconfig` (Git config)
- Systemd user environment variables

**Uninstall Strategy**:
```bash
# Restore to previous values (must be tracked)
git config --global core.editor "$original_editor"
systemctl --user unset-environment EDITOR
# Remove from ~/.profile or ~/.config/environment.d/editor.conf
```

**Complexity**: Medium | **Can Fully Remove**: Partial (revert to original)

**Note**: Requires tracking original editor value.

---

#### 8d. Default Terminal

**Module**: `terminal`

**Pattern**:
```bash
sudo update-alternatives --install /usr/bin/x-terminal-emulator \
    x-terminal-emulator "/usr/bin/$TERMINAL_APP" 50
```

**Resources Modified**:
- Update-alternatives system
- `~/.config/xfce4/helpers.rc` (if exists)

**Uninstall Strategy**:
```bash
sudo update-alternatives --remove x-terminal-emulator "/usr/bin/$TERMINAL_APP"
# Or switch to different terminal:
# sudo update-alternatives --config x-terminal-emulator
```

**Complexity**: Low | **Can Fully Remove**: Partial (remove alternative)

---

#### 8e. Cursor Theme

**Module**: `cursor`

**Pattern**:
```bash
gsettings set org.gnome.desktop.interface cursor-theme "$theme"
gsettings set org.gnome.desktop.interface cursor-size "$size"

# Also modifies:
# - ~/.profile (XCURSOR_THEME export)
# - ~/.config/gtk-3.0/settings.ini
# - ~/.config/environment.d/cursor.conf
# - ~/.config/sway/config (seat * xcursor_theme)
# - ~/.config/niri/config.kdl (cursor block)
```

**Resources Modified**: Multiple config files + GSettings

**Uninstall Strategy**:
```bash
# Revert GSettings
gsettings reset org.gnome.desktop.interface cursor-theme
gsettings reset org.gnome.desktop.interface cursor-size

# Revert config files (requires tracking original values)
# Remove from ~/.profile, gtk-3.0/settings.ini, etc.
# Reload compositor configs
```

**Complexity**: High | **Can Fully Remove**: Partial (revert to defaults)

**Note**: Very high complexity due to multiple config file modifications.

---

#### 8f. Sudo Timeout

**Module**: `sudo_timeout`

**Pattern**:
```bash
echo "Defaults:${USER} timestamp_timeout=${timeout}" > /tmp/user-timeout
sudo cp /tmp/user-timeout /etc/sudoers.d/${USER}-timeout
sudo chmod 440 /etc/sudoers.d/${USER}-timeout
```

**Resources Created**:
- `/etc/sudoers.d/${USER}-timeout`

**Uninstall Strategy**:
```bash
sudo rm /etc/sudoers.d/${USER}-timeout
sudo visudo -c  # Verify sudoers integrity
```

**Complexity**: Low | **Can Fully Remove**: Yes

---

#### 8g. SDDM Theme

**Module**: `sddm`

**Pattern**:
```bash
sudo sed -i 's|^Current=.*|Current=custom|' /etc/sddm.conf
```

**Resources Modified**:
- `/etc/sddm.conf`

**Uninstall Strategy**:
```bash
# Revert to original theme (must be tracked)
sudo sed -i "s|^Current=.*|Current=$original_theme|" /etc/sddm.conf
```

**Complexity**: Low | **Can Fully Remove**: Partial (revert to original)

**Note**: Requires tracking original SDDM theme.

---

### 9. Complex Multi-File Configuration

#### 9a. Wallpaper

**Module**: `wallpaper`

**Complexity**: HIGHEST - modifies 10+ config files across multiple compositors

**Resources Created/Modified**:
- `/usr/share/backgrounds/wallpaper.<ext>` (original)
- `/usr/share/backgrounds/wallpaper-0.<ext>` (split left monitor)
- `/usr/share/backgrounds/wallpaper-1.<ext>` (split right monitor)
- `/usr/share/backgrounds/default` (symlink)
- `~/.config/sway/config` (modified output lines)
- `~/.config/hypr/hyprland.conf` (modified hyprpaper commands)
- `~/.config/niri/config.kdl` (modified swaybg spawn)
- `~/.config/swaylock/config` (modified image path)
- `~/.config/hypr/hyprlock.conf` (modified path)
- `/usr/share/sddm/themes/custom/theme.conf` (modified)
- `/etc/sddm.conf` (modified)

**Uninstall Strategy**:
```bash
# Remove wallpaper files
sudo rm /usr/share/backgrounds/wallpaper*
sudo rm /usr/share/backgrounds/default

# Revert config changes (requires tracking original values or patterns)
# This is VERY complex - each compositor has different config syntax

# Reload/restart affected services
niri msg action load-config-file  # Niri
hyprctl reload                     # Hyprland
swaymsg reload                     # Sway
```

**Complexity**: VERY HIGH | **Can Fully Remove**: Partial (config restoration complex)

**Note**: Recommend "leave configs as-is" approach unless full backup/restore implemented.

---

#### 9b. Mounts

**Module**: `mounts`

**Pattern**:
```bash
# For each mount in _network_mounts and _local_media:
sudo mkdir -p "$mount_point"
echo "$mount_line" | sudo tee -a /etc/fstab
ln -s "$mount_point" "$home_symlink"
sudo systemctl daemon-reload
```

**Resources Created**:
- Mount point directories: `/media/*`, `/mnt/*`
- Symlinks in `$HOME` pointing to mount points
- `/etc/fstab` entries (multiple, with noauto flag)
- Systemd mount units (auto-generated from fstab)
- CIFS credential files (if network mounts): `~/.smbcreds`

**Uninstall Strategy**:
```bash
# Unmount all tracked mount points
sudo umount <mount_point>

# Remove fstab entries (requires identifying which were added by kitbash)
# This is challenging - fstab is shared
sudo sed -i '/# kitbash: mount_name/d' /etc/fstab

# Remove mount point directories
sudo rmdir /media/<mount_point>

# Remove home symlinks
rm ~/symlink

# Reload systemd
sudo systemctl daemon-reload
```

**Complexity**: HIGH | **Can Fully Remove**: Yes (if tracked)

**Note**: Requires careful fstab manipulation. Recommend adding comments to fstab entries for identification.

---

### 10. Git Repository Management (Dotfiles)

**Module**: `dotfiles`

**Pattern**:
```bash
cd $HOME
git init
git remote add origin "$repo"
git fetch origin
git reset --hard origin/$branch
```

**Resources Created/Modified**:
- `$HOME/.git/` (entire home directory becomes git repo)
- Potentially overwrites ALL files in $HOME with remote versions
- Git config: `$HOME/.git/config`

**Uninstall Strategy**:
```bash
# DANGEROUS: Cannot simply remove (would delete all dotfiles)

# Option 1: Keep as-is (dotfiles remain)
# Option 2: De-initialize repo only
rm -rf ~/.git

# Option 3: Backup and restore original files (requires pre-install backup)
```

**Complexity**: VERY HIGH | **Can Fully Remove**: NO (destructive)

**Safety Level**: DESTRUCTIVE

**Note**: This module fundamentally changes $HOME. Uninstallation is not safe without comprehensive pre-install backup. Recommend "never uninstall" or "de-initialize repo only" approach.

---

### 11. Display Manager Installation + Configuration

**Module**: `greetd`

**Pattern**:
```bash
# Install packages
sudo dnf install -y greetd gtkgreet cage

# Configure
sudo tee /etc/greetd/config.toml << EOF
...
EOF

# Create theme CSS
mkdir -p ~/.config/gtkgreet
cat > ~/.config/gtkgreet/style.css << EOF
...
EOF
sudo cp ~/.config/gtkgreet/style.css /var/lib/greeter/.config/gtkgreet/

# Switch display managers
sudo systemctl disable sddm
sudo systemctl enable greetd
```

**Resources Created**:
- Packages: `greetd`, `gtkgreet`, `cage` (DNF)
- `/etc/greetd/config.toml`
- `~/.config/gtkgreet/style.css`
- `/var/lib/greeter/.config/gtkgreet/style.css`
- Systemd service enabled: `greetd.service`
- Previous DM disabled (which one?)

**Uninstall Strategy**:
```bash
# Switch back to previous display manager
sudo systemctl disable greetd
sudo systemctl enable sddm  # Or gdm, lightdm, etc. (must be tracked!)

# Remove packages
sudo dnf remove -y greetd gtkgreet cage

# Remove config files
sudo rm -rf /etc/greetd/
sudo rm -rf /var/lib/greeter/.config/gtkgreet/
rm -rf ~/.config/gtkgreet/
```

**Complexity**: MEDIUM-HIGH | **Can Fully Remove**: Yes

**Note**: Requires tracking which display manager was originally enabled.

---

### 12. Composite Installer (Multiple Packages from Different Sources)

**Module**: `niri`

**Pattern**:
```bash
# Main package from COPR
sudo dnf copr enable -y yalter/niri
sudo dnf install -y niri

# Ecosystem tools from Fedora repos
sudo dnf install -y hypridle hyprlock

# Enable services
systemctl --user enable --now hypridle
```

**Resources Created**:
- COPR repo: `yalter/niri`
- Main package: `niri` (from COPR)
- Ecosystem packages: `hypridle`, `hyprlock` (from Fedora repos)
- Systemd user service: `hypridle.service`

**Module**: `hyprland`

**Pattern**:
```bash
# Main package from Fedora repos
sudo dnf install -y hyprland

# Ecosystem tools from COPR
sudo dnf copr enable -y solopasha/hyprland
sudo dnf install -y hyprlock hypridle hyprpaper hyprland-plugin-hyprexpo
```

**Resources Created**:
- COPR repo: `solopasha/hyprland`
- Main package: `hyprland` (from Fedora repos)
- Ecosystem packages from COPR

**Uninstall Strategy**:
```bash
# Stop and disable services
systemctl --user stop hypridle
systemctl --user disable hypridle

# Remove packages
sudo dnf remove -y niri hypridle hyprlock  # For niri
# or
sudo dnf remove -y hyprland hyprlock hypridle hyprpaper hyprland-plugin-hyprexpo  # For hyprland

# Disable COPR repos
sudo dnf copr disable yalter/niri  # For niri
sudo dnf copr disable solopasha/hyprland  # For hyprland
```

**Complexity**: MEDIUM-HIGH | **Can Fully Remove**: Yes

**Note**: Multi-step removal. Some packages may be shared between niri and hyprland (hypridle, hyprlock).

---

## Proposed Framework Architecture

### Core Components

1. **Module Metadata Header** (Convention)
2. **Installation State Tracker** (`~/.kitbash/state.json`)
3. **Uninstall Helper Functions** (`lib/uninstall.sh`)
4. **Command-Line Interface** (Enhanced `kit-start.sh`)

---

### 1. Module Metadata Header

Add a standardized comment block to each module:

```bash
#!/bin/bash
# MODULE: obsidian
# TYPE: appimage
# PACKAGES: fuse-libs
# BINARIES: /usr/local/bin/obsidian
# FILES: /usr/share/applications/obsidian.desktop /usr/share/icons/hicolor/512x512/apps/obsidian.png
# DIRS:
# SERVICES:
# USERS:
# GROUPS:
# REPOS:
# USER_DATA: ~/.config/obsidian
# REMOVABLE: yes
# SAFETY: safe
```

**Metadata Fields**:

| Field | Description | Example |
|-------|-------------|---------|
| `MODULE` | Module identifier (matches filename without .sh) | `obsidian` |
| `TYPE` | Installation type (see types below) | `appimage` |
| `PACKAGES` | DNF packages installed | `fuse-libs docker-ce` |
| `BINARIES` | Executable files created | `/usr/local/bin/obsidian` |
| `FILES` | Non-binary files created | `/usr/share/applications/obsidian.desktop` |
| `DIRS` | Directories created | `/usr/lib/ollama` |
| `SERVICES` | Systemd services created/enabled | `ollama.service docker.service` |
| `USERS` | System users created | `ollama docker` |
| `GROUPS` | System groups created | `ollama docker` |
| `REPOS` | Repositories added | `copr:owner/project` or `file:/etc/yum.repos.d/vscode.repo` |
| `USER_DATA` | User data directories (optional removal) | `~/.config/obsidian ~/.aws` |
| `REMOVABLE` | Can be safely uninstalled? | `yes` / `no` / `partial` |
| `SAFETY` | Safety level (see below) | `safe` / `cautious` / `dangerous` / `destructive` |

**Installation Types**:
- `dnf_package` - Simple DNF package
- `repo_package` - Third-party repo + package
- `copr_package` - COPR repo + package
- `binary_download` - Downloaded binary/tarball extraction
- `binary_installer` - Downloaded binary with installer script
- `appimage` - AppImage installation
- `git_build` - Git clone + build/install script
- `font` - Font installation
- `config_only` - Configuration changes only
- `multi_config` - Complex multi-file configuration
- `dotfiles` - Dotfiles repository (special case)
- `display_manager` - Display manager installation/switch
- `composite` - Multiple packages from different sources

**Safety Levels**:
- `safe` - Can be automatically removed, no user data or shared resources
- `cautious` - Requires user confirmation, may affect shared resources
- `dangerous` - Requires explicit confirmation + backup, modifies system configs
- `destructive` - Cannot be safely auto-removed, manual intervention required

---

### 2. Installation State Tracker

**File**: `~/.kitbash/state.json`

**Format**:
```json
{
  "version": "1.0",
  "last_updated": "2025-11-12T14:30:00Z",
  "modules": {
    "obsidian": {
      "installed_at": "2025-11-12T08:51:00Z",
      "type": "appimage",
      "version": "1.10.3",
      "packages": ["fuse-libs"],
      "binaries": ["/usr/local/bin/obsidian"],
      "files": [
        "/usr/share/applications/obsidian.desktop",
        "/usr/share/icons/hicolor/512x512/apps/obsidian.png"
      ],
      "directories": [],
      "services": [],
      "users": [],
      "groups": [],
      "repos": [],
      "user_data": ["~/.config/obsidian"],
      "safety": "safe"
    },
    "docker": {
      "installed_at": "2025-11-10T16:20:00Z",
      "type": "repo_package",
      "packages": [
        "docker-ce",
        "docker-ce-cli",
        "containerd.io",
        "docker-buildx-plugin",
        "docker-compose-plugin"
      ],
      "binaries": ["/usr/bin/docker"],
      "files": ["/etc/yum.repos.d/docker-ce.repo"],
      "directories": ["/var/lib/docker"],
      "services": ["docker.service"],
      "users": [],
      "groups": ["docker"],
      "group_members": {
        "docker": ["david"]
      },
      "repos": ["file:/etc/yum.repos.d/docker-ce.repo"],
      "user_data": [],
      "safety": "cautious"
    },
    "hostname": {
      "installed_at": "2025-11-10T12:00:00Z",
      "type": "config_only",
      "original_values": {
        "hostname": "localhost.localdomain"
      },
      "current_values": {
        "hostname": "desktop"
      },
      "files": ["/etc/hostname"],
      "safety": "safe"
    }
  },
  "shared_resources": {
    "repos": {
      "rpmfusion-free": ["steam", "discord"],
      "rpmfusion-nonfree": ["steam", "discord"],
      "copr:solopasha/hyprland": ["hyprland"]
    },
    "packages": {
      "fuse-libs": ["obsidian"],
      "hypridle": ["niri", "hyprland"],
      "hyprlock": ["niri", "hyprland"]
    }
  }
}
```

**State File Operations**:

```bash
# lib/state.sh

# Record module installation
state_record_install() {
    local module=$1
    local type=$2
    # ... extract metadata from module header ...
    # ... append to state.json ...
}

# Mark module as removed
state_record_removal() {
    local module=$1
    # ... remove module from state.json ...
}

# Check if module is installed
state_is_installed() {
    local module=$1
    # ... query state.json ...
}

# Get module metadata
state_get_module() {
    local module=$1
    # ... return JSON object for module ...
}

# Check shared resource usage
state_get_shared_resource_users() {
    local resource_type=$1  # "repos" or "packages"
    local resource_name=$2
    # ... return array of modules using this resource ...
}

# Track shared resource
state_track_shared_resource() {
    local resource_type=$1
    local resource_name=$2
    local module=$3
    # ... add to shared_resources in state.json ...
}

# Untrack shared resource
state_untrack_shared_resource() {
    local resource_type=$1
    local resource_name=$2
    local module=$3
    # ... remove from shared_resources in state.json ...
}
```

---

### 3. Uninstall Helper Functions

**File**: `lib/uninstall.sh`

**Type-Specific Uninstall Functions**:

```bash
#!/bin/bash

# Source dependencies
source "$KITBASH_LIB/state.sh"
source "$KITBASH_LIB/logging.sh"

# ==============================================================================
# UNINSTALL FUNCTIONS BY TYPE
# ==============================================================================

# DNF Package Uninstaller
uninstall_dnf_package() {
    local module=$1
    local dry_run=$2

    log_info "Uninstalling DNF package: $module"

    local metadata=$(state_get_module "$module")
    local packages=$(echo "$metadata" | jq -r '.packages[]')

    if [ "$dry_run" = "true" ]; then
        log_step "Would remove packages: $packages"
        return 0
    fi

    if ! run_with_progress "removing packages" sudo dnf remove -y $packages; then
        log_error "Failed to remove packages"
        return $KIT_EXIT_MODULE_FAILED
    fi

    state_record_removal "$module"
    log_success "Module $module uninstalled"
}

# Repository + Package Uninstaller
uninstall_repo_package() {
    local module=$1
    local dry_run=$2

    log_info "Uninstalling repository package: $module"

    local metadata=$(state_get_module "$module")
    local packages=$(echo "$metadata" | jq -r '.packages[]')
    local repos=$(echo "$metadata" | jq -r '.repos[]')

    # Remove packages
    if [ "$dry_run" = "true" ]; then
        log_step "Would remove packages: $packages"
    else
        run_with_progress "removing packages" sudo dnf remove -y $packages
    fi

    # Check if repo is shared
    for repo in $repos; do
        local repo_name=$(basename "$repo")
        local shared_with=$(state_get_shared_resource_users "repos" "$repo_name")

        if [ ${#shared_with[@]} -gt 1 ]; then
            log_warning "Repository $repo_name is used by other modules: ${shared_with[@]}"
            log_warning "Not removing repository (use --force to override)"
        else
            if [ "$dry_run" = "true" ]; then
                log_step "Would remove repository: $repo"
            else
                if [[ "$repo" == file:* ]]; then
                    local repo_file="${repo#file:}"
                    run_with_progress "removing repository file" sudo rm "$repo_file"
                elif [[ "$repo" == copr:* ]]; then
                    local copr_name="${repo#copr:}"
                    run_with_progress "disabling COPR" sudo dnf copr disable "$copr_name"
                fi
            fi
        fi
    done

    if [ "$dry_run" != "true" ]; then
        state_record_removal "$module"
        log_success "Module $module uninstalled"
    fi
}

# AppImage Uninstaller
uninstall_appimage() {
    local module=$1
    local dry_run=$2

    log_info "Uninstalling AppImage: $module"

    local metadata=$(state_get_module "$module")
    local binaries=$(echo "$metadata" | jq -r '.binaries[]')
    local files=$(echo "$metadata" | jq -r '.files[]')

    if [ "$dry_run" = "true" ]; then
        log_step "Would remove binary: $binaries"
        log_step "Would remove files: $files"
        log_step "Would update desktop database"
        return 0
    fi

    # Remove binary
    for binary in $binaries; do
        run_with_progress "removing binary" sudo rm "$binary"
    done

    # Remove desktop entry and icons
    for file in $files; do
        run_with_progress "removing file" sudo rm "$file"
    done

    # Update desktop database
    run_quiet "updating desktop database" sudo update-desktop-database /usr/share/applications

    state_record_removal "$module"
    log_success "Module $module uninstalled"
}

# Binary Download Uninstaller
uninstall_binary_download() {
    local module=$1
    local dry_run=$2

    log_info "Uninstalling binary: $module"

    local metadata=$(state_get_module "$module")
    local binaries=$(echo "$metadata" | jq -r '.binaries[]')
    local files=$(echo "$metadata" | jq -r '.files[]')
    local dirs=$(echo "$metadata" | jq -r '.directories[]')
    local services=$(echo "$metadata" | jq -r '.services[]')
    local users=$(echo "$metadata" | jq -r '.users[]')
    local groups=$(echo "$metadata" | jq -r '.groups[]')

    if [ "$dry_run" = "true" ]; then
        [ -n "$services" ] && log_step "Would stop and disable services: $services"
        [ -n "$files" ] && log_step "Would remove service files: $files"
        [ -n "$binaries" ] && log_step "Would remove binaries: $binaries"
        [ -n "$dirs" ] && log_step "Would remove directories: $dirs"
        [ -n "$users" ] && log_step "Would remove users: $users"
        [ -n "$groups" ] && log_step "Would remove groups: $groups"
        return 0
    fi

    # Stop and disable services
    for service in $services; do
        run_with_progress "stopping service" sudo systemctl stop "$service"
        run_with_progress "disabling service" sudo systemctl disable "$service"
    done

    # Remove service files
    for file in $files; do
        run_with_progress "removing file" sudo rm "$file"
    done

    # Remove binaries
    for binary in $binaries; do
        run_with_progress "removing binary" sudo rm "$binary"
    done

    # Remove directories
    for dir in $dirs; do
        run_with_progress "removing directory" sudo rm -rf "$dir"
    done

    # Remove users
    for user in $users; do
        run_with_progress "removing user" sudo userdel "$user"
    done

    # Remove groups
    for group in $groups; do
        run_with_progress "removing group" sudo groupdel "$group" 2>/dev/null || true
    done

    # Reload systemd
    run_with_progress "reloading systemd" sudo systemctl daemon-reload

    state_record_removal "$module"
    log_success "Module $module uninstalled"
}

# Configuration-Only Uninstaller
uninstall_config_only() {
    local module=$1
    local dry_run=$2

    log_info "Reverting configuration: $module"

    local metadata=$(state_get_module "$module")
    local files=$(echo "$metadata" | jq -r '.files[]')
    local original_values=$(echo "$metadata" | jq -r '.original_values')

    if [ "$dry_run" = "true" ]; then
        log_step "Would remove files: $files"
        log_step "Would restore original values: $original_values"
        return 0
    fi

    # Remove created config files
    for file in $files; do
        if [ -f "$file" ]; then
            run_with_progress "removing config file" sudo rm "$file"
        fi
    done

    # Restore original values (module-specific logic)
    # This requires module-aware restoration logic
    case "$module" in
        hostname)
            local original_hostname=$(echo "$original_values" | jq -r '.hostname')
            run_with_progress "restoring hostname" sudo hostnamectl hostname "$original_hostname"
            ;;
        editor)
            local original_editor=$(echo "$original_values" | jq -r '.editor')
            git config --global core.editor "$original_editor"
            ;;
        # Add more cases as needed
    esac

    state_record_removal "$module"
    log_success "Module $module configuration reverted"
}

# Font Uninstaller
uninstall_font() {
    local module=$1
    local dry_run=$2

    log_info "Uninstalling fonts: $module"

    local metadata=$(state_get_module "$module")
    local files=$(echo "$metadata" | jq -r '.files[]')

    if [ "$dry_run" = "true" ]; then
        log_step "Would remove font files: $files"
        log_step "Would rebuild font cache"
        return 0
    fi

    # Remove font files
    for file in $files; do
        run_with_progress "removing font file" rm "$file"
    done

    # Rebuild font cache
    run_with_progress "rebuilding font cache" fc-cache -fv

    state_record_removal "$module"
    log_success "Fonts for $module uninstalled"
}

# Dotfiles Uninstaller (SPECIAL CASE - DANGEROUS)
uninstall_dotfiles() {
    local module=$1
    local dry_run=$2

    log_warning "Uninstalling dotfiles is a DESTRUCTIVE operation!"
    log_warning "This will de-initialize the git repository in your home directory."
    log_warning "Your dotfiles will remain, but git tracking will be removed."

    if [ "$dry_run" = "true" ]; then
        log_step "Would remove ~/.git directory"
        return 0
    fi

    read -p "Are you ABSOLUTELY SURE? Type 'yes' to continue: " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Uninstallation cancelled"
        return 0
    fi

    run_with_progress "removing git repository" rm -rf ~/.git

    state_record_removal "$module"
    log_success "Dotfiles git repository removed (files preserved)"
}

# Display Manager Uninstaller
uninstall_display_manager() {
    local module=$1
    local dry_run=$2

    log_info "Uninstalling display manager: $module"

    local metadata=$(state_get_module "$module")
    local packages=$(echo "$metadata" | jq -r '.packages[]')
    local services=$(echo "$metadata" | jq -r '.services[]')
    local files=$(echo "$metadata" | jq -r '.files[]')
    local dirs=$(echo "$metadata" | jq -r '.directories[]')
    local original_dm=$(echo "$metadata" | jq -r '.original_values.display_manager')

    if [ "$dry_run" = "true" ]; then
        log_step "Would disable services: $services"
        log_step "Would enable original DM: $original_dm"
        log_step "Would remove packages: $packages"
        log_step "Would remove files: $files"
        log_step "Would remove directories: $dirs"
        return 0
    fi

    # Disable current DM
    for service in $services; do
        run_with_progress "disabling service" sudo systemctl disable "$service"
    done

    # Re-enable original DM
    if [ -n "$original_dm" ]; then
        run_with_progress "enabling $original_dm" sudo systemctl enable "$original_dm"
    else
        log_warning "Original display manager unknown, please enable manually"
    fi

    # Remove packages
    run_with_progress "removing packages" sudo dnf remove -y $packages

    # Remove config files
    for file in $files; do
        sudo rm "$file" 2>/dev/null || true
    done

    # Remove directories
    for dir in $dirs; do
        sudo rm -rf "$dir" 2>/dev/null || true
    done

    state_record_removal "$module"
    log_success "Display manager $module uninstalled"
}

# Composite Uninstaller
uninstall_composite() {
    local module=$1
    local dry_run=$2

    log_info "Uninstalling composite module: $module"

    local metadata=$(state_get_module "$module")
    local packages=$(echo "$metadata" | jq -r '.packages[]')
    local services=$(echo "$metadata" | jq -r '.services[]')
    local repos=$(echo "$metadata" | jq -r '.repos[]')

    if [ "$dry_run" = "true" ]; then
        [ -n "$services" ] && log_step "Would stop and disable services: $services"
        [ -n "$packages" ] && log_step "Would remove packages: $packages"
        [ -n "$repos" ] && log_step "Would check repos: $repos"
        return 0
    fi

    # Stop and disable services
    for service in $services; do
        systemctl --user stop "$service" 2>/dev/null || true
        systemctl --user disable "$service" 2>/dev/null || true
    done

    # Remove packages (check for shared packages)
    local packages_to_remove=()
    for package in $packages; do
        local shared_with=$(state_get_shared_resource_users "packages" "$package")
        if [ ${#shared_with[@]} -gt 1 ]; then
            log_warning "Package $package is used by other modules: ${shared_with[@]}"
            log_warning "Not removing $package (use --force to override)"
        else
            packages_to_remove+=("$package")
        fi
    done

    if [ ${#packages_to_remove[@]} -gt 0 ]; then
        run_with_progress "removing packages" sudo dnf remove -y "${packages_to_remove[@]}"
    fi

    # Handle repos (similar to repo_package uninstaller)
    for repo in $repos; do
        local shared_with=$(state_get_shared_resource_users "repos" "$(basename "$repo")")
        if [ ${#shared_with[@]} -gt 1 ]; then
            log_warning "Repository $repo is used by other modules: ${shared_with[@]}"
        else
            if [[ "$repo" == copr:* ]]; then
                local copr_name="${repo#copr:}"
                run_with_progress "disabling COPR" sudo dnf copr disable "$copr_name"
            fi
        fi
    done

    state_record_removal "$module"
    log_success "Module $module uninstalled"
}

# ==============================================================================
# MAIN UNINSTALL DISPATCHER
# ==============================================================================

uninstall_module() {
    local module=$1
    local dry_run=${2:-false}
    local force=${3:-false}

    # Check if module is installed
    if ! state_is_installed "$module"; then
        log_error "Module $module is not installed"
        return $KIT_EXIT_MODULE_FAILED
    fi

    # Get module metadata
    local metadata=$(state_get_module "$module")
    local type=$(echo "$metadata" | jq -r '.type')
    local safety=$(echo "$metadata" | jq -r '.safety')

    # Safety checks
    case "$safety" in
        cautious)
            log_warning "This module has shared resources"
            if [ "$force" != "true" ]; then
                read -p "Continue? (y/N) " confirm
                [ "$confirm" != "y" ] && return 0
            fi
            ;;
        dangerous)
            log_warning "This module modifies system configuration"
            log_warning "A backup is recommended before proceeding"
            if [ "$force" != "true" ]; then
                read -p "Continue? (y/N) " confirm
                [ "$confirm" != "y" ] && return 0
            fi
            ;;
        destructive)
            log_error "This module cannot be safely auto-removed"
            log_error "Manual intervention required"
            return $KIT_EXIT_MODULE_FAILED
            ;;
    esac

    # Dispatch to type-specific uninstaller
    case "$type" in
        dnf_package)
            uninstall_dnf_package "$module" "$dry_run"
            ;;
        repo_package|copr_package)
            uninstall_repo_package "$module" "$dry_run"
            ;;
        appimage)
            uninstall_appimage "$module" "$dry_run"
            ;;
        binary_download|binary_installer)
            uninstall_binary_download "$module" "$dry_run"
            ;;
        config_only)
            uninstall_config_only "$module" "$dry_run"
            ;;
        font)
            uninstall_font "$module" "$dry_run"
            ;;
        dotfiles)
            uninstall_dotfiles "$module" "$dry_run"
            ;;
        display_manager)
            uninstall_display_manager "$module" "$dry_run"
            ;;
        composite)
            uninstall_composite "$module" "$dry_run"
            ;;
        *)
            log_error "Unknown module type: $type"
            return $KIT_EXIT_MODULE_FAILED
            ;;
    esac
}
```

---

### 4. Command-Line Interface

**Enhanced `kit-start.sh`**:

```bash
#!/bin/bash

# Parse arguments
ACTION="install"  # Default action
DRY_RUN=false
FORCE=false
MODULE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --list)
            ACTION="list"
            shift
            ;;
        --installed)
            ACTION="installed"
            shift
            ;;
        --info)
            ACTION="info"
            MODULE="$2"
            shift 2
            ;;
        --uninstall)
            ACTION="uninstall"
            MODULE="$2"
            shift 2
            ;;
        --reinstall)
            ACTION="reinstall"
            MODULE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            MODULE="$1"
            shift
            ;;
    esac
done

# Dispatch action
case "$ACTION" in
    list)
        list_available_modules
        ;;
    installed)
        list_installed_modules
        ;;
    info)
        show_module_info "$MODULE"
        ;;
    uninstall)
        uninstall_module "$MODULE" "$DRY_RUN" "$FORCE"
        ;;
    reinstall)
        uninstall_module "$MODULE" false "$FORCE" && install_module "$MODULE"
        ;;
    install)
        install_module "$MODULE"
        ;;
esac
```

**New Commands**:

```bash
# List all available modules
./kit-start.sh --list

# List installed modules
./kit-start.sh --installed

# Show module info (installed or available)
./kit-start.sh --info obsidian

# Dry-run uninstall (show what would be removed)
./kit-start.sh --uninstall obsidian --dry-run

# Uninstall module (with confirmation prompts)
./kit-start.sh --uninstall obsidian

# Force uninstall (skip confirmation prompts)
./kit-start.sh --uninstall obsidian --force

# Reinstall module (uninstall + install)
./kit-start.sh --reinstall obsidian
```

---

## Implementation Phases

### Phase 1: Foundation (State Tracking)

**Goal**: Establish state tracking infrastructure

**Tasks**:
1. Create `lib/state.sh` with JSON manipulation functions
2. Initialize `~/.kitbash/state.json` on first run
3. Add state recording to `module-runner.sh` after successful installation
4. Test state recording with 2-3 simple modules

**Deliverables**:
- `lib/state.sh` (new)
- `~/.kitbash/state.json` (auto-generated)
- Updated `lib/module-runner.sh`

**Estimated Complexity**: Low-Medium

---

### Phase 2: Module Metadata

**Goal**: Add metadata headers to all modules

**Tasks**:
1. Design final metadata format (based on proposal above)
2. Add metadata extraction function to `lib/state.sh`
3. Add metadata headers to all 27 modules
4. Create validation script to ensure metadata matches reality

**Deliverables**:
- All 27 module files updated with metadata headers
- `scripts/validate-metadata.sh` (new)

**Estimated Complexity**: Medium (time-consuming but straightforward)

---

### Phase 3: Uninstall Framework

**Goal**: Implement core uninstallation functionality

**Tasks**:
1. Create `lib/uninstall.sh` with type-specific uninstallers
2. Implement shared resource checking
3. Add safety level enforcement
4. Add `--uninstall` flag to `kit-start.sh`
5. Implement dry-run mode

**Deliverables**:
- `lib/uninstall.sh` (new)
- Updated `kit-start.sh`

**Estimated Complexity**: High

---

### Phase 4: Enhanced Commands

**Goal**: Polish user experience

**Tasks**:
1. Add `--list` command (list available modules)
2. Add `--installed` command (list installed modules with details)
3. Add `--info` command (show module details)
4. Add `--reinstall` command (convenience)
5. Improve output formatting (colors, tables)

**Deliverables**:
- Updated `kit-start.sh`
- Improved logging/formatting

**Estimated Complexity**: Medium

---

### Phase 5: Testing & Documentation

**Goal**: Ensure reliability and usability

**Tasks**:
1. Test uninstallation for each module type
2. Test shared resource scenarios
3. Test safety prompts
4. Update README with new commands
5. Update CLAUDE.md with uninstall framework details

**Deliverables**:
- Updated README.md
- Updated CLAUDE.md
- Test results documentation

**Estimated Complexity**: Medium

---

## Uninstallation Complexity Matrix

| Module | Type | Safety | Shared Resources | Complexity | Notes |
|--------|------|--------|------------------|------------|-------|
| alacritty | dnf_package | safe | - | Low | Simple DNF removal |
| awscli | binary_installer | safe | - | Low | Remove dirs + symlinks |
| copyq | dnf_package | safe | - | Low | Simple DNF removal |
| cursor | config_only | dangerous | Many config files | Very High | Modifies 5+ config files |
| discord | repo_package | cautious | RPM Fusion repos | Medium | Shared repo with steam |
| docker | repo_package | cautious | Group, data dir | Medium-High | Group membership, /var/lib/docker |
| dotfiles | dotfiles | destructive | $HOME as repo | VERY HIGH | Cannot safely auto-remove |
| editor | config_only | safe | Git config | Low | Revert git config + env vars |
| font | font | safe | - | Medium | Need to track font files |
| google_chrome | repo_package | safe | - | Low | Remove package + repo |
| greetd | display_manager | dangerous | Disables other DM | Medium-High | Must track original DM |
| hyprland | composite | cautious | Shared packages | High | hypridle/hyprlock shared with niri |
| jq | dnf_package | safe | - | Low | Simple DNF removal |
| mounts | multi_config | dangerous | /etc/fstab | High | Modifies shared system file |
| niri | composite | cautious | Shared packages | High | hypridle/hyprlock shared with hyprland |
| obsidian | appimage | safe | fuse-libs (shared) | Low | Simple binary + desktop entry removal |
| ollama | binary_download | safe | - | Medium | Service + user + binary |
| power_never_sleep | config_only | safe | - | Low | Remove config files |
| sddm | config_only | safe | - | Low | Revert theme in /etc/sddm.conf |
| steam | repo_package | cautious | RPM Fusion repos | Medium | Shared repo with discord |
| sudo_timeout | config_only | safe | - | Low | Remove sudoers.d file |
| synology | copr_package | safe | - | Low | Remove package + COPR |
| terminal | config_only | safe | - | Low | Remove update-alternatives entry |
| theme | git_build | safe | Theme dependencies | Medium | Remove theme dirs + reset gsettings |
| vscode | repo_package | safe | - | Low | Remove package + repo file |
| wallpaper | multi_config | dangerous | Many config files | VERY HIGH | Modifies 10+ config files |

---

## Shared Resource Management

### Problem

Some resources are shared between multiple modules:

**Example 1: RPM Fusion Repositories**
- `steam` module enables RPM Fusion
- `discord` module enables RPM Fusion
- If user uninstalls `steam`, should RPM Fusion be removed?
  - **No**, because `discord` still needs it

**Example 2: Shared Packages**
- `niri` module installs `hypridle` and `hyprlock`
- `hyprland` module also installs `hypridle` and `hyprlock`
- If user uninstalls `niri`, should these packages be removed?
  - **No**, if `hyprland` is still installed

### Solution: Reference Counting

Track which modules use each shared resource in `state.json`:

```json
{
  "shared_resources": {
    "repos": {
      "rpmfusion-free": ["steam", "discord"],
      "rpmfusion-nonfree": ["steam", "discord"],
      "copr:solopasha/hyprland": ["hyprland"]
    },
    "packages": {
      "fuse-libs": ["obsidian"],
      "hypridle": ["niri", "hyprland"],
      "hyprlock": ["niri", "hyprland"]
    }
  }
}
```

**Uninstall Logic**:

```bash
# When uninstalling a module:
for package in $packages_to_remove; do
    shared_with=$(state_get_shared_resource_users "packages" "$package")

    if [ ${#shared_with[@]} -gt 1 ]; then
        log_warning "Package $package is used by other modules: ${shared_with[@]}"
        log_warning "Not removing $package (use --force to override)"
    else
        # Safe to remove
        sudo dnf remove -y "$package"
    fi
done
```

**Force Override**:
```bash
./kit-start.sh --uninstall niri --force
# Removes hypridle/hyprlock even if hyprland is installed
# Logs warning about potentially breaking hyprland
```

---

## API Design

### Command Summary

```bash
# Installation (existing)
./kit-start.sh                      # Run all enabled modules from kit.conf
./kit-start.sh <module>             # Run specific module

# Information (new)
./kit-start.sh --list               # List all available modules
./kit-start.sh --installed          # List installed modules with metadata
./kit-start.sh --info <module>      # Show module details (metadata + status)

# Uninstallation (new)
./kit-start.sh --uninstall <module>                # Uninstall with prompts
./kit-start.sh --uninstall <module> --dry-run      # Show what would be removed
./kit-start.sh --uninstall <module> --force        # Skip confirmation prompts

# Maintenance (new)
./kit-start.sh --reinstall <module>                # Uninstall + install
./kit-start.sh --verify <module>                   # Check if module is healthy
```

---

### Example Outputs

#### `--list`
```
Available Modules:
  alacritty          Terminal emulator [NOT INSTALLED]
  awscli             AWS CLI v2 [INSTALLED: v2.15.0]
  copyq              Clipboard manager [NOT INSTALLED]
  cursor             Cursor theme configuration [INSTALLED]
  discord            Discord chat client [NOT INSTALLED]
  docker             Docker container platform [INSTALLED]
  ...
```

#### `--installed`
```
Installed Modules (8):

obsidian              (appimage)
  Installed: 2025-11-12 08:51:00
  Version: 1.10.3
  Safety: safe
  Packages: fuse-libs
  Files: 3

docker                (repo_package)
  Installed: 2025-11-10 16:20:00
  Safety: cautious
  Packages: 5
  Services: docker.service
  Shared: docker group (member: david)

hostname              (config_only)
  Installed: 2025-11-10 12:00:00
  Safety: safe
  Current: desktop (was: localhost.localdomain)
```

#### `--info obsidian`
```
Module: obsidian
Status: INSTALLED
Type: appimage
Safety: safe
Installed: 2025-11-12 08:51:00
Version: 1.10.3

Resources:
  Packages: fuse-libs (shared with: -)
  Binaries: /usr/local/bin/obsidian
  Files:
    - /usr/share/applications/obsidian.desktop
    - /usr/share/icons/hicolor/512x512/apps/obsidian.png
  User Data: ~/.config/obsidian (preserved on uninstall)

Can be uninstalled: yes
```

#### `--uninstall obsidian --dry-run`
```
[DRY RUN] Uninstalling AppImage: obsidian

Would perform:
  - Remove binary: /usr/local/bin/obsidian
  - Remove file: /usr/share/applications/obsidian.desktop
  - Remove file: /usr/share/icons/hicolor/512x512/apps/obsidian.png
  - Update desktop database
  - Remove from state file

User data preserved:
  - ~/.config/obsidian

Shared resources (not removed):
  - Package: fuse-libs (no other modules depend on this)

No other modules would be affected.
```

#### `--uninstall docker`
```
[INFO] Uninstalling repository package: docker
[WARNING] This module has shared resources
Continue? (y/N) y
[  ] removing packages ... done
[WARNING] You are a member of the docker group
[WARNING] Log out and back in for group changes to take effect
[  ] removing repository file ... done
[SUCCESS] Module docker uninstalled
```

---

## Safety and Rollback

### Safety Levels

**SAFE**
- Can be automatically removed
- No user data or shared resources affected
- Examples: `alacritty`, `jq`, `copyq`, `obsidian`

**CAUTIOUS**
- Requires user confirmation
- May affect shared resources (repos, packages)
- Examples: `docker`, `steam`, `discord`, `niri`, `hyprland`

**DANGEROUS**
- Requires explicit confirmation + backup recommendation
- Modifies system configuration files
- Examples: `cursor`, `wallpaper`, `mounts`, `greetd`

**DESTRUCTIVE**
- Cannot be safely auto-removed
- Requires manual intervention
- Examples: `dotfiles`

---

### Pre-Uninstall Checks

Before uninstalling, perform safety checks:

1. **Is module installed?**
   - Check state file
   - Error if not installed

2. **What resources will be affected?**
   - List packages, files, services, etc.
   - Check for shared resources

3. **Will other modules be affected?**
   - Check if other modules depend on this module's resources
   - Warn user

4. **Is user data at risk?**
   - List user data directories that will be preserved
   - Offer option to remove user data

---

### Rollback Strategy

**For most modules**: No rollback needed - uninstall is final

**For config-only modules**: Support rollback by tracking original values

Example:
```json
{
  "hostname": {
    "type": "config_only",
    "original_values": {
      "hostname": "localhost.localdomain"
    },
    "current_values": {
      "hostname": "desktop"
    }
  }
}
```

When uninstalling, restore `original_values`.

**For complex modules** (wallpaper, mounts, cursor):
- Consider creating backups of config files before modification
- Store backups in `~/.kitbash/backups/<module>/`
- Restore from backup on uninstall

---

## Conclusion

This proposal provides a comprehensive framework for standardized installation tracking and safe uninstallation across all 27 kitbash modules. The framework:

1. **Categorizes modules by installation type** (12 distinct patterns)
2. **Tracks installation state** (`~/.kitbash/state.json`)
3. **Implements type-specific uninstallers** (`lib/uninstall.sh`)
4. **Manages shared resources** (reference counting)
5. **Enforces safety levels** (safe, cautious, dangerous, destructive)
6. **Provides user-friendly commands** (`--list`, `--installed`, `--info`, `--uninstall`)

### Key Benefits

- **"Get shit done" philosophy maintained** - Simple, practical, effective
- **Safe uninstallation** - Prevents breaking the system or other modules
- **User visibility** - Clear understanding of what's installed and what removal entails
- **Extensible** - Easy to add new module types in the future
- **Backwards compatible** - Existing modules continue to work without modification (Phase 1)

### Next Steps

1. Review and approve this proposal
2. Begin Phase 1 implementation (state tracking)
3. Incrementally add uninstall support module-by-module
4. Test thoroughly before marking as stable

---

**End of Proposal**
