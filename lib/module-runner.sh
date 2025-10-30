#!/bin/bash
# Module discovery and execution functions for setupv2.sh

# Source logging library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

# Helper function to determine if a preference value should run a module
should_run_module() {
    local pref_value="$1"
    [ "$pref_value" = "true" ] || [ "$pref_value" != "false" -a -n "$pref_value" ]
}

# Helper function to get module execution type and args
get_module_execution_info() {
    local module_name="$1"
    local pref_value="$2"

    # Determine execution type and arguments
    if [ "$pref_value" = "true" ]; then
        echo "boolean_true"
    elif [ "$pref_value" = "false" ]; then
        echo "skip"
    else
        echo "configured"
        echo "$pref_value"
    fi
}

# Helper function to execute a single module
execute_module() {
    local module_name="$1"
    local script_file="$2"
    local execution_type="$3"
    local pref_value="$4"
    
    case "$execution_type" in
        "boolean_true")
            log_debug "Module '$module_name': enabled, running with defaults"
            run_module_with_defaults "$module_name" "$script_file"
            ;;
        "configured")
            log_debug "Module '$module_name': configured with value '$pref_value', running"
            run_module_with_value "$module_name" "$script_file" "$pref_value"
            ;;
        "skip")
            log_debug "Module '$module_name': disabled, skipping"
            ;;
    esac
}

# Helper function to run module with default values
run_module_with_defaults() {
    local module_name="$1"
    local script_file="$2"

    case "$module_name" in
        "hostname") setup_hostname ;;
        "wallpaper") setup_wallpaper ;;
        "cursor") setup_cursor ;;
        "font") setup_font ;;
        *)
            log_info "Running module: $module_name"
            if (source "$script_file"); then
                log_success "Module '$module_name' completed"
            else
                local exit_code=$?
                log_error "Module '$module_name' failed with exit code $exit_code"
                log_warning "Continuing with remaining modules..."
            fi
            ;;
    esac
}

# Helper function to run module with provided value
run_module_with_value() {
    local module_name="$1"
    local script_file="$2"
    local pref_value="$3"

    case "$module_name" in
        "hostname") setup_hostname "$pref_value" ;;
        "wallpaper") setup_wallpaper "$pref_value" ;;
        "cursor") setup_cursor "$pref_value" "$_cursor_size" ;;
        "font") setup_font "$pref_value" ;;
        *)
            log_info "Running module: $module_name (configured: $pref_value)"
            if (source "$script_file" "$pref_value"); then
                log_success "Module '$module_name' completed"
            else
                local exit_code=$?
                log_error "Module '$module_name' failed with exit code $exit_code"
                log_warning "Continuing with remaining modules..."
            fi
            ;;
    esac
}

# Function to process a single discovered module
process_module() {
    local script_file="$1"
    local override_args=("${@:2}")  # All arguments after the first
    local module_name
    local pref_var
    local pref_value
    local execution_info
    
    module_name=$(basename "$script_file" .sh)
    pref_var="_${module_name}"

    log_debug "Checking module '$module_name' (pref: $pref_var)"

    # If override arguments provided, use them instead of preferences
    if [ ${#override_args[@]} -gt 0 ]; then
        log_debug "Module '$module_name': using provided arguments: ${override_args[*]}"
        case "$module_name" in
            "hostname") setup_hostname "${override_args[0]}" ;;
            "wallpaper") setup_wallpaper "${override_args[0]}" ;;
            "cursor") setup_cursor "${override_args[0]}" "${override_args[1]:-$_cursor_size}" ;;
            "font") setup_font "${override_args[0]}" ;;
            *)
                log_info "Running module: $module_name (args: ${override_args[*]})"
                if (source "$script_file" "${override_args[@]}"); then
                    log_success "Module '$module_name' completed"
                    return 0
                else
                    local exit_code=$?
                    log_error "Module '$module_name' failed with exit code $exit_code"
                    return $exit_code
                fi
                ;;
        esac
        return 0
    fi
    
    # Check if preference variable exists
    if ! declare -p "$pref_var" >/dev/null 2>&1; then
        log_debug "Module '$module_name': no preference variable '$pref_var' found, skipping"
        return 0
    fi
    
    # Get preference value and execution info
    pref_value="${!pref_var}"
    mapfile -t execution_info < <(get_module_execution_info "$module_name" "$pref_value")

    # Execute the module
    execute_module "$module_name" "$script_file" "${execution_info[@]}"
}

# Function to discover and run available modules
run_discovered_modules() {
    validate_required_prefs

    log_info "Discovering available modules in $_scripts"
    log_debug "Scripts directory: $_scripts"

    # Find all .sh files in the scripts directory (excluding _lib)
    for script_file in "$_scripts"*.sh; do
        [ -f "$script_file" ] && process_module "$script_file"
    done

    log_success "All modules completed"
}