#!/bin/bash

# Exit on any error
set -e

# Get terminal preference from config or use first parameter
TERMINAL_APP="${1:-$_terminal}"

if [ -z "$TERMINAL_APP" ]; then
    log_error "No terminal application specified"
    exit 1
fi

log_step "configuring $TERMINAL_APP as default terminal"
log_debug "Terminal application: $TERMINAL_APP"

# Check if the terminal application is installed
if ! command -v "$TERMINAL_APP" >/dev/null 2>&1; then
    log_error "$TERMINAL_APP not found, please install it first"
    exit 1
fi

# Set terminal as default system-wide
if sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "/usr/bin/$TERMINAL_APP" 50 2>/dev/null; then
    sudo update-alternatives --set x-terminal-emulator "/usr/bin/$TERMINAL_APP"
    log_debug "Set system-wide terminal alternative"
else
    log_debug "Failed to set terminal alternative (update-alternatives not available)"
fi

# Configure XFCE4 helpers if the config exists
XFCE_HELPERS="$HOME/.config/xfce4/helpers.rc"
if [ -f "$XFCE_HELPERS" ]; then
    log_step "configuring XFCE4 terminal helper"
    if grep -q "^TerminalEmulator=" "$XFCE_HELPERS"; then
        sed -i "s|^TerminalEmulator=.*|TerminalEmulator=/usr/bin/$TERMINAL_APP|" "$XFCE_HELPERS"
    else
        echo "TerminalEmulator=/usr/bin/$TERMINAL_APP" >> "$XFCE_HELPERS"
    fi
    log_debug "XFCE4 terminal helper configured"
fi