#!/usr/bin/env bash
#

# ------------------------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------------------------
parse_and_validate_arguments() {
  log_info "Parsing input arguments"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cluster)
          validate_input "$1" "$2"
          CLUSTER_NAME="$2"
          shift 2
          ;;
      --cluster-subnet)
          validate_input "$1" "$2"
          CLUSTER_SUBNET="$2"
          shift 2
          ;;
      --controlplane)
          validate_input "$1" "$2"
          CONTROLPLANE_IP="$2"
          shift 2
          ;;
      --workers)
          validate_input "$1" "$2"
          WORKERS="$2"
          shift 2
          ;;
      --config-dir)
          validate_input "$1" "$2"
          CONFIG_DIR="$2"
          shift 2
          ;;
      --talosconfig)
          validate_input "$1" "$2"
          TALOSCONFIG_PATH="$2"
          shift 2
          ;;
      --talosctl-version)
          validate_input "$1" "$2"
          TALOSCTL_VERSION="$2"
          shift 2
          ;;
      --kubectl-version)
          validate_input "$1" "$2"
          KUBECTL_VERSION="$2"
          shift 2
          ;;
      --calico-version)
          validate_input "$1" "$2"
          CALICO_VERSION="$2"
          shift 2
          ;;
      --pod-cidr)
          validate_input "$1" "$2"
          POD_CIDR="$2"
          shift 2
          ;;
      --git-token)
          validate_input "$1" "$2"
          GIT_PAT="$2"
          shift 2
          ;;
      -h|--help)
          usage
          exit 0
          ;;
      *)
          log_error "Unknown argument: $1"
          usage
          exit 1
          ;;
    esac
  done
}

# ------------------------------------------------------------------------------
# Validate required arguments
# ------------------------------------------------------------------------------
validate_required_args() {
    local cluster_subnet="${1:-${CLUSTER_SUBNET}}"
    local controlplane="${2:-${CONTROLPLANE_IP}}"
    local token="${3:-${GIT_PAT}}"
    local workers=${4:-${WORKERS}}

    log_debug "Validating if required arguments are provided"

    if [ -z $cluster_subnet ] || 
      [ -z $controlplane ] || 
      [ $workers -lt 2 ] || 
      [ -z $token ]; then
        log_error "Required arguments not provided."
        usage
        return 1
    fi

    log_success "All required arguments provided."
    return 0
}

# ------------------------------------------------------------------------------
