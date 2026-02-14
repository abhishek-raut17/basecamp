#!/usr/bin/env bash
#
# Test suite for prereq.sh
# Validates all prerequisites are installed correctly
#
# Steps:
# 1. Check if INSTALL_BIN_DIR is installed and in PATH
# 2. Check if $DATA_DIR/state/terraform is installed
# 3. Check if $DATA_DIR/var/terraform is installed
# 4. Check if $DATA_DIR/manifest/machineconfigs is installed
# 5. Check if $CONFIG_DIR/secrets is installed
# 6. Check if terraform is installed in $INSTALL_BIN_DIR and in $PATH
# 7. Check if terraform is of required version
# 8. Check if talosctl is installed in $INSTALL_BIN_DIR and in $PATH
# 9. Check if talosctl is of required version

set -euo pipefail

# Source shared modules
source "$(dirname "$0")/../scripts/shared/logger.sh"

PROJECT_NAME="${PROJECT_NAME:-basecamp}"
VERSION_TALOSCTL=${VERSION_TALOSCTL:-v1.11.2}
VERSION_TERRAFORM=${VERSION_TERRAFORM:-v1.14.5}
INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-$HOME/.local/bin}"
DATA_DIR="${DATA_DIR:-$HOME/.local/share/$PROJECT_NAME}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/$PROJECT_NAME}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

trap 'log_fatal "test-prereq test target failed' ERR

# Test 1: Check if INSTALL_BIN_DIR exists and is in PATH
test_install_bin_dir() {    
    if [[ ! -d "${INSTALL_BIN_DIR}" ]]; then
        test_error "INSTALL_BIN_DIR does not exist: ${INSTALL_BIN_DIR}"
        TESTS_FAILED=$((TESTS_FAILED + 1)) 
        return 1
    fi
    
    if ! echo "$PATH" | grep -q "$INSTALL_BIN_DIR"; then
        test_error "INSTALL_BIN_DIR not in PATH: ${INSTALL_BIN_DIR}"
        TESTS_FAILED=$((TESTS_FAILED + 1)) 
        return 1
    fi
    
    test_pass "INSTALL_BIN_DIR exists and in PATH: ${INSTALL_BIN_DIR}"
    TESTS_PASSED=$((TESTS_PASSED + 1)) 
}

# Test 2: Check if DATA_DIR/state/terraform exists
test_data_dir_state_terraform() {    
    if [[ ! -d "${DATA_DIR}/state/terraform" ]]; then
        test_error "DATA_DIR/state/terraform does not exist: ${DATA_DIR}/state/terraform"
        TESTS_FAILED=$((TESTS_FAILED + 1)) 
        return 1
    fi
    
    test_pass "DATA_DIR/state/terraform exists: ${DATA_DIR}/state/terraform"
    TESTS_PASSED=$((TESTS_PASSED + 1)) 
}

# Test 3: Check if DATA_DIR/var/terraform exists
test_data_dir_var_terraform() {    
    if [[ ! -d "${DATA_DIR}/var/terraform" ]]; then
        test_error "DATA_DIR/var/terraform does not exist: ${DATA_DIR}/var/terraform"
        TESTS_FAILED=$((TESTS_FAILED + 1)) 
        return 1
    fi
    
    test_pass "DATA_DIR/var/terraform exists: ${DATA_DIR}/var/terraform"
    TESTS_PASSED=$((TESTS_PASSED + 1)) 
}

# Test 4: Check if DATA_DIR/manifest/machineconfigs exists
test_data_dir_machineconfigs() {    
    if [[ ! -d "${DATA_DIR}/manifest/machineconfigs" ]]; then
        test_error "DATA_DIR/manifest/machineconfigs does not exist: ${DATA_DIR}/manifest/machineconfigs"
        TESTS_FAILED=$((TESTS_FAILED + 1)) 
        return 1
    fi
    
    test_pass "DATA_DIR/manifest/machineconfigs exists: ${DATA_DIR}/manifest/machineconfigs"
    TESTS_PASSED=$((TESTS_PASSED + 1)) 
}

