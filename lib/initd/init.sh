#!/usr/bin/env bash
#
# Bastion: init file for initializing bastion for cluster management
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
CLOUD_PROVIDER_REGION=${CLOUD_PROVIDER_REGION:-us-ord}

TALOS_DIR="${TALOS_DIR:-/root/.talos}"
KUBE_DIR="${KUBE_DIR:-/root/.kube}"

GIT_REPO="${GIT_REPO:-ssh://git@github.com/abhishek-raut17/basecamp.git}"
FLUXCD_SSHKEY_PATH="${FLUXCD_SSHKEY_PATH:-/tmp/devops_cd}"
CLOUD_PROVIDER_PAT="${CLOUD_PROVIDER_PAT:-}"

VERSION_TALOSCTL=${VERSION_TALOSCTL:-v1.11.2}
VERSION_KUBECTL=${VERSION_KUBECTL:-v1.34.1}
VERSION_FLUXCD=${VERSION_FLUXCD:-}
VERSION_HELM=${VERSION_HELM:-}
VERSION_GATEWAY_API=${VERSION_GATEWAY_API:-v1.4.1}
VERSION_CRT_MNG_PLUGIN=${VERSION_CRT_MNG_PLUGIN:-v0.2.0}

TALOSCTL_URL="${TALOSCTL_URL:-https://github.com/siderolabs/talos/releases/download/${VERSION_TALOSCTL}}"
KUBECTL_URL="${KUBECTL_URL:-https://dl.k8s.io/release/${VERSION_KUBECTL}/bin/linux/amd64}"
FLUXCD_URL="${FLUXCD_URL:-https://fluxcd.io/install.sh}"
HELM_URL="${HELM_URL:-https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4}"
K8S_GATEWAY_API="${K8S_GATEWAY_API:-https://github.com/kubernetes-sigs/gateway-api/releases/download/${VERSION_GATEWAY_API}/standard-install.yaml}"
CERT_MNG_PLUGIN="${CERT_MNG_PLUGIN:-https://github.com/slicen/cert-manager-webhook-linode/releases/download/${VERSION_CRT_MNG_PLUGIN}/cert-manager-webhook-linode-${VERSION_CRT_MNG_PLUGIN}.tgz}"

NGINX_DIR="${NGINX_DIR:-${INITD}/modules/nginx-gateway}"
NGINX_CONF="${NGINX_CONF:-${NGINX_DIR}/nginx.conf}"
NGINX_STREAM_CONF="${NGINX_STREAM_CONF:-${NGINX_DIR}/nginx-stream.conf}"
NGINX_TUNING_CONF="${NGINX_TUNING_CONF:-${NGINX_DIR}/99-nginx-tuning.conf}"

CLUSTER_NAME="${CLUSTER_NAME:-basecamp}"
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
    local helm_url="${3:-${HELM_URL}}"

    log_info "Provisioning prerequisites"

    # Install talosctl
    install_bin "talosctl-linux-amd64" "sha256sum.txt" "$talos_url"

    # Install kubectl
    install_bin "kubectl" "kubectl.sha256" "$kube_url"

    # Install Helm
    install_tool "helm" "$helm_url"

    # Install FluCD
    install_tool "flux" "$flux_url"

    log_success "Provisioned prerequisites successfully"
}

# ----------------------------------------------------------------------------
# Ensure that bastion can connect to cluster subnet ip route
# ----------------------------------------------------------------------------
add_route_to_cluster() {
    log_info "Validating IP route from bastion/gateway to cluster subnet: ${CLUSTER_SUBNET}"
    ip route add ${CLUSTER_SUBNET} dev eth1 2>/dev/null || echo ' --- Route may already exist --- '
    ip route show
}

# ----------------------------------------------------------------------------
# Use custom env vars for TALOSCONFIG and KUBECOFIG for cluster management
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Update talosconfig for cluster with endpoint and controlplane node(s) details
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Update kubeconfig for cluster access
# ----------------------------------------------------------------------------
setup_kubectl() {
    log_info "Generating kubeconfig for cluster node access"
    talosctl kubeconfig --nodes ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config --merge --force
}

