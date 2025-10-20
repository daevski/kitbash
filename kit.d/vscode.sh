#!/bin/bash

log_info "Setting up Visual Studio Code repository"

run_with_progress "importing Microsoft GPG key" sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

log_step "adding Visual Studio Code repository"
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

run_with_progress "checking for updates" dnf check-update > /dev/null

log_success "Visual Studio Code repository configured"
