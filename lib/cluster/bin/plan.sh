#!/usr/bin/env bash
#
# Cluster lib: plan file for plan terraform backed infrastructure
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
# Generate .tfvars when generating plan from environment variables
# ------------------------------------------------------------------------------
generate_tfvars() {
    local template="${INFRA_DIR:-}/terraform.tfvars.template"
    local genfile="${INFRA_DIR:-}/terraform.tfvars"

    log_info "Generating .tfvars for terraform tasks using template: $template at $genfile"

    if ! exists "file" "$template"; then
        log_error "No terraform.tfvars.template found at $template"
        return 1
    fi

    envsubst < "$template" > "$genfile" || {
        log_warn "Error generating .tfvars from $template."
        return 1
    }

    log_success "Successfully generated .tfvars at: $genfile"
    return 0
}

# ------------------------------------------------------------------------------
# Main function
# ------------------------------------------------------------------------------
main() {

    # Setup error handling
    trap cleanup_on_error EXIT ERR INT TERM

    # Display banner
    log_section "Plannig infrastructure resources using terraform"
    log_info "Release version   : ${RELEASE_VERSION}"
    log_info "Binary version    : ${VERSION}"
    echo ""

    if ! command -v terraform >/dev/null 2>&1; then
        log_warn "Required bin 'terraform' not found in $PATH"
        # TODO: Install terraform if not found
        return 1
    fi

    # CHDIR to infrastructure
    cd $INFRA_DIR

    # Setup .tfvars for terraform tasks
    generate_tfvars

    # Init terraform providers
    terraform init -upgrade

    # Format source code
    terraform fmt -recursive

    # Validate source code for IaC
    terraform validate

    # Plan terraform infrastructure resources
    terraform plan -out=$PLAN

    # Success
    log_success "Infrastructure plan process completed successfully"
    log_section "All plan tasks completed"
}

# ------------------------------------------------------------------------------
# Execute main function
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# ------------------------------------------------------------------------------
