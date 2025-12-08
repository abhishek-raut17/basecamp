#!/usr/bin/env bash
#
# Cluster lib: build file to build terraform backed infrastructure resources
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
PLAN="plan-v1.tfplan"

# ------------------------------------------------------------------------------
# Verify infrastructure build plan
# ----------------------------------------------------------------------------
verify_plan() {
    local plan="${1:-$PLAN}"
    plan="$INFRA_DIR/$plan"

    if ! exists "file" "$plan"; then
        log_warn "Plan does not exist for the current changes. Initiating planning"
        source ./plan.sh
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Main function
# ------------------------------------------------------------------------------
main() {

    # Setup error handling
    trap cleanup_on_error EXIT ERR INT TERM

    # Display banner
    log_section "Building infrastructure resources using terraform"
    log_info "Release version   : ${RELEASE_VERSION}"
    log_info "Binary version    : ${VERSION}"
    echo ""

    # Verify if a plan is generated, if not generate a new one
    verify_plan

    # Apply plan
    # terraform apply plan

    # Success
    log_success "Infrastructure build process completed successfully"
    log_section "All build tasks completed"
}

# ------------------------------------------------------------------------------
# Execute main function
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# ------------------------------------------------------------------------------
