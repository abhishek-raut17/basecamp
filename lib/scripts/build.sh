#!/usr/bin/env bash
#
# Usage: 
#   build - Apply terraform plan to provision the infrastructure
#
# ------------------------------------------------------------------------------

set -euo pipefail
# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "$(dirname "$0")/shared/logger.sh"
source "$(dirname "$0")/shared/utils.sh"

trap 'log_fatal "build target failed at line $LINENO"' ERR

PROJECT_NAME="${PROJECT_NAME:-basecamp}"
DATA_DIR="${DATA_DIR:-$HOME/.local/share/$PROJECT_NAME}"
INFRA_DIR="${INFRA_DIR:-${ROOT_DIR}/infrastructure}"
TERRAFORM_VAR_DIR="${TERRAFORM_VAR_DIR:-${DATA_DIR}/var/terraform}"
TERRAFORM_STATE_DIR="${TERRAFORM_STATE_DIR:-${DATA_DIR}/state/terraform}"
PLAN="${PLAN:-plan-v1.tfplan}"
GENERATED_TFVAR_FILE="${GENERATED_TFVAR_FILE:-${TERRAFORM_VAR_DIR}/terraform.tfvars}"
TERRAFORM_STATE_FILE="${TERRAFORM_STATE_FILE:-${TERRAFORM_STATE_DIR}/terrafom.tfstate}"

build() {
    log_mark "Applying terraform plan to provision the infrastructure"

    # Init terraform providers
    cd "${INFRA_DIR}"

    # Apply terraform infrastructure resources
    terraform apply "${PLAN}"
    terraform output -json > "${TERRAFORM_VAR_DIR}/${PLAN%%.*}.json"

    log_success "Applied terraform plan ${PLAN} to provision the infrastructure sucessfully"
}

build
# ------------------------------------------------------------------------------
