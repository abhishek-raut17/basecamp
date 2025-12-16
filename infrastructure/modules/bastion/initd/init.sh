#!/usr/bin/env bash
#
# Bastion bin: init file for initializing bastion for cluster management
#
set -euo pipefail

declare -r INITD="/usr/local/bin/initd"

# ----------------------------------------------------------------------------
# Configuration (can be overridden via environment)
# ---------------------------------------------------------------------------
RELEASE_VERSION="${RELEASE_VERSION:-v1.0.0}"
VERSION="${VERSION:-v1.0.0}"
LOG_LEVEL=${LOG_LEVEL:-0}

TALOS_DIR="${TALOS_DIR:-/root/.configs/.talos}"
KUBE_DIR="${KUBE_DIR:-/root/.configs/.kube}"
GIT_REPO="${GIT_REPO:-ssh://git@github.com/abhishek-raut17/basecamp.git}"
SSH_KEY_PATH="${SSH_KEY_PATH:-/tmp/devops_cd}"

V_TALOSCTL=${V_TALOSCTL:-v1.11.2}
V_KUBECTL=${V_KUBECTL:-v1.34.1}
V_FLUXCD=${V_FLUXCD:-}
TALOSCTL_URL="${TALOSCTL_URL:-https://github.com/siderolabs/talos/releases/download/${V_TALOSCTL}}"
KUBECTL_URL="${KUBECTL_URL:-https://dl.k8s.io/release/${V_KUBECTL}/bin/linux/amd64}"
FLUXCD_URL="${FLUXCD_URL:-https://fluxcd.io/install.sh}"

CLUSTER_SUBNET="${CLUSTER_SUBNET:-10.0.10.0/24}"
CLUSTER_ENDPOINT="${CLUSTER_ENDPOINT:-10.0.10.10}"

# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "${INITD}/shared/logger.sh"
source "${INITD}/shared/utils.sh"

# ------------------------------------------------------------------------------
# Install prereq on bastion to generate cluster privisioning resources
# ------------------------------------------------------------------------------
provision_prerequisites() {
    local talos_url="${1:-${TALOSCTL_URL}}"
    local kube_url="${2:-${KUBECTL_URL}}"
    local flux_url="${3:-${FLUXCD_URL}}"

    log_info "Provisioning prerequsities"

    # Install talosctl
    install_bin "talosctl-linux-amd64" "sha256sum.txt" "$talos_url"

    # Install kubectl
    install_bin "kubectl" "kubectl.sha256" "$kube_url"

    # Install Helm
    # install_tool "helm" "$helm_url"

    # Install FluxCD
    install_tool "flux" "$flux_url"

    log_success "Provisioned prerequsities successfully"
}

# ----------------------------------------------------------------------------
# Argument parsing and usage
# ----------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS]

Options:
  --talos-dir <path>            Path for talos configs (default: ${TALOS_DIR})
  --kube-dir <path>             Path for kube configs (default: ${KUBE_DIR})
  --talos-version <string>      URL to download talosctl (default: ${TALOSCTL_URL})
  --kube-version <string>       URL to download kubectl (default: ${KUBECTL_URL})
  --cluster-subnet <cidr>       Cluster subnet (default: ${CLUSTER_SUBNET})
  --cluster-endpoint <host>     Cluster endpoint (default: ${CLUSTER_ENDPOINT})
  -h, --help                    Show this help message

Examples:
  ${0##*/} --cluster-endpoint 10.0.10.10 --cluster-subnet 10.0.10.0/24

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --sshkey-path)
                SSH_KEY_PATH="$2"; shift 2;;
            --cluster-endpoint)
                CLUSTER_ENDPOINT="$2"; shift 2;;
            --cluster-subnet)
                CLUSTER_SUBNET="$2"; shift 2;;
            --talos-dir)
                TALOS_DIR="$2"; shift 2;;
            --kube-dir)
                KUBE_DIR="$2"; shift 2;;
            --git-repo)
                GIT_REPO="$2"; shift 2;;
            --talos-version)
                V_TALOSCTL="$2"; shift 2;;
            --kube-version)
                V_KUBECTL="$2"; shift 2;;
            --fluxcd-version)
                V_FLUXCD="$2"; shift 2;;
            -h|--help)
                usage; exit 0;;
            --)
                shift; break;;
            *)
                echo "Unknown option: $1" >&2; usage; exit 2;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Main function
