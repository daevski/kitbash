#!/bin/bash
# Exit code constants for Kitbash
# These codes provide consistent error reporting across all modules

# Define all exit codes using declare -gxr (global, export, readonly)
# Prefixed with KIT_ to avoid namespace conflicts with other scripts
declare -gxr KIT_EXIT_SUCCESS=0                # Operation completed successfully
declare -gxr KIT_EXIT_ERROR=1                  # General/unspecified error
declare -gxr KIT_EXIT_CONFIG_MISSING=2         # Configuration file not found
declare -gxr KIT_EXIT_CONFIG_INVALID=3         # Configuration file is invalid or malformed
declare -gxr KIT_EXIT_DEPENDENCY_MISSING=3     # Required dependency not installed
declare -gxr KIT_EXIT_PERMISSION_DENIED=4      # Insufficient permissions
declare -gxr KIT_EXIT_MODULE_FAILED=5          # Module execution failed
declare -gxr KIT_EXIT_MODULE_SKIPPED=6         # Module intentionally skipped
declare -gxr KIT_EXIT_NETWORK_ERROR=7          # Network/download error
declare -gxr KIT_EXIT_USER_CANCELLED=8         # User cancelled operation
declare -gxr KIT_EXIT_INVALID_INPUT=9          # Invalid user input

# Helper function to exit with code and message
# Usage: exit_with EXIT_CONFIG_MISSING "Config file not found"
exit_with() {
    local exit_code=$1
    local message="${2:-}"

    if [ -n "$message" ]; then
        echo "ERROR: $message" >&2
    fi

    exit "$exit_code"
}

# Helper function to return with code and message (doesn't exit, for functions)
# Usage: return_with EXIT_MODULE_FAILED "Module failed to execute"
return_with() {
    local return_code=$1
    local message="${2:-}"

    if [ -n "$message" ]; then
        echo "ERROR: $message" >&2
    fi

    return "$return_code"
}
