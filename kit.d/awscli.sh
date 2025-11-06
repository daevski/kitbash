#!/bin/bash

# Module: awscli.sh
# Purpose: Install AWS Command Line Interface (awscli)
# AWS CLI is the official command line tool for managing AWS services

log_info "Setting up AWS CLI"

# Check if awscli is already installed
if command -v aws >/dev/null 2>&1; then
    AWS_VERSION=$(aws --version 2>&1 | head -n1 || echo "unknown")
    log_debug "AWS CLI is already installed: $AWS_VERSION"
    log_success "AWS CLI is already installed"
    exit 0
fi

# Install AWS CLI from Fedora repositories
log_step "installing AWS CLI"
if ! run_with_progress "installing awscli package" \
    sudo dnf install -y awscli; then
    log_error "Failed to install AWS CLI"
    log_error "Check ~/kit.log for details"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Verify installation
if command -v aws >/dev/null 2>&1; then
    AWS_VERSION=$(aws --version 2>&1 | head -n1 || echo "installed")
    log_debug "AWS CLI installed successfully: $AWS_VERSION"
else
    log_error "AWS CLI installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi

log_success "AWS CLI installation completed successfully"
log_info "Note: Configure AWS credentials with 'aws configure' or via environment variables"
log_info "Note: Credentials stored in ~/.aws/credentials, config in ~/.aws/config"
exit 0
