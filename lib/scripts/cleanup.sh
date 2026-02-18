#!/usr/bin/env bash
#
# Usage: 
#   cleanup - Cleanup resources created during make run
#           - $TERRAFORM_STATE_DIR
#           - $TERRAFORM_VAR_DIR
#           - $TALOS_SECRETS_DIR
#           - $TALOS_DATA_DIR
#
# ------------------------------------------------------------------------------

set -euo pipefail
# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "$(dirname "$0")/shared/logger.sh"
source "$(dirname "$0")/shared/utils.sh"

trap 'log_fatal "cleanup target failed at line $LINENO"' ERR

PROJECT_NAME="${PROJECT_NAME:-basecamp}"
DATA_DIR="${DATA_DIR:-$HOME/.local/share/$PROJECT_NAME}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/$PROJECT_NAME}"
SECRETS_DIR="${SECRETS_DIR:-${CONFIG_DIR}/secrets}"
TERRAFORM_VAR_DIR="${TERRAFORM_VAR_DIR:-${DATA_DIR}/var/terraform}"
TERRAFORM_STATE_DIR="${TERRAFORM_STATE_DIR:-${DATA_DIR}/state/terraform}"
TALOS_DATA_DIR="${TALOS_DATA_DIR:-${DATA_DIR}/talos}"
TALOS_SECRETS_DIR="${TALOS_SECRETS_DIR:-${SECRETS_DIR}/talos}"

cleanup() {
    log_mark "Cleaning up resources created during make run"

    # Delete content from $TERRAFORM_STATE_DIR
    rm -rf ${TERRAFORM_STATE_DIR}/*

    # Delete content from $TERRAFORM_VAR_DIR
    rm -rf ${TERRAFORM_VAR_DIR}/*

    # Delete content from $TALOS_DATA_DIR
    rm -rf ${TALOS_DATA_DIR}/*

    # Delete content from $TALOS_SECRETS_DIR
    rm -rf ${TALOS_SECRETS_DIR}/*

    log_success "Cleaned up resources from last make run. Proceed for a fresh run."
}

cleanup
# ------------------------------------------------------------------------------
