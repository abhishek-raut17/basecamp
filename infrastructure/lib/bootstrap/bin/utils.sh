#!/usr/bin/env bash
#

# ------------------------------------------------------------------------------
# Usage function
# ------------------------------------------------------------------------------
usage() {
    cat <<EOF

Talos Kubernetes Cluster Bootstrap Script

Usage: ./bootstrap.sh [REQUIRED] [OPTIONS]

Required:
  --cluster-subnet <cidr>       Cluster node's subnet (e.g., 10.0.10.0/24)
  --controlplane <ipv4>         Control plane IPv4 address
  --workers <number>            Number of worker nodes in cluster

Options:
  --cluster <name>              Cluster name
  --config-dir <path>           Base config directory
  --talosconfig <path>          Talosconfig file path
  --talosctl-version <version>  Talosctl version
  --kubectl-version <version>   Kubectl version
  --calico-version <version>    Calico version
  --pod-cidr <cidr>             Pod network CIDR
  --git-token                   Github Personal Access Token
  -h, --help                    Show this help message

Examples:
  # Basic usage with required parameters
  ./bootstrap.sh --cluster-subnet 10.0.10.0/24 --controlplane 10.0.10.10 --workers 3

  # Custom cluster with specific versions
  ./bootstrap.sh --cluster production \\
     --cluster-subnet 172.16.0.0/24 \\
     --controlplane 172.16.0.10 \\
     --workers 5 \\
     --talosctl-version v1.11.2 \\
     --kubectl-version v1.34.1 \\
     --git-token xxxx
EOF
}

# ------------------------------------------------------------------------------
# Cleanup on error
# ------------------------------------------------------------------------------
cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Bootstrap failed with exit code: $exit_code"
        # rm *.sha256
        # rm sha256sum.txt
        # log_warn "Check logs and cluster state before retrying"
    fi
    exit "$exit_code"
}

# ------------------------------------------------------------------------------
# Check if argument is provided
# ------------------------------------------------------------------------------
is_arg_empty() {
  local description="$1"
  local arg="$2"

  log_debug "nullcheck argument $clean_arg: $value"

  if [ -z "$arg" ]; then
    log_error "Argument $description: $arg not provided."
    usage
    return 0
  fi
  return 1
}

# ------------------------------------------------------------------------------
# Check if exists (path, file, dir)
# ------------------------------------------------------------------------------
exists() {
    local resource=$1
    local path=$2

    # Check if path is provided
    if [ -z "$path" ]; then
      log_error "Path not provided"
      return 1
    fi

    if [ ! -e "$path" ]; then
      log_warn "Path $path does not exist"
      return 1
    fi

    case "$resource" in
      file)
          if [ -f "$path" ]; then
              return 0
          else
              log_warn "$path exists but is not a file"
              return 1
          fi
          ;;
      dir)
          if [ -d "$path" ]; then
              return 0
          else
              log_warn "$path exists but is not a directory"
              return 1
          fi
          ;;
      *)
          log_error "Unknown resource type: $resource"
          return 1
          ;;
    esac
}

# ------------------------------------------------------------------------------
# Copy to destination
# ------------------------------------------------------------------------------
copy() {
    local source="$1"
    local dest="$2"

    log_debug "Copying $source to $dest"

    if ! exists "file" "$source"; then
        log_error "Source file not present at $source"
        return 1
    fi

    create_file "$dest"
    cp "$source" "$dest" || {
        log_warn "Failed to copy file from $source to $dest"
        return 1
    }

    log_success "Copied $source to $dest successfully"
    return 0
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

    log_debug "Validated IP addr: $ip validated successfully"
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
    validate_ip "$ip"
    
    # Validate prefix (0-32)
    if [ "$prefix" -gt 32 ] || [ "$prefix" -ne "$cidr_block" ]; then
      log_error "Invalid subnet CIDR: $subnet"
      return 1
    fi
    
    log_debug "Validated subnet CIDR: $subnet validated successfully"
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

  log_debug "Validated worker node count: $workers validated successfully"
  return 0
}

