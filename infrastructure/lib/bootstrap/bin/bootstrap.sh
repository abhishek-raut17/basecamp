#!/usr/bin/env bash
#

# ------------------------------------------------------------------------------
# Bootstrap cluster nodes via talosctl
# ------------------------------------------------------------------------------
initialize_bootstrap() {
    local config="${1:-${TALOSCONFIG_PATH}}"
    local ip="${2:-${CONTROLPLANE_IP}}"

    log_info "Initializing cluster bootstrap"

    # add cluster subnet route
    add_subnet_route

    # copy config to TALOSCONFIG
    if ! copy "$config" "${TALOSCONFIG}"; then
        # if copy fails, run with default talosconfig
        bootstrap_cluster "$ip" "$config"
    else
        # if copy succeeds, run with env variable path TALOSCONFIG
        bootstrap_cluster "$ip"
    fi

    log_success "Cluster bootstrap process completed successfully"
    return 0
}

# ------------------------------------------------------------------------------
# Post bootstrap day-2 ops
# ------------------------------------------------------------------------------
post_bootstrap() {
    local ip="${1:-${CONTROLPLANE_IP}}"

    log_info "Executing post cluster initialization process (day-2 ops)"

    # Verify etcd is healthy and Running
    if ! wait_for_etcd "$ip" 30; then
        log_error "etcd could not be ready in time."
        return 1
    fi

    # Generate kubeconfig at KUBECONFIG
    generate_kubeconfig

    # Setup CNI
    setup_CNI
    sleep 20 # needed for crd to reconcile if slower machine

    # Bootstrap fluxcd
    bootstrap_fluxcd

    # Watch nodes via kubectl
    kube_watch "node" "ready" "default" 60

    log_success "Post cluster initialization process completed successfully"
    return 0
}

# ------------------------------------------------------------------------------
# Bootstrap cluster nodes via talosctl
# ------------------------------------------------------------------------------
bootstrap_cluster() {
    local ip="$1"
    local config="${2:-${TALOSCONFIG}}"

    log_debug "Boostrapping Talos cluster"

    if [ -z "$ip" ]; then
        log_error "Control plane IP addr not provided for bootstrap"
        return 1
    fi

    if is_etcd_running "$ip"; then
        log_info "Cluster is already bootstrapped"
        return 0
    else
        if exists "file" "$config"; then
            log_info "Bootstrapping cluster with controlplane: $ip"
            talosctl --nodes $ip --talosconfig $config bootstrap
        else
            log_error "Talosconfig not found at $config"
            return 1
        fi
    fi

    log_success "Cluster bootstrapped successfully"
    return 0
}

# ------------------------------------------------------------------------------
# Generate and export kubeconfig to KUBECONFIG
# ------------------------------------------------------------------------------
generate_kubeconfig() {
    local ip="${1:-${CONTROLPLANE_IP}}"
    local config="${2:-${TALOSCONFIG}}"
    local kubeconfig="${3:-${KUBECONFIG}}"

    log_info "Generating kubeconfig for kubectl"

    # Config talosctl endpoint if not present
    talosctl config endpoint "$ip"

    # Generate and copy kubeconfig to KUBECONFIG
    exists "file" "./kubeconfig" && rm kubeconfig 2>/dev/null
    talosctl --nodes "$ip" --talosconfig "$config" kubeconfig .

    cp kubeconfig "$kubeconfig" || {
        log_warn "Failed to copy kubeconfig from $(pwd) to $kubeconfig"
        return 1
    }

    log_success "Generated kubeconfig for kubectl"
}

# ------------------------------------------------------------------------------
# Setup CNI
# ------------------------------------------------------------------------------
setup_CNI() {
    local workers=${WORKERS}

    log_info "Setting up CNI Plugin: Calico"

    # label worker nodes for role
    label_workers $workers

    # Install Calico CNI plugin
    cni_plugin || {
        log_error "Error while installing CNI plugin"
        return 1
    }

    return 0
}

# ------------------------------------------------------------------------------
# Install CNI Plugin
# ------------------------------------------------------------------------------
cni_plugin() {
    local resource="${1:-${CNI_BASE_YAML}}"
    local config="${2:-${CUSTOMIZATION_DIR}/cni.config.yaml}"

    log_info "Installing component: CNI plugin"

    kubectl apply -f "$resource"
    sleep 20 # this is required in case the node is slow updating resources

    # Wait for initial installation
    kube_watch "crd" "established" "default" 60
    kube_watch "deployment" "available" "tigera-operator" 120

    kube_apply "$config"
    log_success "Installed component: CNI plugin successfully"

    return 0
}

# ------------------------------------------------------------------------------
# Bootstrap fluxcd
# ------------------------------------------------------------------------------
bootstrap_fluxcd() {
    local cluster="${1:-${CLUSTER_NAME}}"
    local user="${2:-${GIT_USER}}"
    local token="${3:-${GIT_PAT}}"

    log_debug "Bootstrap fluxCD"

    if [[ -z "$token" ]]; then
        log_error "No git PAT provided for fluxcd operations"
        return 1
    fi

    echo "$token" | flux bootstrap github \
        --token-auth \
        --owner="$user" \
        --repository="$cluster" \
        --branch=main \
        --path=clusters/"$cluster" \
        --personal

    log_success "Bootstrap: FluxCD component successfully"
    return 0
}

# ------------------------------------------------------------------------------
