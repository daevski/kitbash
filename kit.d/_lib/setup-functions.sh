#!/bin/bash
# Individual setup functions for setupv2.sh

# Source logging library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

# Functions for individual steps
setup_hostname() {
    local hostname="${1:-$_hostname}"
    log_info "Running module: hostname (value: $hostname)"
    source ${_scripts}hostname.sh "$hostname"
    log_success "Module 'hostname' completed"
}

setup_repos() {
    echo "> setting up 3rd-party repositories ..."
    if [ "$_google_chrome" = true ]; then
        echo -n "  > google chrome repo ... "
        source ${_scripts}google_chrome.sh
        echo "done"
    fi
    if [ "$_vscode" = true ]; then
        echo -n "  > vscode repo ... "
        source ${_scripts}vscode.sh
        echo "done"
    fi
}

setup_packages() {
    echo "> installing packages from $_packages ..."
    xargs -n 1 sudo dnf install -y < "$_packages"
}

setup_dotfiles() {
    echo -n "> setting up dotfiles ... "
    source ${_scripts}dotfiles.sh
}

setup_wallpaper() {
    local wallpaper_path="${1:-$_wallpaper}"
    if [ -n "$wallpaper_path" ]; then
        log_info "Running module: wallpaper (value: $wallpaper_path)"
        wallpaper_expanded=$(eval echo "$wallpaper_path")
        source ${_scripts}wallpaper.sh "$wallpaper_expanded"
        log_success "Module 'wallpaper' completed"
    else
        log_debug "Module 'wallpaper': no wallpaper specified, skipping"
    fi
}

setup_font() {
    local font_name="${1:-$_font}"
    if [ -n "$font_name" ]; then
        log_info "Running module: font (value: $font_name)"
        source ${_scripts}font.sh "$font_name"
        log_success "Module 'font' completed"
    else
        log_debug "Module 'font': no font specified, skipping"
    fi
}

setup_ollama() {
    echo "> setting up Ollama AI runtime ... "
    source ${_scripts}ollama.sh
}

setup_cursor() {
    local cursor_theme="${1:-$_cursor}"
    local cursor_size="${2:-$_cursor_size}"
    log_info "Running module: cursor (theme: $cursor_theme, size: $cursor_size)"
    source ${_scripts}cursor.sh "$cursor_theme" "$cursor_size"
    log_success "Module 'cursor' completed"
}

show_usage() {
    echo "Usage: $0 [STEP] [OPTIONS]"
    echo ""
    echo "Run the full setup or individual steps:"
    echo "  $0                         Run all enabled modules (discovered automatically)"
    echo "  $0 hostname [NAME]         Set hostname (default: $_hostname)"
    echo "  $0 repos                   Set up 3rd-party repositories"
    echo "  $0 packages                Install packages from packages.txt"
    echo "  $0 dotfiles                Set up dotfiles"
    echo "  $0 wallpaper [PATH]        Set up wallpaper (default: $_wallpaper)"
    echo "  $0 ollama                  Install and configure Ollama AI runtime"
    echo "  $0 cursor [THEME] [SIZE]   Set up cursor theme (default: $_cursor, size $_cursor_size)"
    echo "  $0 help                    Show this help message"
    echo ""
    echo "Configuration:"
    echo "  _wallpaper_targets         Array of wallpaper locations to update"
    echo "                             Valid values: desktop, lock, login"
    echo "                             Current: (${_wallpaper_targets[*]})"
    echo ""
    echo "Available modules (auto-discovered from $_scripts):"
    for script_file in "$_scripts"*.sh; do
        if [ -f "$script_file" ]; then
            module_name=$(basename "$script_file" .sh)
            pref_var="_${module_name}"
            if declare -p "$pref_var" >/dev/null 2>&1; then
                pref_value="${!pref_var}"
                echo "  - $module_name (preference: $pref_var = $pref_value)"
            else
                echo "  - $module_name (no preference variable, therefore will be skipped)"
            fi
        fi
    done
    echo ""
    echo "Examples:"
    echo "  $0 wallpaper ~/Pictures/my-wallpaper.jpg"
    echo "  $0 hostname mycomputer"
    echo "  $0 cursor breeze_cursors 32"
}