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
# Install prereq on localhost to generate cluster privisioning resources
# ------------------------------------------------------------------------------
provision_prerequisites() {
    local talos_url="${1:-${TALOSCTL_URL}}"
    local kube_url="${2:-${KUBECTL_URL}}"
    local helm_url="${3:-${HELM_URL}}"

    log_info "Provisioning prerequsities"

    # Install talosctl
    install_bin "talosctl-linux-amd64" "sha256sum.txt" "$talos_url"

    # Install kubectl
    install_bin "kubectl" "kubectl.sha256" "$kube_url"

    # Install Helm
    install_tool "helm" "$helm_url"

    log_success "Provisioned prerequsities successfully"
    return 0
}

# ------------------------------------------------------------------------------
# Main function
# ------------------------------------------------------------------------------
main() {

    # Setup error handling
    trap cleanup_on_error EXIT ERR INT TERM

    # Display banner
    log_section "Provisioning localhost for project management"
    log_info "Release version   : ${RELEASE_VERSION}"
    log_info "Binary version    : ${VERSION}"
    echo ""

    # Check if required variables are avaiable
    validate_required_args PROJECT_NAME BIN_DIR \
        TALOSCTL_URL TALOSCONFIG \
        KUBECTL_URL KUBECONFIG \
        HELM_URL \
        CLUSTER_ENDPOINT
    
    # Create required directories

    # Install CLI tools (talosctl, kubectl, helm)
    provision_prerequisites

    # Generate SSH keys

    # Organize if needed

    # Success
    log_success "Localhost is ready to manage: '${PROJECT_NAME}' project"
    log_section "All Prerequsite tasks completed"
}

# ------------------------------------------------------------------------------
# Execute main function
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# ------------------------------------------------------------------------------