# ----------------------------------------------------------------------------
# Setup Lindoe Cloud controller manager for provisioning CSI driver
# ----------------------------------------------------------------------------
setup_ccm_controller() {
    log_info "Deploying Linode CCM controller"
    helm repo add ccm-linode https://linode.github.io/linode-cloud-controller-manager/
    helm repo update ccm-linode

    if ! resource_exists "ds" "ccm-linode"; then

        log_debug "Installing ccm-linode controller"
        helm install ccm-linode ccm-linode/ccm-linode \
            --namespace kube-system \
            --set secretRef.name=linode-token \
            --set secretRef.apiTokenRef=token \
            --set secretRef.regionRef=region \
            --set image.pullPolicy=IfNotPresent \
            --set logVerbosity=3 \
            --wait \
            --timeout 5m
    fi
            
    if ! kubectl wait --for=condition=ready pod -l app=ccm-linode -n kube-system --timeout=300s; then
        log_error "fatal error: timeout waiting for linode ccm-linode controller pod to be ready"
        exit 1
    fi
}

# ----------------------------------------------------------------------------
# Setup Lindoe block storage driver to manage CSI for cluster
# ----------------------------------------------------------------------------
setup_csi_driver() {
    log_info "Deploying Linode blockstorage CSI driver"
    helm repo add linode-csi https://linode.github.io/linode-blockstorage-csi-driver/
    helm repo update linode-csi

    if ! resource_exists "ds" "csi-linode-node"; then

        log_debug "Installing linode-csi controller"
        helm install linode-csi-driver linode-csi/linode-blockstorage-csi-driver \
            --set apiToken="${CLOUD_PROVIDER_PAT}" \
            --set region="${CLOUD_PROVIDER_REGION}" \
            --wait \
            --timeout 5m
    fi
            
    if ! kubectl wait --for=condition=ready pod -l app=csi-linode-node -n kube-system --timeout=300s; then
        log_error "fatal error: timeout waiting for linode csi-linode pod(s) to be ready."
        exit 1
    fi
}

# ----------------------------------------------------------------------------
# Bootstrap cluster nodes via bastion host using talosctl
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Bootstrap fluxCD for GitOps
# ----------------------------------------------------------------------------
bootstrap_fluxcd() {
    if command -v flux >/dev/null 2>&1; then
        log_info "Bootstraping FluxCD for git repo: ${GIT_REPO}"

        if ! exists "file" ${FLUXCD_SSHKEY_PATH}; then
            log_debug "SSH key for devops_cd doesnt exists at: ${FLUXCD_SSHKEY_PATH}. Copy .pub file for deploy key"
            ssh-keygen -t ed25519 -f ${FLUXCD_SSHKEY_PATH} -N "" -C "fluxcd-devops" || {
                log_error "Cannot find or generate ssh key to bootstrap fluxcd"
                exit 1
            }
        else
            log_debug "Found SSH key for FluxCD bootstrap at: ${FLUXCD_SSHKEY_PATH}"
        fi

        flux bootstrap git \
            --url=${GIT_REPO} \
            --branch=development \
            --private-key-file=${FLUXCD_SSHKEY_PATH} \
            --author-name="Flux Bot" \
            --author-email="flux-bot@sigdep.cloud" \
            --path=clusters/deploy \
            --silent
    fi
}

