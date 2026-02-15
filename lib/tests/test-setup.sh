#!/usr/bin/env bash
#
# Test suite for setup.sh
# Validates all machine configs are generated correctly
#
# Steps:
# 1. Check if talos secrets are generated at: ${TALOS_SECRETS_DIR}/secrets.yaml
# 2. Check if talos controlplane base machineconfigs are generated at: ${TALOS_SECRETS_DIR}/controlplane.yaml
# 3. Check if talos worker base machineconfigs are generated at: ${TALOS_SECRETS_DIR}/worker.yaml
# 4. Check if talos talosconfig is generated at: ${TALOS_SECRETS_DIR}/talosconfig
# 5. Check if talos patched files are available in $TALOS_DATA_DIR where $CONTROLPLANE_NODECOUNT and $WORKER_NODECOUNT
# derive the number of files in directory with pattern controlplane-{count}.machineconfig.yaml and worker-{count}.machineconfig.yaml

set -euo pipefail

# Source shared modules
source "$(dirname "$0")/../scripts/shared/logger.sh"

PROJECT_NAME="${PROJECT_NAME:-basecamp}"
CONTROLPLANE_NODECOUNT=${CONTROLPLANE_NODECOUNT:-1}
WORKER_NODECOUNT=${WORKER_NODECOUNT:-3}
DATA_DIR="${DATA_DIR:-$HOME/.local/share/$PROJECT_NAME}"
TALOS_DATA_DIR="${TALOS_DATA_DIR:-${DATA_DIR}/talos}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/$PROJECT_NAME}"
SECRETS_DIR="${SECRETS_DIR:-${CONFIG_DIR}/secrets}"
TALOS_SECRETS_DIR="${TALOS_SECRETS_DIR:-${SECRETS_DIR}/talos}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

trap 'log_fatal "test-setup failed' ERR

