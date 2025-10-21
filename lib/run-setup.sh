#!/bin/bash

# Main setup function - can be sourced or executed directly
main_setup() {
    # Get the directory of this script
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Load exit codes first (needed by all other libraries)
    source "$KITBASH_LIB/exitcodes.sh"

    # Load path management library
    source "$KITBASH_LIB/paths.sh"
    if ! init_paths; then
        echo "ERROR: Failed to initialize kitbash paths" >&2
        return $KIT_EXIT_ERROR
    fi

    # Verify installation integrity
    if ! verify_installation; then
        echo "ERROR: Kitbash installation verification failed" >&2
        return $KIT_EXIT_ERROR
    fi

    # Load configuration management library
    source "$KITBASH_LIB/config.sh"
    if ! init_config; then
        echo "ERROR: Failed to load configuration" >&2
        return $?  # Propagate specific config error code
    fi

    # Set legacy variables for backwards compatibility (temporary)
    _scripts="$KITBASH_MODULES/"
    _packages="$KITBASH_PACKAGES"
    _desktop=$(echo $XDG_CURRENT_DESKTOP)

    # Load remaining library functions
    source "$KITBASH_LIB/logging.sh"
    source "$KITBASH_LIB/validation.sh"
    source "$KITBASH_LIB/module-runner.sh"
    source "$KITBASH_LIB/setup-functions.sh"

    # Initialize logging
    log_init

    # Validate preferences before any execution
    validate_preferences "$1"

    # Check if first argument matches a module name
    requested_module="$1"

    if [ -n "$requested_module" ] && [ "$requested_module" != "help" ] && [ "$requested_module" != "-h" ] && [ "$requested_module" != "--help" ]; then
        # Check if it's a valid module (script exists)
        script_file="$_scripts${requested_module}.sh"
        if [ -f "$script_file" ]; then
            log_info "Initializing..."
            log_debug "Requested module: $requested_module"
            sudo -n true 2>/dev/null || sudo -v || return 1

            # Use the same logic as module discovery - pass any additional arguments
            process_module "$script_file" "${@:2}"
            return 0
        fi
    fi

    # Handle special cases and fallbacks
    case "$requested_module" in
        "help"|"-h"|"--help")
            show_usage
            return 0
            ;;
        "repos")
            log_info "Initializing..."
            sudo -n true 2>/dev/null || sudo -v || return 1
            setup_repos
            ;;
        "packages")
            log_info "Initializing..."
            sudo -n true 2>/dev/null || sudo -v || return 1
            setup_packages
            ;;
        "")
            # Run full setup with module discovery
            log_info "Initializing..."
            sudo -n true 2>/dev/null || sudo -v || return 1

            # First run core system setup
            setup_repos
            setup_packages

            # Then run discovered modules
            run_discovered_modules
            ;;
        *)
            if [ -n "$requested_module" ]; then
                log_error "Unknown module '$requested_module'"
                echo ""
                echo "Available modules:"
                for script_file in "$_scripts"*.sh; do
                    if [ -f "$script_file" ]; then
                        module_name=$(basename "$script_file" .sh)
                        echo "  - $module_name"
                    fi
                done
                echo ""
                echo "Use '$0 help' for more information."
                return 1
            fi
            ;;
    esac
}

# If this script is executed directly (not sourced), run main_setup
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main_setup "$@"
fi