# ----------------------------------------------------------------------------
# Bootstrap fluxCD for GitOps
# ----------------------------------------------------------------------------
setup_cluster_gateway() {
    log_info "Initializing nginx gateway as TCP passthrough for cluster"

    if ! dpkg -l | grep "nginx" 2>&1; then
        log_debug "Nginx not found. Installing..."
        apt update
        apt install -y nginx libnginx-mod-stream
    else
        log_debug "Nginx is already installed."
    fi

    systemctl stop nginx

    # Setup root config for nginx
    if ! exists "file" ${NGINX_CONF}; then
        log_warn "Root config for nginx doesnt exists at: ${NGINX_CONF}."
        exit 1
    else
        log_debug "Found root config for nginx at: ${NGINX_CONF}"
        cp ${NGINX_CONF} /etc/nginx/nginx.conf
    fi

    # Setup kernel tuning config for nginx TCP passthrough
    if ! exists "file" ${NGINX_TUNING_CONF}; then
        log_warn "Kernel tuning config for nginx doesnt exists at: ${NGINX_TUNING_CONF}."
        exit 1
    else
        log_debug "Found kernel tuning config for nginx at: ${NGINX_TUNING_CONF}"
        cp ${NGINX_TUNING_CONF} /etc/sysctl.d/99-nginx-tuning.conf
    fi

    systemctl enable nginx
    systemctl start nginx

    if systemctl is-active --quiet nginx; then
        log_debug "Nginx is running successfully!"
    else
        log_debug "Nginx failed to start. Checking status..."
        systemctl status nginx
        exit 1
    fi
}

# ----------------------------------------------------------------------------
# Argument parsing and usage
# ----------------------------------------------------------------------------
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
  --k8s-gateway-version <version>               Kubernetes gateway API version (default: ${VERSION_GATEWAY_API})
  --cert-manager-plugin-version <version>       kubernetes cert manager plugin version (default: ${VERSION_CRT_MNG_PLUGIN})
  --git-repo <url>                              Git repository URL (default: ${GIT_REPO})
  -h, --help                                    Show this help message

Examples:
  ${0##*/} --cluster-name basecamp --cluster-endpoint 10.0.10.10 --cluster-subnet 10.0.10.0/24 --ccm-token <token>

EOF
}

