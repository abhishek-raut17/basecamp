#!/usr/bin/env bash
#

set -euo pipefail

# ------------------------------------------------------------------------------
# Script directory detection
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# ------------------------------------------------------------------------------
# Source utility modules
# ------------------------------------------------------------------------------
source "${SCRIPT_DIR}/bin/logger.sh"
source "${SCRIPT_DIR}/bin/utils.sh"
source "${SCRIPT_DIR}/bin/validator.sh"
source "${SCRIPT_DIR}/bin/provisioner.sh"
source "${SCRIPT_DIR}/bin/bootstrap.sh"

# ------------------------------------------------------------------------------
# Default configuration
# ------------------------------------------------------------------------------
declare -r DEFAULT_VERSION="v3.3.0"
declare -r DEFAULT_CLUSTER_NAME="basecamp"
declare -r DEFAULT_WORKERS=0
declare -r DEFAULT_CONFIG_DIR="/root/.config"
declare -r DEFAULT_BASHRC_PATH="/root/.bashrc"
declare -r DEFAULT_TALOSCONFIG_PATH="/tmp/talosconfig"
declare -r DEFAULT_TALOSCTL_VERSION="v1.11.2"
declare -r DEFAULT_KUBECTL_VERSION="v1.34.1"
declare -r DEFAULT_CALICO_VERSION="v3.31.2"
declare -r DEFAULT_POD_CIDR="10.244.0.0/16"
declare -r DEFAULT_LOG_LEVEL=0

# Script variables
BOOTSTRAP_VERSION="${DEFAULT_VERSION}"
CLUSTER_NAME="${DEFAULT_CLUSTER_NAME}"
CLUSTER_SUBNET=""
CONTROLPLANE_IP=""
GIT_PAT=""
GIT_USER="abhishek-raut17"
WORKERS=${DEFAULT_WORKERS}
CONFIG_DIR="${DEFAULT_CONFIG_DIR}"
BASHRC_PATH="${DEFAULT_BASHRC_PATH}"
CUSTOMIZATION_DIR="${SCRIPT_DIR}/configs"
TALOSCONFIG_PATH="${DEFAULT_TALOSCONFIG_PATH}"
TALOSCTL_VERSION="${DEFAULT_TALOSCTL_VERSION}"
KUBECTL_VERSION="${DEFAULT_KUBECTL_VERSION}"
CALICO_VERSION="${DEFAULT_CALICO_VERSION}"
POD_CIDR="${DEFAULT_POD_CIDR}"
LOG_LEVEL=$DEFAULT_LOG_LEVEL

# Derived variables
TALOSCONFIG_DIR="${CONFIG_DIR}/.talos"
KUBECONFIG_DIR="${CONFIG_DIR}/.kube"
TALOSCONFIG="${TALOSCONFIG_DIR}/config"
KUBECONFIG="${KUBECONFIG_DIR}/config"

# Tools manifests
TALOSCTL_URL="https://github.com/siderolabs/talos/releases/download/$TALOSCTL_VERSION"
KUBECTL_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64"
HELM_URL="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4"
FLUXCD_URL="https://fluxcd.io/install.sh"

# Yaml manifests
CNI_BASE_YAML="https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml"

# ------------------------------------------------------------------------------
# Main execution
# ------------------------------------------------------------------------------
main() {
    # Setup error handling
    trap cleanup_on_error EXIT ERR INT TERM

    # Setup logging (default: DEBUG)
    export LOG_LEVEL=${LOG_LEVEL}

    # Display banner
    log_section "Talos Kubernetes Cluster Bootstrap"
    log_info "Version: ${BOOTSTRAP_VERSION}"
    echo ""

    # Validate arguments and required paramters
    parse_and_validate_arguments "$@"
    validate_required_args

    # Provision resources and prerequsities on bastion host
    provision_config "TALOSCONFIG" "$TALOSCONFIG"
    provision_config "KUBECONFIG" "$KUBECONFIG"
    provision_prerequisites

    # Bootstrap cluster
    initialize_bootstrap

    # Day-2 operations
    post_bootstrap

    # Success
    log_section "Bootstrap Complete"
    log_success "Talos cluster '${CLUSTER_NAME}' is ready!"
    echo ""
    log_info "Configuration files:"
    echo " TALOSCONFIG: ${CONFIG_DIR}/${CLUSTER_NAME}/.talos/config"
    echo " KUBECONFIG: ${CONFIG_DIR}/${CLUSTER_NAME}/.kube/config"
    echo ""
}

# ------------------------------------------------------------------------------
# Execute main function
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# ------------------------------------------------------------------------------
