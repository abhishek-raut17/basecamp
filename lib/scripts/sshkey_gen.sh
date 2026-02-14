#!/usr/bin/env bash
#
# Usage: 
#   sshkey_gen - Generates required keys in SSH_DIR
#
# ------------------------------------------------------------------------------

set -euo pipefail
# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "$(dirname "$0")/shared/logger.sh"
source "$(dirname "$0")/shared/utils.sh"

trap 'log_fatal "sshkey_gen target failed at line $LINENO"' ERR

PROJECT_NAME="${PROJECT_NAME:-basecamp}"
KEY_USAGE="${KEY_USAGE:-access=dmz[root]}"
ACCESS_SSHKEY_PATH="${ACCESS_SSHKEY_PATH:-$HOME/.ssh/${PROJECT_NAME}}"

SSH_DIR="$(dirname "$ACCESS_SSHKEY_PATH")"
SSH_KEY_COMMENT="sigdep: ${PROJECT_NAME}: ${KEY_USAGE}"

sshkey_generator() {
    log_mark "Validating required sshkey to access and manage DMZ node"

    if [[ ! -f "$ACCESS_SSHKEY_PATH" ]]; then
        log_warn "No sshkey found at ${SSH_DIR}"
        log_debug "Creating ed25519 key at: ${ACCESS_SSHKEY_PATH} with usage: {${SSH_KEY_COMMENT}}"
        ssh-keygen -t ed25519 -N "" -f "${ACCESS_SSHKEY_PATH}" -C "sigdep: ${PROJECT_NAME}: ${KEY_USAGE}"  
    
    else
        log_success "SSH key found at: ${ACCESS_SSHKEY_PATH} for usage: ${KEY_USAGE}"
        return 0
    fi

    log_success "Proceeding to use key for ${KEY_USAGE}"
}

sshkey_generator
# ------------------------------------------------------------------------------
