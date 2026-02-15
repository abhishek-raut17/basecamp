#!/usr/bin/env bash
#
# Bastion: init file for initializing bastion for cluster management
#
# [Deprecated]: This is kept here for backward compactibility
#

set -euo pipefail

declare -r INITD="/usr/local/lib/initd"
declare -r IPHOST_REGEX='^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
declare -r SUBNET_REGEX='^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/([0-9]|[1-2][0-9]|3[0-2])$'

# ----------------------------------------------------------------------------
# Configuration (can be overridden via environment)
# ---------------------------------------------------------------------------
RELEASE_VERSION="${RELEASE_VERSION:-v1.0.0}"
VERSION="${VERSION:-v1.0.0}"
LOG_LEVEL=${LOG_LEVEL:-0}

TALOS_DIR="${TALOS_DIR:-/root/.talos}"
KUBE_DIR="${KUBE_DIR:-/root/.kube}"

GIT_REPO="${GIT_REPO:-ssh://git@github.com/abhishek-raut17/basecamp.git}"
FLUXCD_SSHKEY_PATH="${FLUXCD_SSHKEY_PATH:-/tmp/devops_cd}"
CLOUD_PROVIDER_PAT="${CLOUD_PROVIDER_PAT:-}"
CLOUD_PROVIDER_REGION=${CLOUD_PROVIDER_REGION:-us-ord}

VERSION_TALOSCTL=${VERSION_TALOSCTL:-v1.11.2}
VERSION_KUBECTL=${VERSION_KUBECTL:-v1.34.1}
VERSION_FLUXCD=${VERSION_FLUXCD:-}
VERSION_HELM=${VERSION_HELM:-}
VERSION_GATEWAY_API=${VERSION_GATEWAY_API:-v1.4.1}
VERSION_CRT_MNG_PLUGIN=${VERSION_CRT_MNG_PLUGIN:-v0.2.0}
VERSION_KUBESEAL=${VERSION_KUBESEAL:-v0.30.0}

TALOSCTL_URL="${TALOSCTL_URL:-https://github.com/siderolabs/talos/releases/download/${VERSION_TALOSCTL}}"
KUBECTL_URL="${KUBECTL_URL:-https://dl.k8s.io/release/${VERSION_KUBECTL}/bin/linux/amd64}"
FLUXCD_URL="${FLUXCD_URL:-https://fluxcd.io/install.sh}"
HELM_URL="${HELM_URL:-https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4}"
K8S_GATEWAY_API="${K8S_GATEWAY_API:-https://github.com/kubernetes-sigs/gateway-api/releases/download/${VERSION_GATEWAY_API}/standard-install.yaml}"
CERT_MNG_PLUGIN="${CERT_MNG_PLUGIN:-https://github.com/slicen/cert-manager-webhook-linode/releases/download/${VERSION_CRT_MNG_PLUGIN}/cert-manager-webhook-linode-${VERSION_CRT_MNG_PLUGIN}.tgz}"
KUBESEAL_URL="${KUBESEAL_URL:-https://github.com/bitnami-labs/sealed-secrets/releases/download/${VERSION_KUBESEAL}/kubeseal-${VERSION_KUBESEAL#v}-linux-amd64.tar.gz}"
KUBESEAL_CONTOLLER_URL="${KUBESEAL_CONTOLLER_URL:-https://github.com/bitnami-labs/sealed-secrets/releases/download/${VERSION_KUBESEAL}/controller.yaml}"

NGINX_DIR="${NGINX_DIR:-${INITD}/modules/nginx-gateway}"
ACME_CERT_DIR="${NGINX_DIR:-${INITD}/modules/acme-cert}"
COTURN_DIR="${COTURN_DIR:-${INITD}/modules/coturn}"

CLUSTER_NAME="${CLUSTER_NAME:-basecamp}"
CLUSTER_SUBNET="${CLUSTER_SUBNET:-10.5.0.0/16}"
CLUSTER_ENDPOINT="${CLUSTER_ENDPOINT:-10.5.0.10}"

# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "${INITD}/shared/logger.sh"
source "${INITD}/shared/utils.sh"

