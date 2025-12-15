#!/usr/bin/env bash
#
# Local lib: prereq file for provisioning and preparing local machine to setup
#            and manage project/cluster
#
set -euo pipefail

# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "${SHARED_LIB}/bin/logger.sh"
source "${SHARED_LIB}/bin/utils.sh"

# ------------------------------------------------------------------------------
# Default configuration
# ------------------------------------------------------------------------------
declare -r VERSION="v1.0.0"

# ------------------------------------------------------------------------------
# Cleanup function
# ------------------------------------------------------------------------------
cleanup() {

    # Setup error handling
    trap cleanup_on_error EXIT ERR INT TERM

    # Display banner
    log_section "Initializing safe cleanup process"
    log_info "Release version   : ${RELEASE_VERSION}"
    log_info "Binary version    : ${VERSION}"
    echo ""

    # Delete sha256sum files
    delete_file "${ROOT_DIR}/kubectl.sha256"
    delete_file "${ROOT_DIR}/sha256sum.txt"
    # delete_file "${INFRA_DIR}/terraform.tfvars"

    # Completed
    log_section "All cleanup tasks completed"
}

# ------------------------------------------------------------------------------
# Execute cleanup function
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cleanup "$@"
fi

# ------------------------------------------------------------------------------
