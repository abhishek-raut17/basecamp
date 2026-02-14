#!/usr/bin/env bash
#
# Usage: 
#   validate_env - Validate all the required environment variables for cluster provisioning
#
# ------------------------------------------------------------------------------

set -euo pipefail

# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "$(dirname "$0")/shared/logger.sh"
source "$(dirname "$0")/shared/utils.sh"

trap 'log_fatal "validate_env target failed at line $LINENO"' ERR

REQUIRED_ENV_VARS=(
    PROJECT_NAME
    CLOUD_PROVIDER_PAT
    CLOUD_PROVIDER_REGION
    ACCESS_SSHKEY_PATH
    VPC_CIDR
    CLUSTER_IP
    NODETYPE_DMZ
    NODETYPE_CLUSTER
    NODEIMG_DMZ
    NODEIMG_CLUSTER
    CONTROLPLANE_NODECOUNT
    WORKER_NODECOUNT
    CONFIG_DIR
    DATA_DIR
    INSTALL_BIN_DIR
)

validate_env() {
    log_mark "Validating required environment variables from .env file"

    local missing=0
    local missing_var=""
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        # Use indirect expansion to get the variable's value
        if [[ -z "${!var:-}" ]]; then
            missing=$((missing + 1))
            missing_var+="\\n${var}"
        else
            test_pass "$var=${!var}"
        fi
    done
    
    if [[ $missing -gt 0 ]]; then
        log_error "$missing required environment variable(s) not set. Required variables: $missing_var"
        return 1
    fi

    log_success "All required environment variables are available and valid"
}

validate_env
# ------------------------------------------------------------------------------