# -------------------------------------------------------------------------------
# Validate argument values
# -------------------------------------------------------------------------------
validate_arg() {
    local name="$1"
    local value="$2"

    case "$name" in
        --ccm-token)
            if [[ -z "$value" ]]; then
                log_warn "Admin token not provided. Please retry with valid admin token"
            fi
            ;;
        --cluster-name)
            if [[ -z "$value" ]]; then
                log_warn "Cluster name not provided. Using default: ${CLUSTER_NAME}"
            fi
            ;;
        --cluster-endpoint)
            if [[ -z "$value" ]]; then
                log_warn "Cluster endpoint not provided. Using default: ${CLUSTER_ENDPOINT}"
            fi
            if ! [[ $value =~ $IPHOST_REGEX ]]; then
                log_warn "Cluster endpoint not in proper ipv4 host format. Ref default: ${CLUSTER_ENDPOINT}"
            fi
            ;;
        --cluster-subnet)
            if [[ -z "$value" ]]; then
                log_warn "Cluster subnet not provided. Using default: ${CLUSTER_SUBNET}"
            fi
            if ! [[ $value =~ $SUBNET_REGEX ]]; then
                log_warn "Cluster subnet not in proper ipv4 subnet format. Ref default: ${CLUSTER_SUBNET}"
            fi
            ;;
    esac
}

# -------------------------------------------------------------------------------
# Parse command-line arguments
# -------------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cluster-name)
                CLUSTER_NAME="$2"
                validate_arg "$1" "$2"
                shift 2
                ;;
            --cluster-endpoint)
                CLUSTER_ENDPOINT="$2"
                validate_arg "$1" "$2"
                shift 2
                ;;
            --cluster-subnet)
                CLUSTER_SUBNET="$2"
                validate_arg "$1" "$2"
                shift 2
                ;;
            --ccm-token)
                CLOUD_PROVIDER_PAT="$2"
                validate_arg "$1" "$2"
                shift 2
                ;;
            --sshkey-path)
                FLUXCD_SSHKEY_PATH="$2"
                shift 2
                ;;
            --talos-version)
                VERSION_TALOSCTL="$2"
                shift 2
                ;;
            --kube-version)
                VERSION_KUBECTL="$2"
                shift 2
                ;;
            --kubeseal-version)
                VERSION_KUBESEAL="$2"
                shift 2
                ;;
            --k8s-gateway-version)
                VERSION_GATEWAY_API="$2"
                shift 2
                ;;
            --cert-manager-plugin-version)
                VERSION_CRT_MNG_PLUGIN="$2"
                shift 2
                ;;
            --git-repo)
                GIT_REPO="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                exit 2
                ;;
        esac
    done
}

# -------------------------------------------------------------------------------
# Display usage information
# -------------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS]

Options:
  --cluster-name <name>                         Cluster name (default: ${CLUSTER_NAME})
  --cluster-endpoint <host>                     Cluster endpoint (default: ${CLUSTER_ENDPOINT})
  --cluster-subnet <cidr>                       Cluster subnet (default: ${CLUSTER_SUBNET})
  --ccm-token <token>                           Admin token for DNS provider challenges
  --sshkey-path <path>                          SSH key path (default: ${FLUXCD_SSHKEY_PATH})
  --talos-version <version>                     Talos version (default: ${VERSION_TALOSCTL})
  --kube-version <version>                      Kubectl version (default: ${VERSION_KUBECTL})
  --kubeseal-version <version>                  Kubeseal version (default: ${VERSION_KUBESEAL})
  --k8s-gateway-version <version>               Kubernetes gateway API version (default: ${VERSION_GATEWAY_API})
  --cert-manager-plugin-version <version>       kubernetes cert manager plugin version (default: ${VERSION_CRT_MNG_PLUGIN})
  --git-repo <url>                              Git repository URL (default: ${GIT_REPO})
  -h, --help                                    Show this help message

Examples:
  ${0##*/} --cluster-name basecamp --cluster-endpoint 10.0.10.10 --cluster-subnet 10.0.10.0/24 --ccm-token <token>

EOF
}

