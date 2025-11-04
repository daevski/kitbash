#!/bin/bash
# Configuration management for Kitbash
# This library handles loading and validating configuration files

# Load exit codes (should already be loaded by caller, but ensure it's available)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "$KIT_EXIT_SUCCESS" ]; then
    source "$SCRIPT_DIR/exitcodes.sh"
fi

# Load configuration file
# Requires kit.conf to exist - will NOT fall back to kit.conf.example
load_config() {
    # Assert that kit.conf exists
    if [ ! -f "$KITBASH_CONFIG" ]; then
        echo "ERROR: Configuration file not found: $KITBASH_CONFIG" >&2
        echo "" >&2
        echo "Kitbash requires a customized configuration file to run." >&2
        echo "" >&2

        # Check if example exists to provide helpful guidance
        if [ -f "$KITBASH_CONFIG_EXAMPLE" ]; then
            echo "To get started, copy the example configuration and customize it:" >&2
            echo "  cp $KITBASH_CONFIG_EXAMPLE $KITBASH_CONFIG" >&2
            echo "" >&2
            echo "Then edit $KITBASH_CONFIG to match your preferences:" >&2
            echo "  - Set your hostname (_hostname)" >&2
            echo "  - Choose your terminal emulator (_terminal)" >&2
            echo "  - Choose your editor (_editor)" >&2
            echo "  - Enable/disable optional modules" >&2
        else
            echo "ERROR: Template file also missing: $KITBASH_CONFIG_EXAMPLE" >&2
            echo "Please ensure you're running kitbash from the correct directory." >&2
        fi
        echo "" >&2
        return $KIT_EXIT_CONFIG_MISSING
    fi

    log_debug "Loading configuration from: $KITBASH_CONFIG"
    source "$KITBASH_CONFIG"
    return $KIT_EXIT_SUCCESS
}

# Validate required configuration variables
validate_config() {
    local errors=0

    # Required preferences that must be set
    local required_prefs=(
        "_hostname"
        "_terminal"
        "_editor"
    )

    log_debug "Validating configuration..."

    for pref in "${required_prefs[@]}"; do
        if [ -z "${!pref}" ]; then
            echo "ERROR: Required configuration variable '$pref' is not set" >&2
            echo "  Please define $pref in $KITBASH_CONFIG" >&2
            errors=$((errors + 1))
        else
            log_debug "✓ $pref = ${!pref}"
        fi
    done

    # Validate wallpaper targets array if wallpaper is configured
    if [ -n "$_wallpaper" ]; then
        if [ -z "${_wallpaper_targets[*]}" ]; then
            echo "WARNING: _wallpaper is set but _wallpaper_targets array is empty" >&2
            echo "  Setting default: desktop, lock, login" >&2
            _wallpaper_targets=("desktop" "lock" "login")
        fi
    fi

    # Validate cursor configuration
    if [ -n "$_cursor" ] && [ -z "$_cursor_size" ]; then
        echo "WARNING: _cursor is set but _cursor_size is not defined" >&2
        echo "  Setting default cursor size: 24" >&2
        _cursor_size=24
    fi

    if [ $errors -gt 0 ]; then
        echo "" >&2
        echo "Configuration validation failed with $errors error(s)" >&2
        echo "Please fix the issues above and try again" >&2
        return $KIT_EXIT_CONFIG_INVALID
    fi

    log_debug "Configuration validation passed"
    return $KIT_EXIT_SUCCESS
}

# Display current configuration (for debugging)
show_config() {
    echo "Kitbash Configuration:"
    echo "  Hostname: ${_hostname:-<not set>}"
    echo "  Terminal: ${_terminal:-<not set>}"
    echo "  Editor: ${_editor:-<not set>}"
    echo "  Wallpaper: ${_wallpaper:-<not set>}"
    echo "  Cursor: ${_cursor:-<not set>} (size: ${_cursor_size:-<not set>})"
    echo "  Font: ${_font:-<not set>}"
    echo ""
    echo "Modules:"
    echo "  Docker: ${_docker:-false}"
    echo "  Dotfiles: ${_dotfiles:-false}"
    echo "  Google Chrome: ${_google_chrome:-false}"
    echo "  Mounts: ${_mounts:-false}"
    echo "  Ollama: ${_ollama:-false}"
    echo "  Power (never sleep): ${_power_never_sleep:-false}"
    echo "  SDDM: ${_sddm:-false}"
    echo "  Synology: ${_synology:-false}"
    echo "  VS Code: ${_vscode:-false}"
}

# Get the value of a preference variable
# Usage: get_pref "_hostname"
get_pref() {
    local pref_name="$1"
    echo "${!pref_name}"
}

# Check if a module is enabled
# Usage: is_module_enabled "_docker"
is_module_enabled() {
    local module_pref="$1"
    local value="${!module_pref}"

    # Boolean check - true, yes, 1, or non-empty value
    if [[ "$value" == "true" ]] || [[ "$value" == "yes" ]] || [[ "$value" == "1" ]]; then
        return 0  # enabled
    elif [[ "$value" == "false" ]] || [[ "$value" == "no" ]] || [[ "$value" == "0" ]] || [[ -z "$value" ]]; then
        return 1  # disabled
    else
        # Non-boolean value (like a path or string) - consider it enabled
        return 0
    fi
}

# Initialize configuration system
# This is the main entry point for config management
init_config() {
    if ! load_config; then
        return $?
    fi

    if ! validate_config; then
        return $?
    fi

    return $KIT_EXIT_SUCCESS
}