# ------------------------------------------------------------------------------
# Create directory (with parent if not exists) (default: 0750 permission)
# ------------------------------------------------------------------------------
create_dir() {
    local path="$1"

    log_debug "Provisioning directory at $path"
    
    # Check if directory already exists
    if ! exists "dir" "$path"; then
        mkdir -m 0750 -p "$path"
        log_success "Created directory at $path successfully"
    else
        log_info "Directory already exists at path $path"
        return 0
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Create file
# ------------------------------------------------------------------------------
create_file() {
    local path="$1"
    local dir=$(dirname "$path")

    log_debug "Provisioning file at $path"
    
    # Check if directory already exists, create if not
    create_dir "$dir"
    
    # Check if file already exists
    if ! exists "file" "$path"; then
        touch "$path"
        chmod 0640 "$path"
        log_success "Created file at $path successfully"
    else
        log_info "File already exists at path $path"
        return 0
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Export variables for persistence across sessions
# ------------------------------------------------------------------------------
export_variable() {
    local config_name="$1"
    local path="$2"
    local bashrc="${3:-${BASHRC_PATH}}"

    log_debug "Exporting $config_name to $bashrc"

    if [ -z "$config_name" ] || [ -z "$path" ]; then
        log_error "Config: $config or path: $path not provided"
        return 1
    fi

    if grep -q "^export ${config_name}=" "$bashrc"; then
        log_info "$config_name already exists in $bashrc"
    else
        echo "export $config_name=\"$path\"" >> "$bashrc"
        log_info "Config $config exported to $bashrc"
    fi

    source "$bashrc"
    return 0
}

# ------------------------------------------------------------------------------
# Install CLI bin
# ------------------------------------------------------------------------------
install_bin() {
    local tool="$1"
    local checksum="$2"
    local url="$3"
    local cmd
    cmd="$(basename "$tool")"
    cmd="${cmd%%-*}"

    log_debug "Installing CLI bin: $cmd in PATH."

    # Check if url is provided
    if [[ -z "$url" ]]; then
        log_error "$url not valid or incorrect format"
        return 1
    fi

    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_warn "$cmd not found in PATH"
        log_info "Fetching resources from URL: $url"

        curl -LO "$url/$tool"
        curl -LO "$url/$checksum"

        if cat "$checksum" | grep -q "$tool"; then
            # checksum file already contains filename → direct verify
            cat sha256sum.txt | grep talosctl-linux-amd64 | sha256sum -c -
        else
            # checksum file contains ONLY the hash → add filename dynamically
            local hash
            hash="$(cat "$checksum")"
            echo "$hash  $tool" | sha256sum -c -
        fi

        chmod 0750 "$tool"
        # Testing only (turn off in prod)
        # chown sentinel:ops "$tool"

        mv "$tool" "/usr/local/bin/$cmd"
        log_info "CLI bin: $cmd installed IN PATH"
    else
        log_info "CLI bin: $cmd already in PATH"
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Install tools
# ------------------------------------------------------------------------------
install_tool() {
    local tool="$1"
    local url="$2"

    log_debug "Installing CLI tool: $tool in PATH."

    # Check if url is provided
    if [[ -z "$url" ]]; then
        log_error "$url not valid or incorrect format"
        return 1
    fi

    if ! command -v "$tool" >/dev/null 2>&1; then
        log_warn "$tool not found in PATH"
        log_info "Fetching resources from URL: $url"
        
        curl "$url" | bash
    else
        log_info "CLI tool: $tool already in PATH"
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Add IP route to subnet
# ------------------------------------------------------------------------------
add_subnet_route() {
    local subnet="${1:-${CLUSTER_SUBNET}}"
    
    log_debug "Validating route to cluster subnet: $subnet"

    if ip route show | grep "$subnet"; then
        log_info "Route to $subnet already exists"
        return 0
    fi
    
    if ip route add "$subnet" dev eth1 2>/dev/null; then
        log_info "Route to $subnet added successfully"
    else
        log_error "Failed to add route to $subnet"
        return 1
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Validate if etcd is running
# ------------------------------------------------------------------------------
is_etcd_running() {
    local node="$1"
    local status
    status=$(talosctl --nodes $node service etcd | grep "HEALTH.*" 2>/dev/null)

    log_debug "Reaching etcd node: $node with $status"

    [[ "$status" =~ OK ]]
    return $?
}

# ------------------------------------------------------------------------------
# Wait for ETCD to be valid and Running
# ------------------------------------------------------------------------------
wait_for_etcd() {
  local ip="$1"
  local timeout=$2
  local elapsed=0
  local interval=5

  if is_etcd_running "$ip"; then
    log_info "etcd is running (initial check)"
    return 0
  fi

  until is_etcd_running "$ip" || [ $elapsed -ge $timeout ]; do
      log_debug "Waiting for etcd... (${elapsed}/${timeout}s)"
      sleep "$interval"
      elapsed=$((elapsed + interval))
  done

  if is_etcd_running "$ip"; then
      log_info "etcd is running after ${elapsed}s"
      return 0
  else
      log_error "Timeout waiting for etcd"
      return 1
  fi
}

# ------------------------------------------------------------------------------
# Watch kubectl nodes
# ------------------------------------------------------------------------------
kube_watch() {
    local resource=${1:-pod}
    local condition=${2:-ready}
    local namespace=${3:-default}
    local timeout=${4:-30}

    kubectl wait \
        --for=condition="$condition" \
        --namespace="$namespace" \
        --all \
        $resource \
        --timeout="${timeout}s"
}

# ------------------------------------------------------------------------------
# Label worker nodes
# ------------------------------------------------------------------------------
label_workers() {
    local workers=$1
    local prefix="${2:-${CLUSTER_NAME}}"

    log_debug "Labeling worker nodes"

    for (( i=0; i<$workers; i++ )); do
        node="${prefix}-worker-${i}"
        if kubectl get node "$node" >/dev/null 2>&1; then
            kubectl label node "$node" node-role.kubernetes.io/worker="" --overwrite || warn "Failed to label $node"
            log_info "Labeled node ${i} as $node"
        else
            log_warn "Node $node not found, skipping"
        fi
    done
}

# ------------------------------------------------------------------------------
# Kube apply with resource
# ------------------------------------------------------------------------------
kube_apply() {
    local config="$1"
    log_info "Customizing component: $config"
    
    exists "file" "$config"
    kubectl apply -f "$config"
    log_success "Customized component successfully"
}
# ------------------------------------------------------------------------------
