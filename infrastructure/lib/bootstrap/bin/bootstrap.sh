#!/usr/bin/env bash
#

# ------------------------------------------------------------------------------
# Bootstrap cluster nodes via talosctl
# ------------------------------------------------------------------------------
initialize_bootstrap() {

    log_info "Initializing cluster bootstrap"

    # add cluster subnet route
    add_subnet_route "${CLUSTER_SUBNET}"

    # copy /tmp/talosconfig to TALOSCONFIG
    log_debug "Copying $TALOSCONFIG_PATH to $TALOSCONFIG"
    cp "${TALOSCONFIG_PATH}" "${TALOSCONFIG}" || {
        log_warn "Failed to copy talosconfig from $TALOSCONFIG_PATH to $TALOSCONFIG"
        return 1
    }

    # talosctl bootstrap
    bootstrap_cluster

    return 0
}

# ------------------------------------------------------------------------------
# Bootstrap cluster nodes via talosctl
# ------------------------------------------------------------------------------
bootstrap_cluster() {
    local ip="${CONTROLPLANE_IP}"
    local timeout=30

    log_debug "Boostrapping Talos cluster"

    if is_etcd_running "$ip"; then
        log_info "Cluster is already bootstrapped"
        return 0
    else
        log_info "Bootstrap cluster with controlplane: $ip"
        talosctl --nodes $ip bootstrap

        log_debug "Waiting for etcd to start. timeout: $timeout"
        watch_etcd "$ip" $timeout
    fi
}

# ------------------------------------------------------------------------------
# Post bootstrap day-2 ops
# ------------------------------------------------------------------------------
post_bootstrap() {
    # install fluxcd

    log_debug "Executing post cluster initialization process (day-2 ops)"

    # Verify etcd is healthy and Running
    if ! wait_for_etcd "${CONTROLPLANE_IP}" 30; then
        log_error "etcd could not be ready in time."
        return 1
    fi

    # Generate kubeconfig at KUBECONFIG
    setup_kubeconfig || return 1

    # Setup CNI
    setup_CNI || return 1

    # Bootstrap fluxcd
    boostrap_fluxcd || return 1

    # Watch nodes via kubectl
    kube_watch "node" "ready" "default" 60

    return 0
}

# ------------------------------------------------------------------------------
