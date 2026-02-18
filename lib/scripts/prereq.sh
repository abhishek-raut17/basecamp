#!/usr/bin/env bash
#
# Usage: 
#   prereq - Generates required prerequesities for cluster and DMZ management
#
# ------------------------------------------------------------------------------

set -euo pipefail
# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "$(dirname "$0")/shared/logger.sh"
source "$(dirname "$0")/shared/utils.sh"

trap 'log_fatal "prereq target failed at line $LINENO"' ERR

PROJECT_NAME="${PROJECT_NAME:-basecamp}"
VERSION_TALOSCTL=${VERSION_TALOSCTL:-v1.11.2}
VERSION_TERRAFORM=${VERSION_TERRAFORM:-v1.14.5}
VERSION_SOPS=${VERSION_SOPS:-v3.11.0}
VERSION_AGE=${VERSION_AGE:-v1.3.1}
TALOSCTL_URL="${TALOSCTL_URL:-https://github.com/siderolabs/talos/releases/download/${VERSION_TALOSCTL}/talosctl-linux-amd64}"
TERRAFORM_URL="${TERRAFORM_URL:-https://releases.hashicorp.com/terraform/${VERSION_TERRAFORM##v}/terraform_${VERSION_TERRAFORM##v}_linux_amd64.zip}"
SOPS_URL="${SOPS_URL:-https://github.com/getsops/sops/releases/download/${VERSION_SOPS}/sops-${VERSION_SOPS}.linux.amd64}"
AGE_URL="${AGE_URL:-https://github.com/FiloSottile/age/releases/download/${VERSION_AGE}/age-${VERSION_AGE}-linux-amd64.tar.gz}"
INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-$HOME/.local/bin}"
DATA_DIR="${DATA_DIR:-$HOME/.local/share/$PROJECT_NAME}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/$PROJECT_NAME}"

prereq() {
    log_mark "Generating required prerequesities for cluster and DMZ management"

    # Install required tools
    install_bin "terraform" "${TERRAFORM_URL}" "zip" || return 1
    install_bin "talosctl" "${TALOSCTL_URL}" || return 1
    install_bin "sops" "${SOPS_URL}" || return 1
    install_bin "age" "${AGE_URL}" "tar" || return 1

    # Install required directories
    install_dir "${DATA_DIR}/state/terraform" || return 1
    install_dir "${DATA_DIR}/var/terraform" || return 1
    install_dir "${CONFIG_DIR}/secrets/talos" || return 1
    install_dir "${CONFIG_DIR}/secrets/age" || return 1

    log_success "All required prerequesities for cluster and DMZ management completed sucessfully"
}

prereq
# ------------------------------------------------------------------------------
