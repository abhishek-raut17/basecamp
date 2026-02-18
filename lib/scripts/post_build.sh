#!/usr/bin/env bash
#
# Usage: 
#   post_build - Run post infrastructure provisioning steps
#
# ------------------------------------------------------------------------------

set -euo pipefail
# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "$(dirname "$0")/shared/logger.sh"
source "$(dirname "$0")/shared/utils.sh"

trap 'log_fatal "post_build target failed at line $LINENO"' ERR

PROJECT_NAME="${PROJECT_NAME:-basecamp}"
INFRA_DIR="${INFRA_DIR:-${ROOT_DIR}/infrastructure}"
DMZ_CONF_DIR="${DMZ_CONF_DIR:-${LIB_DIR}/configs}"
DATA_DIR="${DATA_DIR:-$HOME/.local/share/$PROJECT_NAME}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/$PROJECT_NAME}"
SECRETS_DIR="${SECRETS_DIR:-${CONFIG_DIR}/secrets}"
TALOS_SECRETS_DIR="${TALOS_SECRETS_DIR:-${SECRETS_DIR}/talos}"
AGE_SECRETS_DIR="${AGE_SECRETS_DIR:-${SECRETS_DIR}/age}"
TERRAFORM_VAR_DIR="${TERRAFORM_VAR_DIR:-${DATA_DIR}/var/terraform}"
DMS_PROVISION_DIR="${DMZ_PROVISION_DIR:-${INFRA_DIR}/ansible}"
TERRAFORM_VAR_DIR="${TERRAFORM_VAR_DIR:-${DATA_DIR}/var/terraform}"
PLAN="${PLAN:-plan-v1.tfplan}"

generate_inventory_vars() {
    local template="${DMS_PROVISION_DIR}/inventory.ini.template"
    local genfile="${DMS_PROVISION_DIR}/inventory.ini"

    log_debug "Generating inventory.ini for ansible using template: $template at $genfile"

    if [[ ! -f "$template" ]]; then
        log_error "No inventory.ini.template found at $template"
        return 1
    fi

    envsubst < "$template" > "$genfile" || {
        log_warn "Error generating inventory.ini from $template."
        return 1
    }

    log_debug "Successfully generated inventory.ini at: $genfile"
    return 0
}

post_build() {
    log_mark "Running post infrastructure provisioning steps"

    # Sleep for 30 to give infra resource time to bootup
    log_debug "Sleeping for 30s"
    sleep 30

    # Init terraform providers
    cd "${DMS_PROVISION_DIR}"
 
    export DMZ_ACCESS_KEY="${ACCESS_SSHKEY_PATH%%.pub}"
    export DEVOPS_SSHKEY_PATH="${DEVOPS_SSHKEY_PATH%%.pub}"
    export DMZ_HOST="$(jq -r '.compute_details.value.dmz.ipv4[0]' "${TERRAFORM_VAR_DIR}/${PLAN%%.*}.json")"
    export CLUSTER_SUBNET="$(jq -r '.network_details.value.vpc.subnets[] | select(.name == "cluster") | .cidr' "${TERRAFORM_VAR_DIR}/${PLAN%%.*}.json")"
    export TALOSCONFIG="${TALOS_SECRETS_DIR}/talosconfig"
    export KUBECONFIG="${TALOS_SECRETS_DIR}/kubeconfig"
    export AGE_PRIVATE_KEY="${AGE_PRIVATE_KEY:-${AGE_SECRETS_DIR}/${PROJECT_NAME}-key.txt}"
    export GIT_REPO="${GIT_REPO:-ssh://git@github.com/abhishek-raut17/basecamp.git}"
    export NGINX_CONF="${NGINX_CONF:-${DMZ_CONF_DIR}/nginx.conf}"
    export KERNEL_TUNING_CONF="${KERNEL_TUNING_CONF:-${DMZ_CONF_DIR}/99-tuning.conf}"
    export TURNSERVER_CONF="${TURNSERVER_CONF:-${DMZ_CONF_DIR}/turnserver.conf.template}"
    export COTURN_SERVER_AUTH_ENCODED="${COTURN_SERVER_AUTH_ENCODED}"
    export TURN_DOMAIN="${TURN_DOMAIN:-turn.sigdep.cloud}"

    # Apply terraform infrastructure resources
    generate_inventory_vars || return 1

    # Run ansible playbook
    ansible-playbook -i inventory.ini playbook.yaml

    log_success "Post infrastructure provisioning steps completed successfully"
}

post_build
# ------------------------------------------------------------------------------
