#!/usr/bin/env bash
#
# Cluster lib: prep file for preparing cloud-init machineconfigs for nodes
#
set -euo pipefail

# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "${SHARED_LIB}/bin/logger.sh"
source "${SHARED_LIB}/bin/utils.sh"

# ------------------------------------------------------------------------------
# Default configuration
# ------------------------------------------------------------------------------
declare -r VERSION="v1.0.0"


# ------------------------------------------------------------------------------
# Validate CNI manifests
# ------------------------------------------------------------------------------
check_cni_manifest() {
    local manifest_path="${1:-${MANIFEST_LIB:-}}/static/cni/custom.cni.yaml"

    log_info "Checking static manifests for CNI plugin at $(basename $manifest_path)"

    # Check if custom resource manifest exists
    if ! exists "file" "$manifest_path"; then
        log_error "No manifest for CNI plugin exists. Please provide one in 
        manifests before proceeding"
        return 1
    fi
}

generate_machine_conf() {
    local generated_dir="${MANIFEST_LIB:-}/generated"
    local patches_dir="${MANIFEST_LIB:-}/patches"
    local project_name="${1:-${PROJECT_NAME:-basecamp}}"
    local cluster_ip="${2:-${CLUSTER_ENDPOINT:-10.0.10.10}}"

    log_info "Generating machine configs for talos nodes"

    # Check if patches are available (critical)
    if ! exists "dir" "$patches_dir"; then
        log_error "No template patch directory found. Please ensure it at $patches_dir"
        return 1
    fi

    # Check if generated directory is available, create if not
    if ! exists "dir" "$generated_dir"; then
        log_warn "No generated directory found in manifests. Generating now"
        create_dir "$generated_dir"
    fi

    talosctl gen secrets --force -o "$generated_dir/secrets.yaml"
    talosctl gen config ${project_name}-cluster https://${cluster_ip}:6443 \
        --output-dir "$generated_dir" \
        --with-secrets "$generated_dir/secrets.yaml" \
        --with-examples=false \
        --with-docs=false \
        --force

    talosctl config endpoint ${cluster_ip} --talosconfig=${generated_dir}/talosconfig
    talosctl config merge ${generated_dir}/talosconfig
}

patch_machine_conf() {
    local machineconfig_dir="${MANIFEST_LIB:-}/machineconfig"
    local generated_dir="${MANIFEST_LIB:-}/generated"
    local patches_dir="${MANIFEST_LIB:-}/patches"

    log_info "Patching machine configs for talos nodes"

    # Check if machineconfig dir exists
    if ! exists "dir" "$machineconfig_dir"; then
        log_warn "No machineconfig directory found in manifests. Generating now"
        create_dir "$machineconfig_dir"
    fi

    # Patch controlplane machineconfig
    log_debug "Patching machineconfig for controlplane"
    talosctl machineconfig patch "${generated_dir}/controlplane.yaml" \
        --patch @"${patches_dir}/cp.machineconfig.yaml" \
        --patch @"${patches_dir}/cni.secret.yaml" \
        --output "${machineconfig_dir}/controlplane.machineconfig.yaml"

    # Patch worker node machineconfig
    log_debug "Patching machineconfig for worker node"
    talosctl machineconfig patch "${generated_dir}/worker.yaml" \
        --patch @"${patches_dir}/wkr.machineconfig.yaml" \
        --output "${machineconfig_dir}/wkr.machineconfig.yaml"
}

# ------------------------------------------------------------------------------
# Main function
# ------------------------------------------------------------------------------
main() {

    # Setup error handling
    trap cleanup_on_error EXIT ERR INT TERM

    # Display banner
    log_section "Setup machine configs for cluster nodes"
    log_info "Release version   : ${RELEASE_VERSION}"
    log_info "Binary version    : ${VERSION}"
    echo ""

    # Validate if CNI manifest is present (required in case of Cilium CNI)
    check_cni_manifest

    # Generate talosctl default machineconfigs with secrets
    generate_machine_conf

    # Patch machineconfigs for controlplane and worker nodes
    patch_machine_conf

    # Success
    log_success "Machine configs generated for cluster nodes init process"
    log_section "All Setup tasks completed"
}

# ------------------------------------------------------------------------------
# Execute main function
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# ------------------------------------------------------------------------------