# -------------------------------------------------------------------------------
# Validate environment configuration
# -------------------------------------------------------------------------------
validate_environment() {
    log_section "Validating environment configuration"

    # Check if required tools are available
    local required_tools=("bash" "grep")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_error "Required tool not found: $tool"
            exit 1
        fi
    done

    # Validate directory structure
    if [[ ! -d "$INITD" ]]; then
        log_error "INITD directory does not exist: $INITD"
        exit 1
    fi

    if [[ ! -f "${INITD}/run.sh" ]]; then
        log_error "Run module not found: ${INITD}/run.sh"
        exit 1
    fi

    if [[ ! -f "${INITD}/shared/logger.sh" ]]; then
        log_error "Logger module not found: ${INITD}/shared/logger.sh"
        exit 1
    fi

    if [[ ! -f "${INITD}/shared/utils.sh" ]]; then
        log_error "Utils module not found: ${INITD}/shared/utils.sh"
        exit 1
    fi

    # Validate required parameters
    if [[ -z "$CLOUD_PROVIDER_PAT" ]]; then
        log_error "fatal error: No Cloud Controller Manager (CCM) token provided for resource creation."
        log_error "Please provide --ccm-token parameter"
        exit 1
    fi

    # Validate cluster configuration
    if ! [[ $CLUSTER_ENDPOINT =~ $IPHOST_REGEX ]]; then
        log_error "Invalid cluster endpoint format: $CLUSTER_ENDPOINT"
        log_error "Must be a valid IPv4 address"
        exit 1
    fi

    if ! [[ $CLUSTER_SUBNET =~ $SUBNET_REGEX ]]; then
        log_error "Invalid cluster subnet format: $CLUSTER_SUBNET"
        log_error "Must be a valid IPv4 CIDR (e.g., 10.0.10.0/24)"
        exit 1
    fi

    if [[ -z "$CLUSTER_NAME" ]]; then
        log_error "Cluster name cannot be empty"
        exit 1
    fi

    log_success "Environment validation passed"
}

# -------------------------------------------------------------------------------
# Export configuration for run.sh
# -------------------------------------------------------------------------------
export_configuration() {
    log_debug "Exporting configuration variables"

    # Export all configuration variables
    export RELEASE_VERSION
    export VERSION
    export LOG_LEVEL
    export CLOUD_PROVIDER_REGION
    export TALOS_DIR
    export KUBE_DIR
    export GIT_REPO
    export FLUXCD_SSHKEY_PATH
    export CLOUD_PROVIDER_PAT
    export VERSION_TALOSCTL
    export VERSION_KUBECTL
    export VERSION_FLUXCD
    export VERSION_HELM
    export VERSION_GATEWAY_API
    export VERSION_CRT_MNG_PLUGIN
    export VERSION_KUBESEAL
    export TALOSCTL_URL
    export KUBECTL_URL
    export FLUXCD_URL
    export HELM_URL
    export KUBESEAL_URL
    export KUBESEAL_CONTOLLER_URL
    export K8S_GATEWAY_API
    export CERT_MNG_PLUGIN
    export NGINX_DIR
    export ACME_CERT_DIR
    export COTURN_DIR
    export CLUSTER_NAME
    export CLUSTER_SUBNET
    export CLUSTER_ENDPOINT
}

# -------------------------------------------------------------------------------
# Main function
# -------------------------------------------------------------------------------
main() {
    # Setup error handling
    trap cleanup_on_error EXIT ERR INT TERM

    # Display banner
    log_section "Pre-initialization: Argument parsing and validation"
    log_info "Release version   : ${RELEASE_VERSION}"
    log_info "Binary version    : ${VERSION}"
    echo ""

    # Parse command-line arguments
    parse_args "$@"

    # Validate environment and configuration
    validate_environment

    # Export configuration for init.sh
    export_configuration

    # Display configuration summary
    log_section "Cluster Configuration Summary"
    log_info "Cluster name      : ${CLUSTER_NAME}"
    log_info "Cluster endpoint  : ${CLUSTER_ENDPOINT}"
    log_info "Cluster subnet    : ${CLUSTER_SUBNET}"
    log_info "Talos version     : ${VERSION_TALOSCTL}"
    log_info "Kubectl version   : ${VERSION_KUBECTL}"
    log_info "Cloud region      : ${CLOUD_PROVIDER_REGION}"
    log_info "Git repo          : ${GIT_REPO}"
    echo ""
}

# -------------------------------------------------------------------------------
# Execute main function
# -------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
# -------------------------------------------------------------------------------
