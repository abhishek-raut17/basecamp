#!/usr/bin/env bash
#

# ------------------------------------------------------------------------------
# Create config and export path
# ------------------------------------------------------------------------------
provision_config() {
    local config="$1"
    local path="$2"

    log_info "Provisioning config $config at path $path"

    if [ -z "$config" ] || [ -z "$path" ]; then
        log_warn "Failed to provision $config at $path: missing parameter"
        return 1
    fi

    create_file "$path"
    export_variable "$config" "$path"

    log_success "Provisioned and exported $config successfully"
}

# ------------------------------------------------------------------------------
# Install prereq on bastion host to access and manage cluster
# ------------------------------------------------------------------------------
provision_prerequisites() {
    local talos_url="${1:-${TALOSCTL_URL}}"
    local kube_url="${2:-${KUBECTL_URL}}"
    local helm_url="${3:-${HELM_URL}}"
    local flux_url="${4:-${FLUXCD_URL}}"

    log_info "Provisioning prerequsities"

    # Install talosctl
    install_bin "talosctl-linux-amd64" "sha256sum.txt" "$talos_url"

    # Install kubectl
    install_bin "kubectl" "kubectl.sha256" "$kube_url"

    # Install Helm
    install_tool "helm" "$helm_url"

    # Install FluxCD
    install_tool "flux" "$flux_url"

    log_success "Provisioned prerequsities successfully"
    return 0
}

# ------------------------------------------------------------------------------
