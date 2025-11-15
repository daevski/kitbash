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
# Set KITBASH_REQUIRE_CONFIG=false to make config optional (for module mode)
load_config() {
    local require_config="${KITBASH_REQUIRE_CONFIG:-true}"

    # Assert that kit.conf exists
    if [ ! -f "$KITBASH_CONFIG" ]; then
        # Only error out if config is required (bootstrap/setup mode)
        if [ "$require_config" = "true" ]; then
            echo "ERROR: Configuration file not found: $KITBASH_CONFIG" >&2
            echo "" >&2
            echo "Kitbash requires a customized configuration file to run." >&2
            echo "" >&2

            # Check if example exists to provide helpful guidance
            if [ -f "$KITBASH_CONFIG_EXAMPLE" ]; then
                # If running interactively, offer to create config
                if [ -t 0 ] && [ -t 1 ]; then
                    echo "Would you like to create kit.conf now? [Y/n]: " >&2
                    read -r response
                    response="${response:-y}"  # Default to yes

                    if [[ "$response" =~ ^[Yy]$ ]]; then
                        echo "Copying example configuration..." >&2
                        if cp "$KITBASH_CONFIG_EXAMPLE" "$KITBASH_CONFIG"; then
                            echo "Configuration file created: $KITBASH_CONFIG" >&2
                            echo "" >&2
                            echo "Opening configuration in your editor..." >&2
                            echo "Please customize these settings:" >&2
                            echo "  - _hostname (your system hostname)" >&2
                            echo "  - _terminal (alacritty, kitty, gnome-terminal)" >&2
                            echo "  - _editor (vim, nvim, nano, code)" >&2
                            echo "  - Enable/disable optional modules (true/false)" >&2
                            echo "" >&2
                            echo "Press Enter when ready to edit..." >&2
                            read -r

                            # Determine which editor to use
                            local editor="${EDITOR:-vim}"
                            if ! command -v "$editor" >/dev/null 2>&1; then
                                editor="vi"  # Fallback to vi (always available)
                            fi

                            # Open editor
                            "$editor" "$KITBASH_CONFIG"

                            # After editing, reload config
                            echo "" >&2
                            echo "Configuration saved. Continuing with setup..." >&2
                            source "$KITBASH_CONFIG"
                            return $KIT_EXIT_SUCCESS
                        else
                            echo "ERROR: Failed to copy configuration file" >&2
                            return $KIT_EXIT_CONFIG_MISSING
                        fi
                    else
                        echo "Setup cancelled. Please create kit.conf manually:" >&2
                        echo "  cp $KITBASH_CONFIG_EXAMPLE $KITBASH_CONFIG" >&2
                        return $KIT_EXIT_USER_CANCELLED
                    fi
                else
                    # Non-interactive - show manual instructions
                    echo "To get started, copy the example configuration and customize it:" >&2
                    echo "  cp $KITBASH_CONFIG_EXAMPLE $KITBASH_CONFIG" >&2
                    echo "" >&2
                    echo "Then edit $KITBASH_CONFIG to match your preferences:" >&2
                    echo "  - Set your hostname (_hostname)" >&2
                    echo "  - Choose your terminal emulator (_terminal)" >&2
                    echo "  - Choose your editor (_editor)" >&2
                    echo "  - Enable/disable optional modules" >&2
                    echo "" >&2
                    return $KIT_EXIT_CONFIG_MISSING
                fi
            else
                echo "ERROR: Template file also missing: $KITBASH_CONFIG_EXAMPLE" >&2
                echo "Please ensure you're running kitbash from the correct directory." >&2
                echo "" >&2
                return $KIT_EXIT_CONFIG_MISSING
            fi
        else
            # Config optional - just warn and continue
            if command -v log_debug >/dev/null 2>&1; then
                log_debug "Configuration file not found, but not required for this operation"
            fi
            return $KIT_EXIT_SUCCESS
        fi
    fi

    # Use log_debug if available (logging may not be loaded yet)
    if command -v log_debug >/dev/null 2>&1; then
        log_debug "Loading configuration from: $KITBASH_CONFIG"
    fi
    source "$KITBASH_CONFIG"
    return $KIT_EXIT_SUCCESS
}

# Validate required configuration variables
# Set KITBASH_REQUIRE_CONFIG=false to skip validation (for module mode)
validate_config() {
    local require_config="${KITBASH_REQUIRE_CONFIG:-true}"

    # Skip validation if config is not required (module mode)
    if [ "$require_config" = "false" ]; then
        if command -v log_debug >/dev/null 2>&1; then
            log_debug "Skipping configuration validation (not required for this operation)"
        fi
        return $KIT_EXIT_SUCCESS
    fi

    local errors=0

    # Required preferences that must be set
    local required_prefs=(
        "_hostname"
        "_terminal"
        "_editor"
    )

    # Use log_debug if available (logging may not be loaded yet)
    if command -v log_debug >/dev/null 2>&1; then
        log_debug "Validating configuration..."
    fi

    for pref in "${required_prefs[@]}"; do
        if [ -z "${!pref}" ]; then
            echo "ERROR: Required configuration variable '$pref' is not set" >&2
            echo "  Please define $pref in $KITBASH_CONFIG" >&2
            errors=$((errors + 1))
        else
            if command -v log_debug >/dev/null 2>&1; then
                log_debug "✓ $pref = ${!pref}"
            fi
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

    # Use log_debug if available (logging may not be loaded yet)
    if command -v log_debug >/dev/null 2>&1; then
        log_debug "Configuration validation passed"
    fi
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
