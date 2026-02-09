#!/usr/bin/env bash
#
# Prerequisites: Install binaries and configure Talos (Steps 1-4)
#
# Step 1: Add route to cluster subnet
# Step 2: Setup environment variables
# Step 3: Provision prerequisites
# Step 4: Setup talosctl configuration
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
: "${CLOUD_PROVIDER_REGION:?CLOUD_PROVIDER_REGION not set}"
: "${TALOS_DIR:?TALOS_DIR not set}"
: "${KUBE_DIR:?KUBE_DIR not set}"
: "${GIT_REPO:?GIT_REPO not set}"
: "${FLUXCD_SSHKEY_PATH:?FLUXCD_SSHKEY_PATH not set}"
: "${CLOUD_PROVIDER_PAT:?CLOUD_PROVIDER_PAT not set}"
: "${VERSION_TALOSCTL:?VERSION_TALOSCTL not set}"
: "${VERSION_KUBECTL:?VERSION_KUBECTL not set}"
: "${VERSION_GATEWAY_API:?VERSION_GATEWAY_API not set}"
: "${VERSION_CRT_MNG_PLUGIN:?VERSION_CRT_MNG_PLUGIN not set}"
: "${VERSION_KUBESEAL:?VERSION_KUBESEAL not set}"
: "${TALOSCTL_URL:?TALOSCTL_URL not set}"
: "${KUBECTL_URL:?KUBECTL_URL not set}"
: "${FLUXCD_URL:?FLUXCD_URL not set}"
: "${HELM_URL:?HELM_URL not set}"
: "${KUBESEAL_URL:?KUBESEAL_URL not set}"
: "${KUBESEAL_CONTOLLER_URL:?KUBESEAL_CONTOLLER_URL not set}"
: "${K8S_GATEWAY_API:?K8S_GATEWAY_API not set}"
: "${CERT_MNG_PLUGIN:?CERT_MNG_PLUGIN not set}"
: "${NGINX_DIR:?NGINX_DIR not set}"
: "${NGINX_CONF:?NGINX_CONF not set}"
: "${NGINX_TUNING_CONF:?NGINX_TUNING_CONF not set}"
: "${CLUSTER_NAME:?CLUSTER_NAME not set}"
: "${CLUSTER_SUBNET:?CLUSTER_SUBNET not set}"
: "${CLUSTER_ENDPOINT:?CLUSTER_ENDPOINT not set}"

# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "${SCRIPT_DIR}/shared/logger.sh"
source "${SCRIPT_DIR}/shared/utils.sh"

# ===============================================================================
# Step 1: Add route to cluster subnet
# ===============================================================================
add_route_to_cluster() {
    log_info "Validating IP route from bastion/gateway to cluster subnet: ${CLUSTER_SUBNET}"
    ip route add ${CLUSTER_SUBNET} dev eth1 2>/dev/null || echo ' --- Route may already exist --- '
    ip route show
}

# ===============================================================================
# Step 2: Setup environment variables
# ===============================================================================
setup_env_vars() {
    log_info "Creating config files for talosctl and kubectl for cluster access"
    create_file "${TALOS_DIR}/config"
    create_file "${KUBE_DIR}/config"

    # Export config files for default access via cli (idempotent)
    if ! grep -qxF "export TALOSCONFIG=${TALOS_DIR}/config" /root/.bashrc 2>/dev/null; then
        echo "export TALOSCONFIG=${TALOS_DIR}/config" >> /root/.bashrc
    fi
    if ! grep -qxF "export KUBECONFIG=${KUBE_DIR}/config" /root/.bashrc 2>/dev/null; then
        echo "export KUBECONFIG=${KUBE_DIR}/config" >> /root/.bashrc
    fi

    source /root/.bashrc
}

# ===============================================================================
# Step 3: Provision prerequisites
# ===============================================================================
provision_prerequisites() {
    local talos_url="${1:-${TALOSCTL_URL}}"
    local kube_url="${2:-${KUBECTL_URL}}"
    local flux_url="${3:-${FLUXCD_URL}}"
    local helm_url="${4:-${HELM_URL}}"
    local kubeseal_url="${5:-${KUBESEAL_URL}}"
    local kubeseal_tarball="${6:-kubeseal-${VERSION_KUBESEAL#v}-linux-amd64.tar.gz}"

    log_info "Provisioning prerequisites"
    cd $(mktemp -d)

    # Install talosctl
    install_bin "talosctl-linux-amd64" "sha256sum.txt" "$talos_url"

    # Install kubectl
    install_bin "kubectl" "kubectl.sha256" "$kube_url"

    # Install Helm
    install_tool "helm" "$helm_url"

    # Install FluCD
    install_tool "flux" "$flux_url"

    # Custom installation for kubeseal (with tar)
    curl -L "$kubeseal_url" -o "$kubeseal_tarball"
    tar -xvzf "$kubeseal_tarball" kubeseal
    install -m 0750 kubeseal /usr/local/bin/kubeseal

    log_success "Provisioned prerequisites successfully"
}

# ===============================================================================
# Step 4: Setup talosctl configuration
# ===============================================================================
setup_talosctl() {
    log_info "Copying /tmp/talosconfig to ${TALOS_DIR}/config"
    if cp /tmp/talosconfig "${TALOS_DIR}/config" 2>/dev/null; then
        log_debug "Copied /tmp/talosconfig successfully"
    else
        log_debug "File /tmp/talosconfig does not exist"
    fi

    log_info "Setting up talos nodes with cluster endpoint: ${CLUSTER_ENDPOINT}"
    if ! talosctl config nodes ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config 2>&1; then
        log_error "Failed to set talos nodes"
        exit 1
    fi

    if ! talosctl config endpoint ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config 2>&1; then
        log_error "Failed to set talos endpoint"
        exit 1
    fi
    log_info "Talos nodes and endpoint configured"
}

# ===============================================================================
# Main function
# ===============================================================================
main() {
    # Setup error handling
    trap cleanup_on_error EXIT ERR INT TERM

    # Display banner
    log_section "Prerequisites: Install binaries and configure Talos"
    log_info "Release version   : ${RELEASE_VERSION}"
    log_info "Binary version    : ${VERSION}"
    log_info "Cluster endpoint  : ${CLUSTER_ENDPOINT}"
    log_info "Cluster subnet    : ${CLUSTER_SUBNET}"
    echo ""

    # Step 1: Verify and/or add route to cluster subnet
    log_section "Step 1/4: Add IP route to cluster subnet"
    add_route_to_cluster
    log_success "Step 1 completed: Route verified"
    echo ""

    # Step 2: Create config files and environment variables
    log_section "Step 2/4: Setup environment variables"
    setup_env_vars
    log_success "Step 2 completed: Environment variables configured"
    echo ""

    # Step 3: Install binaries and tools
    log_section "Step 3/4: Provision prerequisites"
    provision_prerequisites
    log_success "Step 3 completed: Prerequisites installed"
    echo ""

    # Step 4: Setup talosctl configuration
    log_section "Step 4/4: Setup talosctl configuration"
    setup_talosctl
    log_success "Step 4 completed: Talosctl configured"
    echo ""

    # Success
    log_success "Prerequisites setup completed successfully"
    log_info "Ready to proceed with: make bootstrap"

    # Cleanup
    rm -rf kubectl.sha256
    rm -rf sha256sum.txt
}

# ===============================================================================
# Execute main function
# ===============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
# ===============================================================================
