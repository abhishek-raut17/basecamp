#!/usr/bin/env bash
#
# Test suite for plan.sh
# Validates terraform plan is generated correctly
#
# Steps:
# 1. Check if terraform.tfvars file is generated at ${TERRAFORM_VAR_DIR}/terraform.tfvars
# 2. Check if there are no invalid variables in terraform.tfvars (i.e. value is empty or null)
# 3. Check if ${PLAN} is generated at ${INFRA_DIR}/${PLAN}

set -euo pipefail

# Source shared modules
source "$(dirname "$0")/../scripts/shared/logger.sh"

PROJECT_NAME="${PROJECT_NAME:-basecamp}"
DATA_DIR="${DATA_DIR:-$HOME/.local/share/$PROJECT_NAME}"
INFRA_DIR="${INFRA_DIR:-${ROOT_DIR}/infrastructure}"
TERRAFORM_VAR_DIR="${TERRAFORM_VAR_DIR:-${DATA_DIR}/var/terraform}"
TERRAFORM_STATE_DIR="${TERRAFORM_STATE_DIR:-${DATA_DIR}/state/terraform}"
PLAN="${PLAN:-plan-v1.tfplan}"
GENERATED_TFVAR_FILE="${GENERATED_TFVAR_FILE:-${TERRAFORM_VAR_DIR}/terraform.tfvars}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

trap 'log_fatal "test-plan failed at line $LINENO"' ERR

# Test 1: Check if terraform.tfvars file is generated
test_terraform_tfvars_generated() {
    if [[ ! -f "${GENERATED_TFVAR_FILE}" ]]; then
        test_error "terraform.tfvars file not found at: ${GENERATED_TFVAR_FILE}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    if [[ ! -s "${GENERATED_TFVAR_FILE}" ]]; then
        test_error "terraform.tfvars file is empty at: ${GENERATED_TFVAR_FILE}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    test_pass "terraform.tfvars file exists and contains data: ${GENERATED_TFVAR_FILE}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

# Test 2: Check if there are no invalid variables in terraform.tfvars
test_terraform_tfvars_valid() {
    if [[ ! -f "${GENERATED_TFVAR_FILE}" ]]; then
        test_error "terraform.tfvars file not found at: ${GENERATED_TFVAR_FILE}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    local invalid_vars=0
    local invalid_var_list=""
    
    # Check for empty values or null values in tfvars
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        
        # Remove leading/trailing whitespace and quotes
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | tr -d '"')
        
        # Check if value is empty or null
        if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
            invalid_vars=$((invalid_vars + 1))
            invalid_var_list="${invalid_var_list}${key}, "
        fi
    done < "${GENERATED_TFVAR_FILE}"
    
    if [[ ${invalid_vars} -gt 0 ]]; then
        test_error "Found ${invalid_vars} invalid variables in terraform.tfvars: ${invalid_var_list%??}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    test_pass "All variables in terraform.tfvars are valid (no empty or null values)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

# Test 3: Check if terraform plan file is generated
test_terraform_plan_generated() {
    local plan_file="${INFRA_DIR}/${PLAN}"
    
    if [[ ! -d "${INFRA_DIR}" ]]; then
        test_error "Infrastructure directory not found at: ${INFRA_DIR}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    if [[ ! -f "${plan_file}" ]]; then
        test_error "terraform plan file not found at: ${plan_file}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    if [[ ! -s "${plan_file}" ]]; then
        test_error "terraform plan file is empty at: ${plan_file}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    test_pass "terraform plan file exists and contains data: ${plan_file}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

# Run all tests
run_all_tests() {
    test_mark "Starting terraform plan validation tests..."
    echo ""
    
    test_terraform_tfvars_generated || return 1
    test_terraform_tfvars_valid || return 1
    test_terraform_plan_generated || return 1

    echo ""
    log_info "Test Results: Passed: ${TESTS_PASSED}, Warned: ${TESTS_WARNED}, Failed: ${TESTS_FAILED}"
    
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

run_all_tests