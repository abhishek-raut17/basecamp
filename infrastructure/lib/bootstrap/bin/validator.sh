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
    local cluster_subnet="$1"
    local controlplane="$2"
    local workers=$3

    log_debug "Validating if required arguments are provided"

    if [ -z $cluster_subnet ] || [ -z $controlplane ] || [ $workers -lt 2 ]; then
        log_error "Required arguments not provided."
        usage
        return 1;
    fi

    log_success "All required arguments provided."
}

# ------------------------------------------------------------------------------
# Validate arguments
# ------------------------------------------------------------------------------
validate_input() {
  local arg="$1"
  local value="$2"
  local clean_arg="${arg#"${arg%%[^-]*}"}"

  log_info "Validating input $clean_arg: $value"

  if is_arg_empty "$clean_arg" "$value"; then
    log_error "Failed to validate input $arg: $value"
    return 1
  fi

  case "$clean_arg" in
    cluster-subnet)
      validate_subnet "$value" "24" # default: /24 for cluster-subnet
      ;;
    controlplane)
      validate_ip "$value"
      ;;
    workers)
      validate_workers "$value"
      ;;
    config-dir)
      exists "dir" "$value"
      ;;
    talosconfig)
      exists "file" "$value"
      ;;
    pod-cidr)
      validate_subnet "$value" "16" # default: /16 for pod-cidr
      ;;
  esac

  log_success "Validated input $clean_arg: $value validated successfully"
  return 0
}

# ------------------------------------------------------------------------------
# Validate IP address
# ------------------------------------------------------------------------------
validate_ip() {
  local ip=$1
  
  log_debug "Validating IP addr: $ip"

  # Regex pattern: 4 octets (0-255) separated by dots
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    local IFS='.'
    local -a octets=($ip)
    
    for octet in "${octets[@]}"; do
      # Check range and no leading zeros
      if [ "$octet" -gt 255 ] || { [ ${#octet} -gt 1 ] && [ "${octet:0:1}" = "0" ]; }; then

        log_error "Invalid IP addr: $ip"
        return 1
      fi
    done

    log_success "Validated IP addr: $ip validated successfully"
    return 0
  fi

  log_error "Invalid IP addr: $ip"
  return 1
}

# ------------------------------------------------------------------------------
# Validate subnet
# ------------------------------------------------------------------------------
validate_subnet() {
  local subnet=$1
  local cidr_block=$2
  
  log_debug "Validating subnet $subnet: $cidr_block"

  # Check CIDR notation (IP/prefix)
  if [[ $subnet =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    local ip="${subnet%/*}"
    local prefix="${subnet#*/}"
    
    # Validate IP part
    validate_ip "$ip" || return 1
    
    # Validate prefix (0-32)
    if [ "$prefix" -gt 32 ] || [ "$prefix" -ne "$cidr_block" ]; then
      log_error "Invalid subnet CIDR: $subnet"
      return 1
    fi
    
    log_success "Validated subnet CIDR: $subnet validated successfully"
    return 0
  fi

  log_error "Invalid subnet CIDR: $subnet"
  return 1
}

# ------------------------------------------------------------------------------
# Validate worker node count
# ------------------------------------------------------------------------------
validate_workers() {
  local workers=$1
  local count=2

  log_debug "Validating worker count"

  if [ "$workers" -lt $count ]; then
  
    log_error "Need worker count > $count"
    return 1
  fi

  log_success "Validated worker node count: $workers validated successfully"
  return 0
}

# ------------------------------------------------------------------------------
