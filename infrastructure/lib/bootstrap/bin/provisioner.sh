#!/usr/bin/env bash
#

# ------------------------------------------------------------------------------
# Create config and export path
# ------------------------------------------------------------------------------
provision_config() {
    local config="$1"
    local path="$2"

    log_debug "Provisioning config $config at path $path"

    create_file "$path"
    export_variable "$config" "$path"

    log_success "Provisioned and exported $config successfully"
}

# ------------------------------------------------------------------------------
# Install prereq on bastion host to access and manage cluster
# ------------------------------------------------------------------------------
install_prerequisites() {

    log_debug "Provisioning prerequsities"

    # Install talosctl
    install_tool "talosctl-linux-amd64" "sha256sum.txt" "${TALOSCTL_URL}" || return 1

    # Install kubectl
    install_tool "kubectl" "kubectl.sha256" "${KUBECTL_URL}" || return 1

    # Install Helm
    install_helm "${HELM_URL}" || return 1

    return 0
}

# ------------------------------------------------------------------------------
