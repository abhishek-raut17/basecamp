#!/usr/bin/env bash
set -euo pipefail

# Variables
CLUSTER_NAME=""
CLUSTER_SUBNET=""
CONTROLPLANE_IP=""
WORKERS=0
CONFIG_DIR="/root/.config"
TALOSCONFIG_PATH="/tmp/talosconfig"
TALOSCTL_VERSION="v1.11.2" # default 
KUBECTL_VERSION="v1.34.1" # default
CALICO_VERSION="v3.31.2" # default
POD_CIDR="10.244.0.0/16" # default

# ------------------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------------------
info()    { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# ------------------------------------------------------------------------------
# Utility functions
# ------------------------------------------------------------------------------
usage() {
    cat <<EOF

Usage: $0 [REQUIRED] [OPTIONS]

Required:
--cluster-subnet string         Cluster node's subnet to administer
--controlplane <ipv4>           Cluster controlplane ipv4 address
--workers numbber               Number of worker nodes in cluster

Options:
--cluster string                Cluster name (default: basecamp)
--talosconfig <path>            Talosconfig file path. (default: /tmp/talosconfig)

-h, --help                      Show this help message

Examples:
$0 --cluster example --cluster-subnet 10.0.10.10/24 --controlplane 10.0.10.10 --workers 3 --talosconfig /tmp/talosconfig
$0 --cluster-subnet 10.0.10.10/24 --controlplane 10.0.10.10 --workers 3 --talosconfig /tmp/talosconfig
$0 --cluster example --cluster-subnet 10.0.10.10/24 --workers 3 --controlplane 10.0.10.10

EOF
}

# ------------------------------------------------------------------------------
# Error handling
# ------------------------------------------------------------------------------
trap 'error " --- Script failed ---' ERR INT

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------
create_dir() {
    local path="$1"
    local dirname="$(basename "$path")"

    if [[ -z "$path" ]]; then
        error "Directory path is required"
        return 1
    fi

    if [[ ! -d "$path" ]]; then
        mkdir -m 0750 -p $path
        info "Created directory $dirname at $path"
    else
        warn "Directory $dirname already exists at $path"
    fi
}

install_tool() {
    local cmd="$1"
    local tool="$2"
    local checksum="$3"
    local url="$4"

    info "Installing CLI tool: $cmd in PATH."

    if [[ -z "$url" ]]; then
        error "$url not valid or incorrect format"
        exit 1
    fi

    if ! command -v "$cmd" >/dev/null 2>&1; then
        warn "$cmd not found in PATH"
        info "Fetching resources from URL: $url"

        cd $(mktemp -d) && echo $(pwd)
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

        chmod 0550 "$tool"
        mv "$tool" "/usr/local/bin/$cmd"
        info "CLI tool installed IN PATH"
    else
        info "CLI tool: $cmd already in PATH"
    fi
}

install_helm() {

    info "Installing CLI tool: HELM in PATH."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash
}

is_bootstrapped() {
    local node_ip=$1
    
    # Check if etcd has members
    if talosctl --nodes "${node_ip}" etcd members &>/dev/null; then
        # Check if we got actual members (not empty)
        local member_count=$(talosctl --nodes "${node_ip}" etcd members 2>/dev/null | grep -c ":")
        if [ "$member_count" -gt 0 ]; then
            return 0  # Already bootstrapped
        fi
    fi
    return 1  # Not bootstrapped
}

# ------------------------------------------------------------------------------
# Main function
# ------------------------------------------------------------------------------

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --cluster-subnet)
            CLUSTER_SUBNET="$2"
            shift 2
            ;;
        --controlplane)
            CONTROLPLANE_IP="$2"
            shift 2
            ;;
        --workers)
            WORKERS="$2"
            shift 2
            ;;
        --talosconfig)
            TALOSCONFIG_PATH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown argument: $1"
            usage
            ;;
    esac
done

# --- Validate inputs ---
if [ -z "${CLUSTER_NAME}" ]; then
    error "Cluster name not provided."
    usage
    exit 1
fi

if [ -z "${CLUSTER_SUBNET}" ]; then
    error "Cluster node's subnet not provided."
    usage
    exit 1
fi

if [ -z "${CONTROLPLANE_IP}" ]; then
    error "Control plane IP not provided."
    usage
    exit 1
fi

if [ -z "${WORKERS}" ] || [ "${WORKERS}" -lt 1 ]; then
    error "Worker node count not provided or less than 1."
    usage
    exit 1
fi

if [ ! -f "${TALOSCONFIG_PATH}" ]; then
    error "Talosconfig file missing or not provided."
    usage
    exit 1
fi

