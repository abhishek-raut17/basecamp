#!/usr/bin/env bash
#
# Usage: 
#   plan - Generates terraform plan to provision the infrastructure
#
# ------------------------------------------------------------------------------

set -euo pipefail
# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "$(dirname "$0")/shared/logger.sh"
source "$(dirname "$0")/shared/utils.sh"

trap 'log_fatal "plan target failed at line $LINENO"' ERR

PROJECT_NAME="${PROJECT_NAME:-basecamp}"
DATA_DIR="${DATA_DIR:-$HOME/.local/share/$PROJECT_NAME}"
INFRA_DIR="${INFRA_DIR:-${ROOT_DIR}/infrastructure}"
TERRAFORM_VAR_DIR="${TERRAFORM_VAR_DIR:-${DATA_DIR}/var/terraform}"
TERRAFORM_STATE_DIR="${TERRAFORM_STATE_DIR:-${DATA_DIR}/state/terraform}"
PLAN="${PLAN:-plan-v1.tfplan}"
GENERATED_TFVAR_FILE="${GENERATED_TFVAR_FILE:-${TERRAFORM_VAR_DIR}/terraform.tfvars}"
TERRAFORM_STATE_FILE="${TERRAFORM_STATE_FILE:-${TERRAFORM_STATE_DIR}/terrafom.tfstate}"

generate_vars() {
    local template="${INFRA_DIR}/terraform.tfvars.template"
    local genfile="${GENERATED_TFVAR_FILE}"

    log_debug "Generating .tfvars for terraform using template: $template at $genfile"

    if [[ ! -f "$template" ]]; then
        log_error "No terraform.tfvars.template found at $template"
        return 1
    fi

    envsubst < "$template" > "$genfile" || {
        log_warn "Error generating .tfvars from $template."
        return 1
    }

    log_debug "Successfully generated .tfvars at: $genfile"
    return 0
}

plan() {
    log_mark "Generating terraform plan to provision the infrastructure"

    # Generating tfvars using environment variables
    generate_vars || return 1

    # Init terraform providers
    cd "${INFRA_DIR}"
    terraform init -upgrade

    # Format source code
    terraform fmt -recursive

    # Validate source code for IaC
    terraform validate

    # Plan terraform infrastructure resources
    terraform plan -out="${PLAN}" -var-file="${GENERATED_TFVAR_FILE}"

    log_success "Generated terraform plan to provision the infrastructure sucessfully"
}

plan
# ------------------------------------------------------------------------------
