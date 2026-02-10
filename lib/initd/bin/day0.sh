#!/usr/bin/env bash
#
# Day0: Deploy operators, networking, storage, and services (Steps 7-16)
#
# Step 7:  Verify cluster health and status
# Step 8:  Label worker nodes
# Step 9:  Create required namespaces
# Step 10: Apply Kubernetes CRDs (SealedSecrets, Gateway API)
# Step 11: Generate and seal Kubernetes secrets
# Step 12: Deploy Linode CCM controller
# Step 13: Deploy Linode BlockStorage CSI driver
# Step 14: Bootstrap FluxCD for GitOps
# Step 15: Deploy cert-manager webhook plugin for Linode DNS
# Step 16: Setup Nginx gateway as TCP passthrough
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
: "${VERSION_CRT_MNG_PLUGIN:?VERSION_CRT_MNG_PLUGIN not set}"
: "${CERT_MNG_PLUGIN:?CERT_MNG_PLUGIN not set}"
: "${NGINX_DIR:?NGINX_DIR not set}"
: "${NGINX_CONF:?NGINX_CONF not set}"
: "${NGINX_TUNING_CONF:?NGINX_TUNING_CONF not set}"
: "${CLUSTER_NAME:?CLUSTER_NAME not set}"
: "${CLUSTER_ENDPOINT:?CLUSTER_ENDPOINT not set}"

# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "${SCRIPT_DIR}/shared/logger.sh"
source "${SCRIPT_DIR}/shared/utils.sh"

# ===============================================================================
# Step 7: Log cluster initial state and health
# ===============================================================================
verify_cluster_health() {
    log_info "Verifying cluster health: endpoint: ${CLUSTER_ENDPOINT}"
    if ! talosctl health --nodes ${CLUSTER_ENDPOINT} --talosconfig ${TALOS_DIR}/config; then
        log_warn "Cluster health check returned warnings"
    else
        log_success "Cluster health verified"
    fi
}

# ===============================================================================
# Step 8: Label worker nodes with node-role label
# ===============================================================================
label_worker_nodes() {
    log_info "Labeling worker nodes with node-role.kubernetes.io/worker"
    kubectl label nodes -l 'node-role.kubernetes.io/control-plane!=' node-role.kubernetes.io/worker=
    log_success "Worker nodes labeled successfully"
}

# ===============================================================================
# Step 9: Create Kubernetes namespace
# ===============================================================================
create_namespace() {
    local namespace="$1"

    log_info "Creating namespace: ${namespace}"
    if ! resource_exists "namespace" "${namespace}"; then
        kubectl create namespace "${namespace}" --dry-run=client -o yaml | kubectl apply -f -
        log_debug "Namespace created: ${namespace}"
    else
        log_info "Namespace already exists: ${namespace}"
    fi
}

# ===============================================================================
# Create Kubernetes secrets with dynamic literals
# ===============================================================================
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

# ===============================================================================
# Create and seal Kubernetes secrets with kubeseal
# ===============================================================================
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
        log_error "kubeseal command not found. Please run 'make prereq' first."
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

# ===============================================================================
# Step 12: Setup Lindoe Cloud controller manager for provisioning CSI driver
# ===============================================================================
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

    log_success "Linode CCM controller deployed successfully"
}

# ===============================================================================
# Step 13: Setup Lindoe block storage driver to manage CSI for cluster
# ===============================================================================
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

    log_success "Linode CSI driver deployed successfully"
}

# ===============================================================================
# Step 14: Bootstrap fluxCD for GitOps
# ===============================================================================
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

        log_success "FluxCD bootstrapped successfully"
    else
        log_warn "flux CLI not found, skipping FluxCD bootstrap"
    fi
}

# ===============================================================================
# Step 15: Setup kubernetes resource: Cert-Manager-Webhook (for Linode)
# ===============================================================================
setup_cert_manager() {
    if ! resource_exists "deploy" "cert-manager-webhook" "security"; then

        # CRITICAL: cert-manager-webhook needs to be running before installing cert-manager-webhook-linode
        if ! kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n security --timeout=600s; then
            log_error "fatal error: timeout waiting for cert-manager-webhook to be ready"
            exit 1
        fi

        helm install cert-manager-webhook-linode \
            --namespace=security \
            --set certManager.namespace=security \
            --set deployment.logLevel=null \
            ${CERT_MNG_PLUGIN}

        log_success "Cert-manager webhook for Linode DNS deployed successfully"
    else
        log_info "Cert-manager webhook already deployed"
    fi
}