# --- Initialize bootstrap process ---
TALOSCONFIG_DIR="${CONFIG_DIR}/${CLUSTER_NAME}/.talos"
KUBECONFIG_DIR="${CONFIG_DIR}/${CLUSTER_NAME}/.kube"

info "---------------------------------------------------"
info " --- Initializing bastion host --- "
info ""
info " > controlplane ip: ${CONTROLPLANE_IP}"
info " > talosconfig path: ${TALOSCONFIG_PATH}"
info " > talos config path: ${TALOSCONFIG_DIR}"
info " > kube config path: ${KUBECONFIG_DIR}"
info "---------------------------------------------------"

# --- Step 1. Create necessary directories ---
create_dir "${TALOSCONFIG_DIR}"
create_dir "${KUBECONFIG_DIR}"

# --- Step 1.2. Touch and export config path for talos and kube
touch "${TALOSCONFIG_DIR}/config"
touch "${KUBECONFIG_DIR}/config"
echo "export TALOSCONFIG=\"${TALOSCONFIG_DIR}/config\"" >> /root/.bashrc
echo "export KUBECONFIG=\"${KUBECONFIG_DIR}/config\"" >> /root/.bashrc
source /root/.bashrc

# --- Step 2. Copy talosconfig to .talos directory
cp "${TALOSCONFIG_PATH}" "${TALOSCONFIG_DIR}/config" || {
    warn "Failed to copy talosconfig from $TALOSCONFIG_PATH to $TALOSCONFIG_DIR/config"
    exit 1
}
info "Copied talosconfig from $TALOSCONFIG_PATH to $TALOSCONFIG_DIR/config"

# --- Step 3. Install required CLI tools
# apt update > /dev/null 2>&1
# apt install git -y > /dev/null 2>&1

install_tool "talosctl" \
    "talosctl-linux-amd64" \
    "sha256sum.txt" \
    "https://github.com/siderolabs/talos/releases/download/${TALOSCTL_VERSION}"
talosctl version --client

install_tool "kubectl" \
    "kubectl" \
    "kubectl.sha256" \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64"
kubectl version --client

install_helm

# --- Step 4. Bootstrap cluster nodes ---
info "---------------------------------------------------"
info " --- Bootstraping cluster nodes (controlplane) --- "
info "---------------------------------------------------"

# --- Step 4.1. Add route to cluster subnet --- 
info "Adding route to cluster subnet, if not present ..."
ip route add "${CLUSTER_SUBNET}" dev eth1 2>/dev/null || echo ' --- Route may already exist --- '
ip route show

# --- Step 4.2. Bootstrap etcd and kubeapi on controlplane (talosctl)
info "Booting up cluster controlplane node ..."
talosctl --nodes "${CONTROLPLANE_IP}" bootstrap || {
    warn "Talos bootstrap failed."
    if talosctl --nodes "${CONTROLPLANE_IP}" etcd members > /dev/null 2>&1; then
        info "Cluster is already bootstrapped."
    else
        error "Talos bootstrap error."
        exit 1
    fi
}

talosctl config endpoint "${CONTROLPLANE_IP}"
# talosctl config node "${CONTROLPLANE_IP}"

# --- Step 4.3. Create kubeconfig and initialize kubectl
info "Generating kubeconfig for kubectl ..."
talosctl --nodes "${CONTROLPLANE_IP}" --talosconfig "$TALOSCONFIG_PATH" kubeconfig --merge --force

cat "${TALOSCONFIG_DIR}/config"
cat "${KUBECONFIG_DIR}/config"
info "Cluster is up and running !!!"

sleep 10
# kubectl --kubeconfig "${KUBECONFIG_DIR}/config" get nodes -o wide

# --- Step 5. Install components ---

# Label worker nodes: 
for (( i=0; i<WORKERS; i++ )); do
    node="${CLUSTER_NAME}-worker-${i}"
    if kubectl get node "$node" >/dev/null 2>&1; then
        kubectl label node "$node" node-role.kubernetes.io/worker="" --overwrite || warn "Failed to label $node"
        info "Labeled node $node as worker"
    else
        warn "Node $node not found, skipping"
    fi
done

# --- Step 5.1 Install CNI plugin: Calico
info "Installing component: CNI plugin"

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml
curl -O https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/custom-resources.yaml
sed -i "s|192.168.0.0/16|$POD_CIDR|g" custom-resources.yaml
kubectl create -f custom-resources.yaml
info "Installed component: CNI plugin successfully"

# talosctl --nodes "${CONTROLPLANE_IP}" health
info "---------------------------------------------------"
info " --- Bootstrap process completed. --- "
info "---------------------------------------------------"
# ------------------------------------------------------------------------------
