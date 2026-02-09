#!/usr/bin/env bash
#
# Bootstrap: Initialize cluster and kubeconfig (Steps 5-6)
#
# Step 5: Bootstrap cluster (talos) nodes
# Step 6: Setup kubeconfig for cluster access
#
set -euo pipefail

# Get the directory where this script is located
declare -r SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r INITD="${SCRIPT_DIR}"

# Configuration variables are expected to be set by init.sh
# Verify they are properly exported
: "${RELEASE_VERSION:?RELEASE_VERSION not set}"
: "${VERSION:?VERSION not set}"
: "${LOG_LEVEL:?LOG_LEVEL not set}"
: "${TALOS_DIR:?TALOS_DIR not set}"
: "${KUBE_DIR:?KUBE_DIR not set}"
: "${CLUSTER_ENDPOINT:?CLUSTER_ENDPOINT not set}"
: "${CLUSTER_NAME:?CLUSTER_NAME not set}"

# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "${SCRIPT_DIR}/shared/logger.sh"
source "${SCRIPT_DIR}/shared/utils.sh"

# ===============================================================================
# Step 5: Bootstrap cluster nodes via bastion host using talosctl
# ===============================================================================
bootstrap_cluster() {
    log_info "Initializing bootstrap process for talos nodes"
    if timeout 5 talosctl --nodes ${CLUSTER_ENDPOINT} --endpoints ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config etcd members >/dev/null 2>&1; then
        log_warn "Cluster already bootstrap at endpoint: ${CLUSTER_ENDPOINT}"
    else
        if timeout 5 talosctl bootstrap --nodes ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config; then
            log_success "Cluster at endpoint: ${CLUSTER_ENDPOINT} bootstrapped successfully"
            log_debug "Sleeping for 10s waiting for cluster to bootup"
            sleep 10 # needed due to slow bootup speeds of ec2 instances
        else
            log_error "Failed to bootstrap cluster at endpoint: ${CLUSTER_ENDPOINT}"
            exit 1
        fi
    fi
}

# ===============================================================================
# Step 6: Update kubeconfig for cluster access
# ===============================================================================
setup_kubectl() {
    log_info "Generating kubeconfig for cluster node access"
    talosctl kubeconfig --nodes ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config --merge --force
}

# ===============================================================================
# Main function
# ===============================================================================
main() {
    # Setup error handling
    trap cleanup_on_error EXIT ERR INT TERM

    # Display banner
    log_section "Bootstrap: Initialize cluster and kubeconfig"
    log_info "Release version   : ${RELEASE_VERSION}"
    log_info "Binary version    : ${VERSION}"
    log_info "Cluster endpoint  : ${CLUSTER_ENDPOINT}"
    log_info "Cluster name      : ${CLUSTER_NAME}"
    echo ""

    # Verify talosctl is available
    if ! command -v talosctl &>/dev/null; then
        log_error "talosctl not found. Please run 'make prereq' first"
        exit 1
    fi

    # Verify talosconfig exists
    if [[ ! -f "${TALOS_DIR}/config" ]]; then
        log_error "Talosconfig not found at ${TALOS_DIR}/config. Please run 'make prereq' first"
        exit 1
    fi

    # Step 5: Bootstrap cluster nodes
    log_section "Step 1/2: Bootstrap cluster (talos) nodes"
    bootstrap_cluster
    log_success "Step 1 completed: Cluster bootstrapped"
    echo ""

    # Step 6: Setup kubeconfig
    log_section "Step 2/2: Setup kubeconfig for cluster access"
    setup_kubectl
    log_success "Step 2 completed: Kubeconfig generated"
    echo ""

    # Success
    log_success "Bootstrap setup completed successfully"
    log_info "Ready to proceed with: make day0"
    log_section "Cluster Status"
    log_info "Cluster health: endpoint: ${CLUSTER_ENDPOINT}"
    talosctl health --nodes ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config
}

# ===============================================================================
# Execute main function
# ===============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
# ===============================================================================
