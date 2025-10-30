#!/bin/bash

log_info "Installing Alacritty terminal emulator"

# Check if Alacritty is already installed
if command -v alacritty >/dev/null 2>&1; then
    log_success "Alacritty is already installed"
    exit 0
fi

# Install Alacritty from Fedora repositories
if ! run_with_progress "installing Alacritty" sudo dnf install -y alacritty; then
    log_error "Failed to install Alacritty"
    exit 1
fi

log_success "Alacritty installed successfully"
