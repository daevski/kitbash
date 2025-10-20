#!/bin/bash

# Dotfiles Module - Manage $HOME as git repo for dotfiles

DOTFILES_REPO="${_dotfiles_repo:-https://github.com/daevski/dotfiles.git}"
DOTFILES_BRANCH="${_dotfiles_branch:-main}"

log_info "Dotfiles module starting"

# Change to home directory
cd "$HOME"

# Initialize git if needed
if [ ! -d "$HOME/.git" ]; then
    log_step "Initializing $HOME as git repository"
    git init
    git branch -m "$DOTFILES_BRANCH"
fi

# Check for remote
REMOTE_EXISTS=$(git remote -v | grep origin | wc -l)
if [ "$REMOTE_EXISTS" -eq 0 ]; then
    log_step "Adding remote origin"
    git remote add origin "$DOTFILES_REPO"
fi

# Fetch latest from remote
run_with_progress "fetching from origin" git fetch origin

# Confirm before overwriting local changes
if ! git diff --quiet HEAD "origin/$DOTFILES_BRANCH"; then
    prompt_yes_no "Overwrite local changes in $HOME with remote dotfiles?" "n"
    if [ "$PROMPT_RESULT" != "y" ] && [ "$PROMPT_RESULT" != "Y" ]; then
        log_info "Aborting dotfiles update. Local changes preserved."
        return 0
    fi
fi

# Overwrite with remote
run_with_progress "resetting to origin/$DOTFILES_BRANCH" git reset --hard "origin/$DOTFILES_BRANCH"
log_debug "dotfiles deployed successfully"

log_success "Dotfiles module complete"