# ===============================================================================
# Step 16: Setup Nginx gateway as TCP passthrough for cluster nodes
# ===============================================================================
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
        log_success "Nginx is running successfully!"
    else
        log_error "Nginx failed to start. Checking status..."
        systemctl status nginx
        exit 1
    fi
}

# ===============================================================================
# Main function
# ===============================================================================
main() {
    # Setup error handling
    trap cleanup_on_error EXIT ERR INT TERM

    # Display banner
    log_section "Day0: Deploy operators, networking, storage, and services"
    log_info "Release version   : ${RELEASE_VERSION}"
    log_info "Binary version    : ${VERSION}"
    log_info "Cluster endpoint  : ${CLUSTER_ENDPOINT}"
    log_info "Cluster name      : ${CLUSTER_NAME}"
    echo ""

    # Verify kubectl is available
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl not found. Please run 'make bootstrap' first"
        exit 1
    fi

    # Verify kubeconfig exists
    if [[ ! -f "${KUBE_DIR}/config" ]]; then
        log_error "Kubeconfig not found at ${KUBE_DIR}/config. Please run 'make bootstrap' first"
        exit 1
    fi

    # Step 7: Verify cluster health
    log_section "Step 1/9: Verify cluster health and status"
    verify_cluster_health
    log_success "Step 1 completed: Cluster health verified"
    echo ""

    # Step 8: Label worker nodes
    log_section "Step 2/9: Label worker nodes"
    label_worker_nodes
    log_success "Step 2 completed: Worker nodes labeled"
    echo ""

    # Step 9: Create required namespaces
    log_section "Step 3/9: Create required namespaces"
    create_namespace "security"
    create_namespace "persistence"
    create_namespace "ingress"
    create_namespace "dashboard"
    log_success "Step 3 completed: Namespaces created"
    echo ""

    # Step 11: Generate secrets
    log_section "Step 4/9: Generate and seal Kubernetes secrets"
    log_info "Generating secrets for cloud provider and DNS challenges"
    create_k8s_secret "security" "linode-credentials" "token=${CLOUD_PROVIDER_PAT}"
    create_k8s_secret "kube-system" "ccm-token" "token=${CLOUD_PROVIDER_PAT}" "region=${CLOUD_PROVIDER_REGION}"
    log_success "Step 4 completed: Secrets created and sealed"
    echo ""

    # Step 12: Deploy Linode CCM controller
    log_section "Step 5/9: Deploy Linode CCM controller"
    setup_ccm_controller
    log_success "Step 5 completed: Linode CCM deployed"
    echo ""

    # Step 13: Deploy Linode CSI driver
    log_section "Step 6/9: Deploy Linode BlockStorage CSI driver"
    setup_csi_driver
    log_success "Step 6 completed: Linode CSI deployed"
    echo ""

    # Step 14: Bootstrap FluxCD
    log_section "Step 7/9: Bootstrap FluxCD for GitOps"
    bootstrap_fluxcd

    # Sleeping to give flux time to reconcile
    log_debug "Sleeping for 30s to give flux time to reconcile"
    sleep 30
    log_success "Step 7 completed: FluxCD bootstrapped"
    echo ""

    # Step 15: Deploy cert-manager webhook
    log_section "Step 8/9: Deploy cert-manager webhook for Linode DNS"
    setup_cert_manager
    log_success "Step 8 completed: Cert-manager webhook deployed"
    echo ""

    # Step 16: Setup Nginx gateway
    log_section "Step 9/9: Setup Nginx gateway as TCP passthrough"
    setup_public_gateway
    log_success "Step 9 completed: Nginx gateway configured"
    echo ""

    # Success
    log_success "Day0 setup completed successfully"
    log_section "Cluster initialization complete!"
    log_info "Cluster name      : ${CLUSTER_NAME}"
    log_info "Cluster endpoint  : ${CLUSTER_ENDPOINT}"
    log_success "Your cluster is now ready for workload deployment"
}

# ===============================================================================
# Execute main function
# ===============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
# ===============================================================================
