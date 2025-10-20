#!/bin/bash

log_info "Setting up Google Chrome repository"

run_with_progress "installing DNF plugins" sudo dnf install -y dnf-plugins-core

run_with_progress "adding Google Chrome repository" sudo dnf config-manager addrepo --id=google-chrome --set=baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64 --set=name=google-chrome --set=enabled=1 --set=gpgcheck=1 --set=gpgkey=https://dl.google.com/linux/linux_signing_key.pub

log_success "Google Chrome repository configured"
