# Kitbash - Modular Linux System Setup Tool

A flexible, modular system configuration tool for Linux (optimized for Fedora). Kitbash provides a clean, scriptable way to configure fresh systems or update existing ones with minimal manual intervention.

> [Kitbashing](http://perplexity.ai/?q=what+is+kitbashing) (in a generic sense) is the process of creating something by combining and altering parts from different kits to create a new, unique design. This technique is popular in hobbies like model building, tabletop gaming, and digital art to make custom figures, scenes, or assets. It involves cutting, gluing, and sculpting pieces, but can also be done digitally to repurpose 3D assets.

## Features

- **Modular Design**: Each feature is self-contained and can be run independently
- **Configuration-Driven**: All preferences centralized in `kit.conf`
- **Clean Console Output**: Minimal, progress-focused console messages with detailed logging to `~/kit.log`
- **Dynamic Discovery**: Scripts automatically discover and validate available modules
- **Dual Monitor Support**: Intelligent wallpaper handling for multiple displays
- **Fedora Optimized**: Designed specifically for Fedora Linux installations
- **Stand-alone Tool**: No longer tied to `$HOME`; can be installed and run from any directory

## Quick Start

### 🚀 One-Line Installation

```bash
# Interactive setup (will prompt for configuration)
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/kitbash/main/kit-start.sh | bash

# With custom dotfiles repo
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/kitbash/main/kit-start.sh | bash -s -- --repo yourusername/dotfiles
```

### 📋 Manual Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/kitbash.git ~/kitbash
   cd ~/kitbash
   ```

2. **Create your configuration:**
   ```bash
   cp kit.conf.example kit.conf
   # Edit kit.conf with your preferences
   ```

3. **Run setup:**
   ```bash
   ./kit-start.sh                    # Run all configured modules
   ./kit-start.sh wallpaper          # Run specific module
   ./kit-start.sh help               # See all options
   ```

## Configuration

### Setup File (`kit.conf`)

Create a `kit.conf` file with your preferences:

```bash
# Required preferences
_hostname='my-computer'
_editor='vim'
_wallpaper='fractal-colors'  # Or path to image file
_cursor='breeze_cursors'
_cursor_size='24'

# Optional modules (true/false or custom values)
_docker=false
_vscode=true
_google_chrome=true
_terminal='alacritty'
_font='AudioLink Mono'

# Wallpaper configuration
_wallpaper_targets=("desktop" "lock" "login")

# Predefined wallpapers (name:url)
_wallpaper_definitions=(
    "fractal-colors:https://example.com/wallpaper.jpg"
    "custom-wallpaper:https://example.com/custom.jpg"
)

# Predefined fonts (name:url)
_font_definitions=(
    "AudioLink Mono:https://audiolink.dev/gallery/AudioLinkMono.zip"
)
```

## Available Modules

Kitbash includes the following modules in `kit.d/`:

### System Configuration
- **hostname.sh** - Set system hostname
- **editor.sh** - Configure default text editor
- **terminal.sh** - Set default terminal emulator
- **sudo_timeout.sh** - Configure sudo password timeout

### Desktop Environment
- **wallpaper.sh** - Desktop, lock screen, and login wallpaper
- **cursor.sh** - Cursor theme configuration
- **font.sh** - Font installation and configuration
- **sddm.sh** - SDDM login manager setup
- **power_never_sleep.sh** - Power management configuration

### Applications
- **docker.sh** - Docker installation and user setup
- **vscode.sh** - Visual Studio Code repository setup
- **google_chrome.sh** - Google Chrome repository setup
- **ollama.sh** - Ollama AI runtime installation
- **synology.sh** - Synology Drive installation

### System Integration
- **dotfiles.sh** - Clone and manage dotfiles repository
- **mounts.sh** - Configure mount points and symlinks

## Usage Examples

```bash
# Run all modules configured in kit.conf
./kit-start.sh

# Run specific modules
./kit-start.sh wallpaper
./kit-start.sh vscode docker

# Override preferences for one-time use
./kit-start.sh wallpaper ~/Pictures/new-wallpaper.jpg
./kit-start.sh editor code
./kit-start.sh hostname my-new-hostname

# Get help
./kit-start.sh help
```

## Logging System

Kitbash uses a dual-output logging approach:

- **Console**: Clean, minimal progress indicators showing what's happening
- **Log File** (`~/kit.log`): Detailed timestamped logs with full command output, debug information, and error details

When troubleshooting issues, always check `~/kit.log` for complete details about what happened during setup.

Example console output:
```
[INFO] Initializing...
[INFO] Running module: font (value: AudioLink Mono)
  installing font: AudioLink Mono
  downloading font ... done
  extracting archive ... done
  copying font files
  rebuilding font cache ... done
[SUCCESS] Module 'font' completed
```

## Creating Custom Modules

1. Create a new script in `kit.d/`:
   ```bash
   touch kit.d/mymodule.sh
   chmod +x kit.d/mymodule.sh
   ```

2. Add logging to your module:
   ```bash
   #!/bin/bash

   # Module configuration
   MY_VALUE="${1:-$_mymodule}"

   log_step "configuring my feature"

   if run_with_progress "installing something" sudo dnf install -y package; then
       log_debug "Installation successful"
   else
       log_error "Installation failed"
       exit 1
   fi
   ```

3. Add preference to `kit.conf`:
   ```bash
   _mymodule=true
   # Or with a custom value
   _mymodule="custom-value"
   ```

4. Run your module:
   ```bash
   ./kit-start.sh mymodule
   ```

## Architecture

### Bootstrap Script (`kit-start.sh`)
The main entry point that handles:
- Repository cloning (when run via curl)
- Initial system setup
- Module discovery and execution

### Library Functions (`lib/`)
Core infrastructure for the kitbash tool:
- **exitcodes.sh** - Standardized exit codes and error handling
- **paths.sh** - Path detection and management
- **config.sh** - Configuration loading and validation
- **logging.sh** - Dual console/file logging system
- **module-runner.sh** - Module discovery and execution
- **setup-functions.sh** - Setup helper functions
- **validation.sh** - Configuration validation

### Module Scripts (`kit.d/*.sh`)
Self-contained scripts that configure specific features. Each module:
- Uses the logging library for clean output
- Can be run independently
- Accepts configuration from `kit.conf` or command-line arguments
- Returns appropriate exit codes

## Integration with Dotfiles

Kitbash works seamlessly with dotfiles repositories through the `dotfiles.sh` module:

1. Set your dotfiles repo in `kit.conf`:
   ```bash
   _dotfiles_repo="yourusername/dotfiles"
   ```

2. Run the dotfiles module:
   ```bash
   ./kit-start.sh dotfiles
   ```

This will clone your dotfiles and initialize a dedicated directory (not `$HOME`) as a git repository, allowing you to track your personal configuration files separately from the kitbash tool.

## Exit Codes

Kitbash uses consistent exit codes across all modules for predictable error handling:

| Exit Code | Constant | Description |
|-----------|----------|-------------|
| `0` | `KIT_EXIT_SUCCESS` | Operation completed successfully |
| `1` | `KIT_EXIT_ERROR` | General/unspecified error |
| `2` | `KIT_EXIT_CONFIG_MISSING` | Configuration file not found |
| `3` | `KIT_EXIT_CONFIG_INVALID` | Configuration file is invalid or malformed |
| `3` | `KIT_EXIT_DEPENDENCY_MISSING` | Required dependency not installed |
| `4` | `KIT_EXIT_PERMISSION_DENIED` | Insufficient permissions |
| `5` | `KIT_EXIT_MODULE_FAILED` | Module execution failed |
| `6` | `KIT_EXIT_MODULE_SKIPPED` | Module intentionally skipped |
| `7` | `KIT_EXIT_NETWORK_ERROR` | Network/download error |
| `8` | `KIT_EXIT_USER_CANCELLED` | User cancelled operation |
| `9` | `KIT_EXIT_INVALID_INPUT` | Invalid user input |

These constants are defined in `lib/exitcodes.sh` and are available to all scripts via sourcing.

### Usage in Scripts

```bash
# Source exit codes
source "$KITBASH_LIB/exitcodes.sh"

# Use exit codes
if ! some_command; then
    echo "ERROR: Command failed" >&2
    return $KIT_EXIT_ERROR
fi

# Helper functions
exit_with $KIT_EXIT_CONFIG_MISSING "Config file not found"      # Exits script
return_with $KIT_EXIT_MODULE_FAILED "Module failed to execute"  # Returns from function
```

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

## License

MIT License - feel free to use and modify for your own needs.

## Credits

Created by David as a modular alternative to monolithic system setup scripts.
