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
     --kubectl-version v1.34.1
EOF
}

# ------------------------------------------------------------------------------
# Cleanup on error
# ------------------------------------------------------------------------------
cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Bootstrap failed with exit code: $exit_code"
        rm *.sha256
        rm sha256sum.txt
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
# Create directory (with parent if not exists) (default: 0750 permission)
# ------------------------------------------------------------------------------
create_dir() {
    local path="$1"

    log_debug "Provisioning directory at $path"
    
    # Check if directory already exists
    if ! exists "dir" "$path"; then
        mkdir -m 0750 -p "$path"
        log_info "Created directory at $path successfully"
    else
        log_info "Directory already exists at path $path"
        return 0
    fi
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
        log_info "Created file at $path successfully"
    else
        log_info "File already exists at path $path"
        return 0
    fi
}

# ------------------------------------------------------------------------------
# Export variables for persistence across sessions
# ------------------------------------------------------------------------------
export_variable() {
    local config_name="$1"
    local path="$2"
    local bashrc="/root/.bashrc"

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
}

# ------------------------------------------------------------------------------
# Install CLI tools
# ------------------------------------------------------------------------------
install_tool() {
    local tool="$1"
    local checksum="$2"
    local url="$3"
    local cmd
    cmd="$(basename "$tool")"
    cmd="${cmd%%-*}"

    log_debug "Installing CLI tool: $cmd in PATH."

    # Check if url is provided
    if [[ -z "$url" ]]; then
        log_error "$url not valid or incorrect format"
        return 1
    fi

    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_warn "$cmd not found in PATH"
        log_info "Fetching resources from URL: $url"

        # cd $(mktemp -d)
        # log_info "In temp dir: $(pwd) ... "

        curl -LO "$url/$tool"
        curl -LO "$url/$checksum"

        if grep -q "$tool" "$checksum"; then
            # checksum file already contains filename → direct verify
            grep "$tool" "$checksum" | sha256sum -c "$checksum"
        else
            # checksum file contains ONLY the hash → add filename dynamically
            local hash
            hash="$(cat "$checksum")"
            echo "$hash  $tool" | sha256sum -c -
        fi

        chmod 0750 "$tool"

        # Testing only (turn off in prod)
        chown sentinel:ops "$tool"

        mv "$tool" "/usr/local/bin/$cmd"
        log_info "CLI tool: $cmd installed IN PATH"
    else
        log_info "CLI tool: $cmd already in PATH"
    fi
}

# ------------------------------------------------------------------------------
# Install Helm
# ------------------------------------------------------------------------------
install_helm() {
    local url="$1"

    log_debug "Installing CLI tool: Helm in PATH."

    # Check if url is provided
    if [[ -z "$url" ]]; then
        log_error "$url not valid or incorrect format"
        return 1
    fi

    if ! command -v helm >/dev/null 2>&1; then
        log_warn "Helm not found in PATH"
        log_info "Fetching resources from URL: $url"
        
        curl "$url" | bash
    else
        log_info "CLI tool: helm already in PATH"
    fi
}

install_fluxcd() {

    log_debug "Installing CLI tool: FluxCD in PATH."
    curl -s https://fluxcd.io/install.sh | bash
}

# ------------------------------------------------------------------------------
# Add IP route to subnet
# ------------------------------------------------------------------------------
add_subnet_route() {
    local subnet="$1"
    
    log_debug "Adding route to cluster subnet: $subnet"

    if ip route show | grep "$subnet"; then
        log_debug "Route to $subnet already exists"
        return 0
    fi
    
    if ip route add "$subnet" dev eth1 2>/dev/null; then
        log_info "Route to $subnet added successfully"
    # elif ip route show | grep -q "${subnet} "; then
    #     log_debug "Route to $subnet already exists"
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

    log_debug "reaching etcd node: $node with Health: $status"

    [[ "$status" =~ OK ]]
    return $?
}

# ------------------------------------------------------------------------------
# Watch etcd
# ------------------------------------------------------------------------------
watch_etcd() {
    local ip="$1"
    local timeout=$2
    
    timeout $timeout watch -n 2 "talosctl --nodes $ip service etcd"
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
    log_info "etcd is running"
    return 0
  fi

  until is_etcd_running "$ip" || [ $elapsed -ge $timeout ]; do
      log_debug "Waiting for etcd... (${elapsed}/${timeout}s)"
      watch_etcd "$ip" $interval
      elapsed=$((elapsed + interval))
  done

  if is_etcd_running "$ip"; then
      log_info "etcd is running"
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
# Generate and export kubeconfig to KUBECONFIG
# ------------------------------------------------------------------------------
setup_kubeconfig() {

    log_info "Generating kubeconfig for kubectl"

    # Config talosctl endpoint if not present
    talosctl config endpoint "${CONTROLPLANE_IP}"

    # Generate and copy kubeconfig to KUBECONFIG
    rm kubeconfig
    talosctl --nodes "${CONTROLPLANE_IP}" --talosconfig "$TALOSCONFIG" kubeconfig .

    cp kubeconfig "${KUBECONFIG}" || {
        log_warn "Failed to copy kubeconfig from $(pwd) to $KUBECONFIG"
        return 1
    }

    log_success "Generated kubeconfig for kubectl"
}

# ------------------------------------------------------------------------------
# Install CNI Plugin
# ------------------------------------------------------------------------------
cni_plugin() {

    log_info "Installing component: CNI plugin"

    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml
    
    # Wait for initial installation
    kube_watch "crd" "established" "default" 60
    kube_watch "deployment" "available" "tigera-operator" 120

    log_success "Installed component: CNI plugin successfully"
}

update_cni_plugin() {

    log_info "Customizing component: CNI plugin"
    curl -O https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/custom-resources.yaml
    sed -i "s|192.168.0.0/16|$POD_CIDR|g" custom-resources.yaml    
    kubectl apply -f custom-resources.yaml
    log_success "Customized component: CNI plugin successfully"
}

# ------------------------------------------------------------------------------
# Label worker nodes
# ------------------------------------------------------------------------------
label_workers() {
    local workers=$WORKERS

    log_debug "Labeling worker nodes"

    for (( i=0; i<$workers; i++ )); do
        node="${CLUSTER_NAME}-worker-${i}"
        if kubectl get node "$node" >/dev/null 2>&1; then
            kubectl label node "$node" node-role.kubernetes.io/worker="" --overwrite || warn "Failed to label $node"
            log_info "Labeled node ${i} as $node"
        else
            warn "Node $node not found, skipping"
        fi
    done
}

# ------------------------------------------------------------------------------
# Setup CNI
# ------------------------------------------------------------------------------
setup_CNI() {

    # label worker nodes for role
    label_workers

    # Install Calico CNI plugin
    cni_plugin

    # Customize CNI plugin with custom resource
    update_cni_plugin
}

# ------------------------------------------------------------------------------