validate_arg() {
    local name="$1"
    local value="$2"

    case "$1" in
        --admin-token)
            if [[ -z "$value" ]]; then
                log_warn "Admin token not provided. Please retry with valid admin token"
            fi
            break;;
        --cluster-name)
            if [[ -z "$value" ]]; then
                log_warn "Cluster name not provided. Using default: ${CLUSTER_NAME}"
            fi
            break;;
        --cluster-endpoint)
            if [[ -z "$value" ]]; then
                log_warn "Cluster endpoint not provided. Using default: ${CLUSTER_ENDPOINT}"
            fi
            if ! [[ $value =~ $IPHOST_REGEX ]]; then
                log_warn "Cluster endpoint not in proper ipv4 host format. Ref default: ${CLUSTER_ENDPOINT}"
            fi
            break;;
        --cluster-subnet)
            if [[ -z "$value" ]]; then
                log_warn "Cluster subnet not provided. Using default: ${CLUSTER_SUBNET}"
            fi
            if ! [[ $value =~ $SUBNET_REGEX ]]; then
                log_warn "Cluster subnet not in proper ipv4 subnet format. Ref default: ${CLUSTER_SUBNET}"
            fi
            break;;
    esac
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cluster-name)
                CLUSTER_NAME="$2"; shift 2;;
            --cluster-endpoint)
                CLUSTER_ENDPOINT="$2"; shift 2;;
            --cluster-subnet)
                CLUSTER_SUBNET="$2"; shift 2;;
            --ccm-token)
                CLOUD_PROVIDER_PAT="$2"; shift 2;;
            --sshkey-path)
                FLUXCD_SSHKEY_PATH="$2"; shift 2;;
            --talos-version)
                VERSION_TALOSCTL="$2"; shift 2;;
            --kube-version)
                VERSION_KUBECTL="$2"; shift 2;;
            --k8s-gateway-version)
                VERSION_GATEWAY_API="$2"; shift 2;;
            --cert-manager-plugin-version)
                VERSION_CRT_MNG_PLUGIN="$2"; shift 2;;
            --git-repo)
                GIT_REPO="$2"; shift 2;;
            -h|--help)
                usage; exit 0;;
            --)
                shift; break;;
            *)
                log_debug "Unknown argument: $1" >&2; usage; exit 2;;
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

    if [[ -z $CLOUD_PROVIDER_PAT ]]; then
        log_error "fatal error: No Cloud Controller Manager (CCM) token provided for resource creation."
        exit 1
    fi

    # Display banner
    log_section "Setup bastion host to manage cluster: ${CLUSTER_NAME}"
    log_info "Release version   : ${RELEASE_VERSION}"
    log_info "Binary version    : ${VERSION}"
    echo ""

    # Step 1: Verfiy and/or add route to cluster subnet
    add_route_to_cluster

    # Step 2: Create config files for talosctl and kubectl and add environment var to .bashrc for future use
    setup_env_vars

    # Step 3: Install bin and tools for cluster management
    provision_prerequisites

    # Step 4: Setup talosconfig to config nodes, endpoint for cluster access
    setup_talosctl

    # Step 5: Bootstrap cluster (talos) nodes
    bootstrap_cluster

    # Step 6: Setup kubeconfig for cluster access
    setup_kubectl

    # Step 7: Log cluster initial state and health
    log_info "Cluster health: endpoint: ${CLUSTER_ENDPOINT}"
    talosctl health --nodes ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config
    # kubectl get nodes -o wide

    # Step 8: Label worker nodes with node-role label
    kubectl label nodes -l 'node-role.kubernetes.io/control-plane!=' node-role.kubernetes.io/worker=

    # Step 9: Create 'security' namespace for cert manager
    log_info "Creating 'security' namespace"
    if ! resource_exists "namespace" "security"; then
        kubectl create namespace security --dry-run=client -o yaml | kubectl apply -f -
    fi

    # Step 10: Generate secrets to edit DNS zone file for DNS-01 challenges and for CSI provisioning
    log_info "Generating CCM API token secrets"
    kubectl create secret generic linode-credentials --namespace=security --from-literal=token=${CLOUD_PROVIDER_PAT} \
        --dry-run=client -o yaml | kubectl apply -f -
    kubectl create secret generic linode-token --namespace=kube-system \
        --from-literal=token=${CLOUD_PROVIDER_PAT} \
        --from-literal=region=${CLOUD_PROVIDER_REGION} \
        --dry-run=client -o yaml | kubectl apply -f -

    # Step 11: Deploy Linode CCM controller for provisioning CSI driver
    setup_ccm_controller

    # Step 12: Deploy Linode Blokstorage CSI driver
    setup_csi_driver

    # # Step 13: Bootstrap fluxCD for GitOps styled cluster resource management
    bootstrap_fluxcd

    # Step 14: Install Kubernetes Gateway API CRDs
    log_info "Applying kubernetes Gateway API: version: ${VERSION_GATEWAY_API}"
    kubectl apply -f ${K8S_GATEWAY_API}

    # Step 13: Deploy webhook plugin for cert-manager for linode DNS provider
    if ! resource_exists "deploy" "cert-manager-webhook-linode"; then

        if ! kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n security --timeout=300s; then
            log_error "fatal error: timeout waiting for cert-manager-webhook to be ready"
            exit 1
        fi

        helm install cert-manager-webhook-linode \
            --namespace=security \
            --set certManager.namespace=security \
            --set deployment.logLevel=null \
            ${CERT_MNG_PLUGIN}
    fi

    # Step 14: Install Nginx gateway as a passthrough TCP for cluster nodes
    setup_cluster_gateway

    # Success
    log_success "Bastion host and Cluster gateway setup completed successfully"
    log_section "Cluster setup completed: Endpoint: ${CLUSTER_ENDPOINT}"

    # Cleanup
    rm -rf kubectl.sha256
    rm -rf sha256sum.txt
    # rm -rf /tmp/talosconfig
    # rm -rf /tmp/devops_cd
}

# ------------------------------------------------------------------------------
# Execute main function
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# ------------------------------------------------------------------------------
