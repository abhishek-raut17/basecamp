#!/usr/bin/env bash
#
# Run: Main cluster initialization and setup script
#
set -euo pipefail

declare -r INITD="/usr/local/lib/initd"

# Configuration variables are expected to be set by pre-init.sh
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
: "${DB_ADMIN_PASS:?DB_ADMIN_PASS not set}"

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
    install -m 755 kubeseal /usr/local/bin/kubeseal

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

    if ! resource_exists "ds" "ccm-linode" "kube-system"; then

        log_debug "Installing ccm-linode controller"
        helm install ccm-linode ccm-linode/ccm-linode \
            --namespace kube-system \
            --set secretRef.name=ccm-token \
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

    if ! resource_exists "ds" "csi-linode-node" "kube-system"; then

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
# Setup kubernetes resource: Gateway API
# ----------------------------------------------------------------------------
setup_public_gateway() {
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
# Setup kubernetes resource: Cert-Manager-Webhook (for Linode)
# ----------------------------------------------------------------------------
setup_cert_manager() {
    if ! resource_exists "deploy" "cert-manager-webhook" "security"; then

        helm install cert-manager-webhook-linode \
            --namespace=security \
            --set certManager.namespace=security \
            --set deployment.logLevel=null \
            ${CERT_MNG_PLUGIN}
    fi

    if ! kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n security --timeout=300s; then
        log_error "fatal error: timeout waiting for cert-manager-webhook to be ready"
        exit 1
    fi
}

# -------------------------------------------------------------------------------
# Create and seal Kubernetes secrets with kubeseal
# -------------------------------------------------------------------------------
seal_k8s_secret() {
    local namespace="$1"
    local secret_name="$2"

    if ! kubectl wait --for=condition=ready pod -l name=sealed-secrets-controller -n kube-system --timeout=300s; then
        log_error "fatal error: timeout waiting for sealed-secrets-controller to be ready"
        exit 1
    fi

    if [[ -z "$namespace" ]] || [[ -z "$secret_name" ]]; then
        log_error "seal_k8s_secret: namespace and secret_name are required"
        return 1
    fi

    log_info "Sealing Kubernetes secret: ${secret_name} in namespace: ${namespace}"

    # Check if secret exists
    if ! kubectl get secret "${secret_name}" -n "${namespace}" &>/dev/null; then
        log_error "Secret ${secret_name} not found in namespace ${namespace}"
        return 1
    fi

    # Check if kubeseal is available
    if ! command -v kubeseal &>/dev/null; then
        log_error "kubeseal command not found. Please install kubeseal first."
        return 1
    fi

    local sealed_secret_file="/tmp/${secret_name}-sealed.yaml"

    # Export the unsealed secret and seal it
    kubectl get secret "${secret_name}" -n "${namespace}" -o yaml | \
        kubeseal -n "${namespace}" -o yaml > "${sealed_secret_file}"

    if [[ ! -f "${sealed_secret_file}" ]]; then
        log_error "Failed to seal secret ${secret_name}"
        return 1
    fi

    log_debug "Sealed secret saved to: ${sealed_secret_file}"

    # Delete the unsealed secret
    log_debug "Deleting unsealed secret: ${secret_name}"
    kubectl delete secret "${secret_name}" -n "${namespace}" 2>/dev/null || true

    # Apply the sealed secret
    log_debug "Applying sealed secret"
    kubectl apply -f "${sealed_secret_file}"

    # Clean up temporary file
    rm -f "${sealed_secret_file}"

    log_success "Secret ${secret_name} sealed and deployed successfully"
}

# -------------------------------------------------------------------------------
# Create Kubernetes secrets with dynamic literals
# -------------------------------------------------------------------------------
create_k8s_secret() {
    local namespace="$1"
    local secret_name="$2"
    shift 2
    local literals=("$@")

    if [[ -z "$namespace" ]] || [[ -z "$secret_name" ]]; then
        log_error "create_k8s_secret: namespace and secret_name are required"
        return 1
    fi

    if [[ ${#literals[@]} -eq 0 ]]; then
        log_error "create_k8s_secret: at least one literal key=value pair is required"
        return 1
    fi

    log_debug "Creating Kubernetes secret: ${secret_name} in namespace: ${namespace}"

    local cmd="kubectl create secret generic ${secret_name} --namespace=${namespace}"

    # Add all literal key=value pairs
    for literal in "${literals[@]}"; do
        cmd+=" --from-literal=${literal}"
    done

    # Add dry-run and apply
    cmd+=" --dry-run=client -o yaml | kubectl apply -f -"

    eval "$cmd"

    seal_k8s_secret "${namespace}" "${secret_name}"
}

# -------------------------------------------------------------------------------
# Create Kubernetes namespace
# -------------------------------------------------------------------------------
create_namespace() {
    local namespace="$1"

    log_info "Creating namespace: ${namespace}"
    if ! resource_exists "namespace" "${namespace}"; then
        kubectl create namespace "${namespace}" --dry-run=client -o yaml | kubectl apply -f -
    else
        log_info "Namespace: ${namespace} already exists"
    fi
}

# -------------------------------------------------------------------------------
# Argument parsing and validation functions are handled by init.sh
# This script should only be called after init.sh has validated config
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Main function
# -------------------------------------------------------------------------------
main() {
    # Setup error handling
    trap cleanup_on_error EXIT ERR INT TERM

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

    # Step 9: Create required namespaces
    create_namespace "security"
    create_namespace "persistence"
    create_namespace "ingress"
    create_namespace "dashboard"

    # Step 10: Deploying custom CRDs
    #   1: Deploy SealedSecret CRDs and sealed-secret-controller in kube-system
    log_info "Applying kubernetes sealed-secrets controller: version: ${VERSION_KUBESEAL}"
    kubectl apply -f ${KUBESEAL_CONTOLLER_URL}
    #   2: Install Kubernetes Gateway API CRDs
    log_info "Applying kubernetes Gateway API: version: ${VERSION_GATEWAY_API}"
    kubectl apply -f ${K8S_GATEWAY_API}

    # Step 11: Generate secrets to:
    #   1: Edit DNS zone file for DNS-01 challenges
    #   2: CSI provisioning
    #   3: Postgres secrets (sealed)
    log_info "Generating secrets"
    create_k8s_secret "security" "linode-credentials" "token=${CLOUD_PROVIDER_PAT}"
    create_k8s_secret "kube-system" "ccm-token" "token=${CLOUD_PROVIDER_PAT}" "region=${CLOUD_PROVIDER_REGION}"
    create_k8s_secret "persistence" "postgres-admin-secrets" "postgres-password=${DB_ADMIN_PASS}" "password=" "replication-password=${DB_ADMIN_PASS}"    

    # Step 12: Deploy Linode CCM controller for provisioning CSI driver
    setup_ccm_controller

    # Step 13: Deploy Linode Blokstorage CSI driver
    setup_csi_driver

    # # Step 14: Bootstrap fluxCD for GitOps styled cluster resource management
    bootstrap_fluxcd

    # Step 15: Deploy webhook plugin for cert-manager for linode DNS provider (post fluxcd)
    setup_cert_manager

    # Step 16: Install Nginx gateway as a passthrough TCP for cluster nodes
    setup_public_gateway

    # Success
    log_success "Bastion host and Cluster gateway setup completed successfully"
    log_section "Cluster setup completed: Endpoint: ${CLUSTER_ENDPOINT}"

    # Cleanup
    rm -rf kubectl.sha256
    rm -rf sha256sum.txt
    # rm -rf /tmp/talosconfig
    # rm -rf /tmp/devops_cd
}

# -------------------------------------------------------------------------------
# Execute main function
# -------------------------------------------------------------------------------
# This script should be called via init.sh which handles argument parsing
# and environment configuration validation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
# -------------------------------------------------------------------------------