# ------------------------------------------------------------------------------
main() {

    # Setup error handling
    trap cleanup_on_error EXIT ERR INT TERM

    # Parse command-line arguments to allow inline overrides
    parse_args "$@"

    # Display banner
    log_section "Setup machine configs for cluster nodes"
    log_info "Release version   : ${RELEASE_VERSION}"
    log_info "Binary version    : ${VERSION}"
    echo ""

    # Step 1: Check and add route to cluster subnet
    log_info "Validating IP route to cluster subnet: ${CLUSTER_SUBNET}"
    ip route add ${CLUSTER_SUBNET} dev eth1 2>/dev/null || echo ' --- Route may already exist --- '
    ip route show

    # Step 2: Create config files for talosctl and kubectl
    log_info "Creating config files for talosctl and kubectl for cluster access"
    create_file "${TALOS_DIR}/config"
    create_file "${KUBE_DIR}/config"

    # Step 2.1: Export config files for default access via cli
    echo "export TALOSCONFIG=${TALOS_DIR}/config" >> /root/.bashrc
    echo "export KUBECONFIG=${KUBE_DIR}/config" >> /root/.bashrc

    # Step 3: Install bin and tools for cluster management
    provision_prerequisites

    # Step 4: Setup talosctl config nodes, endpoint
    log_info "Copying /tmp/talosconfig to ${TALOS_DIR}/config"
    if cp /tmp/talosconfig "${TALOS_DIR}/config" 2>/dev/null; then
        log_debug "Copied /tmp/talosconfig successfully"
    else
        log_debug "File /tmp/talosconfig does not exist"    
    fi

    log_info "Setting up talos nodes and endpoint for cluster: ${CLUSTER_ENDPOINT}"
    # talosctl config merge /tmp/talosconfig --talosconfig ${TALOS_DIR}/config
    talosctl config nodes ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config 2>/dev/null
    talosctl config endpoint ${CLUSTER_ENDPOINT} --nodes ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config 2>/dev/null

    # Step 5: Bootstrap talos nodes
    if talosctl --nodes ${CLUSTER_ENDPOINT} --endpoints ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config etcd members >/dev/null 2>&1; then
        log_warn "Cluster already bootstrap at endpoint: ${CLUSTER_ENDPOINT}"
    else
        log_info "Initializing bootstrap process for talos nodes"
        if talosctl bootstrap --nodes ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config; then
            log_success "Cluster at endpoint: ${CLUSTER_ENDPOINT} bootstrapped successfully"
        else
            log_error "Failed to bootstrap cluster at endpoint: ${CLUSTER_ENDPOINT}"
            exit 1
        fi
    fi

    # Step 6: Setup kubeconfig
    log_info "Generating kubeconfig for cluster node access"
    talosctl kubeconfig --nodes ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config --merge --force

    log_debug "Sleeping for 10s waiting for cluster to bootup"
    sleep 10 # needed due to slow bootup speeds of ec2 instances

    # Log cluster initial state
    log_info "Cluster health: endpoint: ${CLUSTER_ENDPOINT}"
    talosctl health --nodes ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config
    # kubectl get nodes -o wide

    # Bootstrap flux
    if command -v flux >/dev/null 2>&1; then
        log_info "Bootstraping FluxCD for git repo: ${GIT_REPO}"

        if ! exists "file" "$SSH_KEY_PATH"; then
            log_debug "SSH key for devops_cd doesnt exists at: $SSH_KEY_PATH. Copy .pub file for deploy key"
            ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "fluxcd-devops" || {
                log_error "Cannot find or generate ssh key to bootstrap fluxcd"
                exit 1
            }
        else
            log_debug "Found SSH key for FluxCD bootstrap at: $SSH_KEY_PATH"
        fi

        flux bootstrap git \
            --url=${GIT_REPO} \
            --branch=deployment \
            --private-key-file=${SSH_KEY_PATH} \
            --author-name="Flux Bot" \
            --author-email="flux-bot@sigdep.cloud" \
            --path=clusters/production \
            --silent
    fi

    # Success
    log_success "Bastion host setup completed successfully"
    log_section "Cluster setup completed: Endpoint: ${CLUSTER_ENDPOINT}"

    # Cleanup
    rm -rf kubectl.sha256
    rm -rf sha256sum.txt
    # rm -rf /tmp/talosconfig
}

# ------------------------------------------------------------------------------
# Execute main function
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# ------------------------------------------------------------------------------