# Test 1: Check if talos secrets are generated
test_talos_secrets_generated() {
    if [[ ! -f "${TALOS_SECRETS_DIR}/secrets.yaml" ]]; then
        test_error "Talos secrets file not found at: ${TALOS_SECRETS_DIR}/secrets.yaml"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    if [[ ! -s "${TALOS_SECRETS_DIR}/secrets.yaml" ]]; then
        test_error "Talos secrets file is empty at: ${TALOS_SECRETS_DIR}/secrets.yaml"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    test_pass "Talos secrets file exists and contains data: ${TALOS_SECRETS_DIR}/secrets.yaml"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

# Test 2: Check if talos controlplane base machineconfig is generated
test_talos_controlplane_machineconfig() {
    if [[ ! -f "${TALOS_SECRETS_DIR}/controlplane.yaml" ]]; then
        test_error "Talos controlplane machineconfig not found at: ${TALOS_SECRETS_DIR}/controlplane.yaml"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    if [[ ! -s "${TALOS_SECRETS_DIR}/controlplane.yaml" ]]; then
        test_error "Talos controlplane machineconfig is empty at: ${TALOS_SECRETS_DIR}/controlplane.yaml"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    test_pass "Talos controlplane machineconfig exists: ${TALOS_SECRETS_DIR}/controlplane.yaml"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

# Test 3: Check if talos worker base machineconfig is generated
test_talos_worker_machineconfig() {
    if [[ ! -f "${TALOS_SECRETS_DIR}/worker.yaml" ]]; then
        test_error "Talos worker machineconfig not found at: ${TALOS_SECRETS_DIR}/worker.yaml"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    if [[ ! -s "${TALOS_SECRETS_DIR}/worker.yaml" ]]; then
        test_error "Talos worker machineconfig is empty at: ${TALOS_SECRETS_DIR}/worker.yaml"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    test_pass "Talos worker machineconfig exists: ${TALOS_SECRETS_DIR}/worker.yaml"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

# Test 4: Check if talos talosconfig is generated
test_talos_talosconfig() {
    if [[ ! -f "${TALOS_SECRETS_DIR}/talosconfig" ]]; then
        test_error "Talos talosconfig not found at: ${TALOS_SECRETS_DIR}/talosconfig"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    if [[ ! -s "${TALOS_SECRETS_DIR}/talosconfig" ]]; then
        test_error "Talos talosconfig is empty at: ${TALOS_SECRETS_DIR}/talosconfig"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    test_pass "Talos talosconfig exists: ${TALOS_SECRETS_DIR}/talosconfig"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

# Test 5: Check if controlplane machineconfig content matches between base and patched configs
test_talos_controlplane_content_match() {
    if [[ ! -f "${TALOS_SECRETS_DIR}/controlplane.yaml" ]]; then
        test_error "Base controlplane machineconfig not found at: ${TALOS_SECRETS_DIR}/controlplane.yaml"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    local base_cluster_id
    base_cluster_id=$(grep " id:" "${TALOS_SECRETS_DIR}/controlplane.yaml" | awk '{print $2}' | tr -d '\"')
    if [[ -z "${base_cluster_id}" ]]; then
        test_error "Could not extract cluster.id from base controlplane machineconfig"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    local content_mismatch=0
    for ((i=0; i<${CONTROLPLANE_NODECOUNT}; i++)); do
        if [[ ! -f "${TALOS_DATA_DIR}/controlplane-${i}.machineconfig.yaml" ]]; then
            test_warn "Controlplane patched config not found at: ${TALOS_DATA_DIR}/controlplane-${i}.machineconfig.yaml"
            TESTS_WARNED=$((TESTS_WARNED + 1))
            content_mismatch=$((content_mismatch + 1))
            continue
        fi
        
        local patched_cluster_id
        patched_cluster_id=$(grep " id:" "${TALOS_DATA_DIR}/controlplane-${i}.machineconfig.yaml" | awk '{print $2}' | tr -d '\"')
        
        if [[ "${base_cluster_id}" != "${patched_cluster_id}" ]]; then
            test_error "Controlplane-${i} cluster.id mismatch. Base: ${base_cluster_id}, Patched: ${patched_cluster_id}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            content_mismatch=$((content_mismatch + 1))
        fi
    done
    
    if [[ ${content_mismatch} -eq 0 ]]; then
        test_pass "All generated controlplane machineconfigs have matching cluster.id: ${base_cluster_id}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
}

# Test 6: Check if worker machineconfig content matches between base and patched configs
test_talos_worker_content_match() {
    if [[ ! -f "${TALOS_SECRETS_DIR}/worker.yaml" ]]; then
        test_error "Base worker machineconfig not found at: ${TALOS_SECRETS_DIR}/worker.yaml"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    local base_cluster_id
    base_cluster_id=$(grep " id:" "${TALOS_SECRETS_DIR}/worker.yaml" | awk '{print $2}' | tr -d '\"')
    
    if [[ -z "${base_cluster_id}" ]]; then
        test_error "Could not extract cluster.id from base worker machineconfig"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    local content_mismatch=0
    for ((i=0; i<${WORKER_NODECOUNT}; i++)); do
        if [[ ! -f "${TALOS_DATA_DIR}/worker-${i}.machineconfig.yaml" ]]; then
            test_warn "Worker patched config not found at: ${TALOS_DATA_DIR}/worker-${i}.machineconfig.yaml"
            TESTS_WARNED=$((TESTS_WARNED + 1))
            content_mismatch=$((content_mismatch + 1))
            continue
        fi
        
        local patched_cluster_id
        patched_cluster_id=$(grep " id:" "${TALOS_DATA_DIR}/worker-${i}.machineconfig.yaml" | awk '{print $2}' | tr -d '\"')
        
        if [[ "${base_cluster_id}" != "${patched_cluster_id}" ]]; then
            test_error "Worker-${i} cluster.id mismatch. Base: ${base_cluster_id}, Patched: ${patched_cluster_id}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            content_mismatch=$((content_mismatch + 1))
        fi
    done
    
    if [[ ${content_mismatch} -eq 0 ]]; then
        test_pass "All generated worker machineconfigs have matching cluster.id: ${base_cluster_id}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
}

# Run all tests
run_all_tests() {
    test_mark "Starting setup validation tests..."
    echo ""

    test_talos_secrets_generated || return  1
    test_talos_controlplane_machineconfig || return  1
    test_talos_worker_machineconfig || return  1
    test_talos_talosconfig || return  1
    test_talos_controlplane_content_match || return 1
    test_talos_worker_content_match || return  1

    echo ""
    log_info "Test Results: Passed: ${TESTS_PASSED}, Warned: ${TESTS_WARNED}, Failed: ${TESTS_FAILED}"

    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        return 1
    fi

    return 0
}

run_all_tests