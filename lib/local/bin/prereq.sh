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

VERSION_TALOSCTL=${VERSION_TALOSCTL:-v1.11.2}
VERSION_KUBECTL=${VERSION_KUBECTL:-v1.34.1}
V_HELM=${V_HELM:-}

TALOSCTL_URL="${TALOSCTL_URL:-https://github.com/siderolabs/talos/releases/download/${VERSION_TALOSCTL}}"
KUBECTL_URL="${KUBECTL_URL:-https://dl.k8s.io/release/${VERSION_KUBECTL}/bin/linux/amd64}"
HELM_URL="${HELM_URL:-https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4}"
K8S_OPERATOR_URL="${K8S_OPERATOR_URL:-https://github.com/operator-framework/operator-lifecycle-manager/releases/latest/download}"

K8s_OPERATOR_DIR="${K8s_OPERATOR_DIR:-${CLUSTER_DEPLOY_DIR}/operators-olm}"

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
# Install prereq on localhost to generate cluster privisioning resources
# ------------------------------------------------------------------------------
install_k8s_operator() {
    log_info "Downloading and installing kubernetes CRDs for OLM operators."

    local install_path="${1:-${K8s_OPERATOR_DIR}}"
    if ! exists "file" "$install_path"; then
        log_debug "Installing CRDs and OLM resources for OLM"

        cd ${K8s_OPERATOR_DIR}
        curl -L "${K8S_OPERATOR_URL}/crds.yaml" -o crds.yaml
        curl -L "${K8S_OPERATOR_URL}/olm.yaml" -o olm.yaml
    fi

    log_success "Downloaded resources successfully"
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
    validate_required_args PROJECT_NAME BIN_DIR DRY_RUN \
        TALOSCONFIG KUBECONFIG \
        VERSION_TALOSCTL VERSION_KUBECTL VERSION_GATEWAY_API VERSION_CRT_MNG_PLUGIN VERSION_KUBESEAL \
        CLOUD_PROVIDER_PAT CLOUD_PROVIDER_REGION GIT_REPO \
        ACCESS_SSHKEY_PATH FLUXCD_SSHKEY_PATH \
        VPC_CIDR \
        NODETYPE_BASTION NODETYPE_CLUSTER \
        IMG_BASTION IMG_CLUSTER \
        CLUSTER_ENDPOINT WORKER_NODES

    # Install CLI tools (talosctl, kubectl, helm)
    provision_prerequisites

    # Install custom CRDs for K8s operators if not present
    install_k8s_operator

    # Generate SSH keys
    # 1. ssh key for cluster access via bastion
    # 2. ssh key for flux cd

    # Organize if needed
    export TALOSCONFIG=${TALOSCONFIG}
    export KUBECONFIG=${KUBECONFIG}

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
