#!/usr/bin/env bash
#
# Usage: 
#   setup - Generates machine configs for cluster node bootstrap
#
# ------------------------------------------------------------------------------

set -euo pipefail
# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "$(dirname "$0")/shared/logger.sh"
source "$(dirname "$0")/shared/utils.sh"

trap 'log_fatal "setup target failed at line $LINENO"' ERR

PROJECT_NAME="${PROJECT_NAME:-basecamp}"
CLUSTER_IP="${CLUSTER_IP:-10.5.0.10}"
CONTROLPLANE_NODECOUNT=${CONTROLPLANE_NODECOUNT:-1}
WORKER_NODECOUNT=${WORKER_NODECOUNT:-3}
DATA_DIR="${DATA_DIR:-$HOME/.local/share/$PROJECT_NAME}"
TALOS_DATA_DIR="${TALOS_DATA_DIR:-${DATA_DIR}/talos}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/$PROJECT_NAME}"
SECRETS_DIR="${SECRETS_DIR:-${CONFIG_DIR}/secrets}"
TALOS_SECRETS_DIR="${TALOS_SECRETS_DIR:-${SECRETS_DIR}/talos}"
MANIFEST_LIB="${MANIFEST_LIB:-${ROOT_DIR}/manifests}"
PATCH_MACHINECONF_LIB="${PATCH_MACHINECONF_LIB:-${MANIFEST_LIB}/patches}"
CNI_MANIFEST="${CNI_MANIFEST:-${MANIFEST_LIB}/static/cni/custom.cni.yaml}"

generate_talos_secret() {
    if [[ ! -d "$(dirname "${TALOS_SECRETS_DIR}/secrets.yaml")" ]]; then
        install_dir "$(dirname "${TALOS_SECRETS_DIR}/secrets.yaml")"
    fi

    if [[ ! -f "${TALOS_SECRETS_DIR}/secrets.yaml" ]]; then
        log_debug "Generating secrets for talosctl machineconfig at: ${TALOS_SECRETS_DIR}/secrets.yaml"
        talosctl gen secrets --force -o "${TALOS_SECRETS_DIR}/secrets.yaml"
    else
        log_debug "Secrets already exists at: ${TALOS_SECRETS_DIR}/secrets.yaml"
    fi
}

generate_talos_machineconf() {
    if [[ ! -f "${TALOS_SECRETS_DIR}/talosconfig" ]] || [[ ! -f "${TALOS_SECRETS_DIR}/controlplane.yaml" ]]; then
        log_debug "Generating base machineconfigs for cluster: ${PROJECT_NAME}-cluster at: ${TALOS_SECRETS_DIR}"

        # generate base machineconfig
        talosctl gen config ${PROJECT_NAME}-cluster https://${CLUSTER_IP}:6443 \
            --output-dir "${TALOS_SECRETS_DIR}" \
            --with-secrets "${TALOS_SECRETS_DIR}/secrets.yaml" \
            --with-examples=false \
            --with-docs=false \
            --force || return 1

        # update talosconfig with cluster endpoint
        talosctl config endpoint ${CLUSTER_IP} --talosconfig=${TALOS_SECRETS_DIR}/talosconfig || return 1
    else
        log_debug "Machine configs already exists at: ${TALOS_SECRETS_DIR}"
    fi
}

patch_talos_machineconf() {

    # check if data dir exists to copy derived patches
    if [[ ! -d "${TALOS_DATA_DIR}" ]]; then
        install_dir "${TALOS_DATA_DIR}"
    fi

    # check if base machineconfigs exists
    if [[ ! -f "${TALOS_SECRETS_DIR}/controlplane.yaml" ]] && [[ ! -f "${TALOS_SECRETS_DIR}/worker.yaml" ]]; then
        log_error "No base machineconfigs found for controlplane and worker nodes at: ${TALOS_SECRETS_DIR}"
        return 1
    fi

    # check if patch machineconfigs exists
    if [[ ! -f "${PATCH_MACHINECONF_LIB}/cp.machineconfig.yaml" ]] && [[ ! -f "${PATCH_MACHINECONF_LIB}/wrk.machineconfig.yaml" ]]; then
        log_error "Error: no patch configs found for patching at: ${PATCH_MACHINECONF_LIB}"
        return 1
    fi

    log_debug "Generating derived machineconfigs for cluster: ${PROJECT_NAME}-cluster at: ${TALOS_DATA_DIR}"

    # Generate patched machineconfig per controlplane node
    log_debug "Patching machineconfig for controlplane"
    for ((i=0; i<${CONTROLPLANE_NODECOUNT}; i++)); do
        talosctl machineconfig patch "${TALOS_SECRETS_DIR}/controlplane.yaml" \
            --patch @"${PATCH_MACHINECONF_LIB}/cp.machineconfig.yaml" \
            --patch '[{"op": "replace", "path": "/machine/network/hostname", "value": "'${PROJECT_NAME}'-controlplane-'${i}'"}]' \
            --output "${TALOS_DATA_DIR}/controlplane-${i}.machineconfig.yaml" || return 1
    done

    # Generate patched machineconfig per worker node
    log_debug "Patching machineconfig for worker"
    for ((i=0; i<${WORKER_NODECOUNT}; i++)); do
        talosctl machineconfig patch "${TALOS_SECRETS_DIR}/worker.yaml" \
            --patch @"${PATCH_MACHINECONF_LIB}/wkr.machineconfig.yaml" \
            --patch '[{"op": "replace", "path": "/machine/network/hostname", "value": "'${PROJECT_NAME}'-worker-'${i}'"}]' \
            --output "${TALOS_DATA_DIR}/worker-${i}.machineconfig.yaml" || return 1
    done
}

setup() {
    log_mark "Generating required machine configs for cluster node bootstrap"
    
    # Check if CNI manifest is available
    log_debug "Checking static manifests for CNI plugin at: ${CNI_MANIFEST}"
    if [[ ! -f "${CNI_MANIFEST}" ]]; then
        log_error "Error: cannot find default CNI manifest at: ${CNI_MANIFEST}"
        return 1
    fi

    # Generate secret.yaml for generating and configuring talos machine configs
    generate_talos_secret || return 1

    # Generate machine configs with secrets
    generate_talos_machineconf || return 1

    # Patch machine configs
    patch_talos_machineconf || return 1

    log_success "All required machine configs for cluster node bootstrap generated sucessfully"
}

setup
# ------------------------------------------------------------------------------
