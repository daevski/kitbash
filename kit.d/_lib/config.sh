#!/bin/bash
# Configuration management for Kitbash
# This library handles loading and validating configuration files

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_CONFIG_MISSING=2
readonly EXIT_CONFIG_INVALID=3

# Load configuration file with precedence
# Priority: kit.conf > kit.conf.example
load_config() {
    local config_loaded=false

    # Try to load user's custom config first
    if [ -f "$KITBASH_CONFIG" ]; then
        echo "[DEBUG] Loading configuration from: $KITBASH_CONFIG" >&2
        source "$KITBASH_CONFIG"
        config_loaded=true
    elif [ -f "$KITBASH_CONFIG_EXAMPLE" ]; then
        # Fall back to example config
        echo "[INFO] No kit.conf found, using defaults from kit.conf.example" >&2
        echo "[INFO] To customize: cp $KITBASH_CONFIG_EXAMPLE $KITBASH_CONFIG" >&2
        source "$KITBASH_CONFIG_EXAMPLE"
        config_loaded=true
    else
        echo "ERROR: No configuration file found!" >&2
        echo "" >&2
        echo "Kitbash requires a configuration file to run." >&2
        echo "Expected one of:" >&2
        echo "  - $KITBASH_CONFIG (your custom config)" >&2
        echo "  - $KITBASH_CONFIG_EXAMPLE (default template)" >&2
        echo "" >&2
        echo "Please ensure you're running kitbash from the correct directory." >&2
        return $EXIT_CONFIG_MISSING
    fi

    if [ "$config_loaded" = true ]; then
        return $EXIT_SUCCESS
    else
        return $EXIT_CONFIG_MISSING
    fi
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

    echo "[DEBUG] Validating configuration..." >&2

    for pref in "${required_prefs[@]}"; do
        if [ -z "${!pref}" ]; then
            echo "ERROR: Required configuration variable '$pref' is not set" >&2
            echo "  Please define $pref in $KITBASH_CONFIG" >&2
            errors=$((errors + 1))
        else
            echo "[DEBUG] ✓ $pref = ${!pref}" >&2
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
        return $EXIT_CONFIG_INVALID
    fi

    echo "[DEBUG] Configuration validation passed" >&2
    return $EXIT_SUCCESS
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

    return $EXIT_SUCCESS
}
