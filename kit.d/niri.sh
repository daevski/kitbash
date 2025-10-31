#!/bin/bash

# Module: niri.sh
# Purpose: Install Niri scrollable-tiling Wayland compositor
# Niri is a modern Wayland compositor with a unique scrollable tiling layout

log_info "Setting up Niri window manager"

# Idempotency: Check if already installed
if command -v niri >/dev/null 2>&1; then
    NIRI_VERSION=$(niri --version 2>&1 | head -n1 || echo "unknown")
    log_success "Niri is already installed: $NIRI_VERSION"
    exit 0
fi

# Check if running on Wayland-compatible system
log_step "checking system compatibility"
if ! rpm -q libwayland-client >/dev/null 2>&1; then
    log_warning "Wayland libraries not detected, installing base dependencies"
    if ! run_with_progress "installing Wayland dependencies" \
        sudo dnf install -y wayland-devel libwayland-client libwayland-server; then
        log_error "Failed to install Wayland dependencies"
        exit $KIT_EXIT_DEPENDENCY_MISSING
    fi
else
    log_debug "Wayland libraries detected"
fi

# Enable COPR repository for Niri
log_step "enabling COPR repository for Niri"
if ! dnf copr list 2>/dev/null | grep -q "yalter/niri"; then
    if ! run_with_progress "adding yalter/niri COPR repository" \
        sudo dnf copr enable -y yalter/niri; then
        log_error "Failed to enable COPR repository for Niri"
        log_error "You may need to enable COPR manually: sudo dnf copr enable yalter/niri"
        exit $KIT_EXIT_NETWORK_ERROR
    fi
else
    log_debug "COPR repository already enabled"
fi

# Install Niri
log_step "installing Niri from COPR"
if ! run_with_progress "installing niri package" \
    sudo dnf install -y niri; then
    log_error "Failed to install Niri"
    log_error "Check ~/kit.log for details"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if command -v niri >/dev/null 2>&1; then
    NIRI_VERSION=$(niri --version 2>&1 | head -n1 || echo "installed")
    log_debug "Niri installed successfully: $NIRI_VERSION"
    log_success "Niri installation completed successfully"
else
    log_error "Niri installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi

exit 0
