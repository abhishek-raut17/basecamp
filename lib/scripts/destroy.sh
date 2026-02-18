#!/usr/bin/env bash
#
# Usage: 
#   destroy - Apply terraform plan to destroy the infrastructure
#
# ------------------------------------------------------------------------------

set -euo pipefail
# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "$(dirname "$0")/shared/logger.sh"
source "$(dirname "$0")/shared/utils.sh"

trap 'log_fatal "destroy target failed at line $LINENO"' ERR

PROJECT_NAME="${PROJECT_NAME:-basecamp}"
DATA_DIR="${DATA_DIR:-$HOME/.local/share/$PROJECT_NAME}"
INFRA_DIR="${INFRA_DIR:-${ROOT_DIR}/infrastructure}"
TERRAFORM_VAR_DIR="${TERRAFORM_VAR_DIR:-${DATA_DIR}/var/terraform}"
PLAN="${PLAN:-plan-v1.tfplan}"
GENERATED_TFVAR_FILE="${GENERATED_TFVAR_FILE:-${TERRAFORM_VAR_DIR}/terraform.tfvars}"

destroy() {
    log_mark "Using terraform plan to destroy the infrastructure"

    # Init terraform providers
    cd "${INFRA_DIR}"

    # CRITICAL: Destroy infrastructure
    if [[ ! -f "${GENERATED_TFVAR_FILE}" ]]; then
        log_warn "No terraform.tfvars file found at: ${TERRAFORM_VAR_DIR}. Skipping make target: destroy"
        return 0
    fi

    terraform apply -destroy -auto-approve -var-file=${GENERATED_TFVAR_FILE}

    log_success "Used terraform plan ${PLAN} to destroy the infrastructure sucessfully"
}

destroy
# ------------------------------------------------------------------------------