# Test 5: Check if CONFIG_DIR/secrets exists
test_config_dir_secrets() {    
    if [[ ! -d "${CONFIG_DIR}/secrets" ]]; then
        test_error "CONFIG_DIR/secrets does not exist: ${CONFIG_DIR}/secrets"
        TESTS_FAILED=$((TESTS_FAILED + 1)) 
        return 1
    fi
    
    test_pass "CONFIG_DIR/secrets exists: ${CONFIG_DIR}/secrets"
    TESTS_PASSED=$((TESTS_PASSED + 1)) 
}

# Test 6: Check if terraform is installed
test_terraform_installed() {    
    if ! command -v terraform >/dev/null 2>&1; then
        test_error "terraform is not installed or not in PATH"
        TESTS_FAILED=$((TESTS_FAILED + 1)) 
        return 1
    fi
    
    local terraform_path
    terraform_path="$(which terraform)"
    test_pass "terraform is installed at: ${terraform_path}"
    TESTS_PASSED=$((TESTS_PASSED + 1)) 
}

# Test 7: Check terraform version
test_terraform_version() {    
    if ! command -v terraform >/dev/null 2>&1; then
        test_error "terraform is not installed"
        TESTS_FAILED=$((TESTS_FAILED + 1)) 
        return 1
    fi
    
    local terraform_version
    terraform_version=$(terraform -v 2>/dev/null | grep 'Terraform' | awk '{print $2}')
    
    if [[ "${terraform_version}" == "${VERSION_TERRAFORM}" ]]; then
        test_pass "terraform version matches requirement: ${terraform_version}"
        TESTS_PASSED=$((TESTS_PASSED + 1)) 
    else
        test_warn "terraform version mismatch. Expected: ${VERSION_TERRAFORM##v}, Got: ${terraform_version}"
        TESTS_WARNED=$((TESTS_WARNED + 1)) 
    fi
}

# Test 8: Check if talosctl is installed
test_talosctl_installed() {    
    if ! command -v talosctl >/dev/null 2>&1; then
        test_error "talosctl is not installed or not in PATH"
        TESTS_FAILED=$((TESTS_FAILED + 1)) 
        return 1
    fi
    
    local talosctl_path
    talosctl_path="$(which talosctl)"
    test_pass "talosctl is installed at: ${talosctl_path}"
    TESTS_PASSED=$((TESTS_PASSED + 1)) 
}

# Test 9: Check talosctl version
test_talosctl_version() {    
    if ! command -v talosctl >/dev/null 2>&1; then
        test_error "talosctl is not installed"
        TESTS_FAILED=$((TESTS_FAILED + 1)) 
        return 1
    fi
    
    local talosctl_version
    talosctl_version=$(talosctl version --client 2>/dev/null | grep 'Tag:' | awk '{print $2}')
    
    if [[ "${talosctl_version}" == "${VERSION_TALOSCTL}" ]]; then
        test_pass "talosctl version matches requirement: ${talosctl_version}"
        TESTS_PASSED=$((TESTS_PASSED + 1)) 
    else
        test_warn "talosctl version mismatch. Expected: ${VERSION_TALOSCTL}, Got: ${talosctl_version}"
        TESTS_WARNED=$((TESTS_WARNED + 1)) 
    fi
}

# Run all tests
run_all_tests() {
    test_mark "Starting prerequisite tests..."
    echo ""

    test_install_bin_dir || return 1
    test_data_dir_state_terraform || return 1
    test_data_dir_var_terraform || return 1
    test_data_dir_machineconfigs || return 1
    test_config_dir_secrets || return 1
    test_terraform_installed || return 1
    test_terraform_version || return 1
    test_talosctl_installed || return 1
    test_talosctl_version || return 1

    echo ""
    log_info "Test Results: Passed: ${TESTS_PASSED}, Warned: ${TESTS_WARNED}, Failed: ${TESTS_FAILED}"
    
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

run_all_tests