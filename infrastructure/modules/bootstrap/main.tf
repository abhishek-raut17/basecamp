################################################################################
# Project: BaseCamp
# Bootstrap Module
#
# Bootraps k8s cluster on Linode:
#   - Attaches firewalls to cluster nodes and nodebalancers
#   - Adds backend nodes (private ipv4) to nodebalancer
#   - Adds DNS records for cluster access
#
# Inputs:
#   - project_name:             Project name
#   - region:                   Linode cluster region
#   - ssh_key:                  SSH public key to access instances
#   - node_img:                 Linux Image label
#   - talos_img:                Talos OS Image ID
#   - cluster_node_type_id:     Compute instance type for cluster nodes
#   - bastion_node_type_id:     Compute instance type for bastion host
#   - dmz_subnet_id:            ID of the DMZ subnet
#   - cluster_subnet_id:        ID of the Cluster subnet
#   - worker_node_count:        Number of worker nodes in the cluster
#
# Outputs:
#   - Bastion host node ID and public IP
#   - Control plane and worker node IDs and private IPs
################################################################################

terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.2.0"
    }
  }
  required_version = ">= 1.0.0"
}

locals {

  talosconfig = trimspace(chomp("${path.module}/../prereq/lib/generated/talosconfig"))
  bootstrap_d = trimspace(chomp("${path.module}/../../lib/bootstrap"))

  gateway_firewall_id = var.components.gateway.firewall_id
  gateway_entity_ids  = try(var.components.gateway.entity_ids, [])

  cluster_firewall_id     = var.components.controlplane.firewall_id
  controlplane_entity_ids = try(var.components.controlplane.entity_ids, [])
  workers_entity_ids      = try(var.components.workers.entity_ids, [])
  workers_count           = length(local.workers_entity_ids)

  bastion_firewall_id = var.components.bastion.firewall_id
  bastion_entity_ids  = try(var.components.bastion.entity_ids, [])

  controlplane_vpc_ip = var.bastion_bootstrap.controlplane_ip
  controlplane_private_ip = [for net in data.linode_instance_networking.cp_network.ipv4 :
  net.private[0].address if net.private != []][0]
  workers_private_ips = [
    for idx in range(length(data.linode_instance_networking.wkr_network)) :
    [for net in data.linode_instance_networking.wkr_network[idx].ipv4 :
    net.private[0].address if net.private != []][0]
  ]
}

data "local_file" "talosconfig" {
  filename = local.talosconfig
}

data "linode_instance_networking" "cp_network" {
  linode_id = local.controlplane_entity_ids[0]
}

data "linode_instance_networking" "wkr_network" {
  count     = var.workers_count
  linode_id = local.workers_entity_ids[count.index]
}

# ------------------------------------------------------------------------------
# Loadbalancer firewall: Attach nodebalancer to dmz firewall
# ------------------------------------------------------------------------------
resource "linode_firewall_device" "loadbalancer_fw_device" {

  firewall_id = local.gateway_firewall_id
  entity_id   = local.gateway_entity_ids[0]
  entity_type = "nodebalancer"
}

# ------------------------------------------------------------------------------
# Attach Firewall (Bastion host): Attach firewall to bastion host
# ------------------------------------------------------------------------------
resource "linode_firewall_device" "bastion_fw_device" {
  firewall_id = local.bastion_firewall_id
  entity_id   = local.bastion_entity_ids[0]
}

# ------------------------------------------------------------------------------
# Control plane firewall: Attach control plane node to cluster subnet firewall
# ------------------------------------------------------------------------------
resource "linode_firewall_device" "cp_fw_device" {

  firewall_id = local.cluster_firewall_id
  entity_id   = local.controlplane_entity_ids[0]
}

# ------------------------------------------------------------------------------
# Worker nodes firewall: Attach worker nodes to cluster subnet firewall
# ------------------------------------------------------------------------------
resource "linode_firewall_device" "wkr_fw_device" {

  count       = var.workers_count
  firewall_id = local.cluster_firewall_id
  entity_id   = local.workers_entity_ids[count.index]
}

# ------------------------------------------------------------------------------
# Configure nodebalancer backend nodes
# ------------------------------------------------------------------------------
resource "linode_nodebalancer_node" "http_nodes" {
  count           = var.workers_count
  nodebalancer_id = local.gateway_entity_ids[0]
  config_id       = var.components.gateway.config_ids.http
  address         = "${local.workers_private_ips[count.index]}:80"
  label           = "${var.infra}-${count.index}-http-port-lb"
  weight          = 100
  mode            = "accept"
}

resource "linode_nodebalancer_node" "https_nodes" {
  count           = var.workers_count
  nodebalancer_id = local.gateway_entity_ids[0]
  config_id       = var.components.gateway.config_ids.https
  address         = "${local.workers_private_ips[count.index]}:443"
  label           = "${var.infra}-${count.index}-https-port-lb"
  weight          = 100
  mode            = "accept"
}

resource "linode_nodebalancer_node" "kubectlapi_nodes" {
  nodebalancer_id = local.gateway_entity_ids[0]
  config_id       = var.components.gateway.config_ids.kubectl_api
  address         = "${local.controlplane_private_ip}:6443"
  label           = "${var.infra}-kubectlapi-port-lb"
  weight          = 100
  mode            = "accept"
}

resource "linode_nodebalancer_node" "talosctlapi_nodes" {
  nodebalancer_id = local.gateway_entity_ids[0]
  config_id       = var.components.gateway.config_ids.talosctl_api
  address         = "${local.controlplane_private_ip}:50000"
  label           = "${var.infra}-talosctlapi-port-lb"
  weight          = 100
  mode            = "accept"
}

# ------------------------------------------------------------------------------
# Install talosctl on bastion host and copy machine config files
# ------------------------------------------------------------------------------
resource "terraform_data" "setup_bastion" {
  depends_on = [
    linode_firewall_device.bastion_fw_device,
    linode_firewall_device.loadbalancer_fw_device,
    linode_firewall_device.cp_fw_device,
    linode_firewall_device.wkr_fw_device,
    data.local_file.talosconfig
  ]

  triggers_replace = {
    talosconfig_hash = data.local_file.talosconfig.content_md5
    init_hash        = filesha256("${local.bootstrap_d}/init.sh")
  }

  connection {
    type        = "ssh"
    host        = var.bastion_bootstrap.public_ip
    user        = "root"
    private_key = var.bastion_bootstrap.private_key
    timeout     = "2m"
  }

  # Step 1: Send talosconfig file to bastion to use for talosctl access
  provisioner "file" {
    source      = local.talosconfig
    destination = "/tmp/talosconfig"
  }

  # Step 2: Send talosctl_bootstrap file to bastion to use for initial cluster setup
  provisioner "file" {
    source      = local.bootstrap_d
    destination = "/tmp"
  }

  # Step 3: Install the required toolset for cluster management (talosctl and kubectl)
  provisioner "remote-exec" {
    inline = [
      "cd /tmp/bootstrap",
      "chmod 750 ./init.sh",
      "./init.sh --cluster ${var.infra} --cluster-subnet ${var.cluster_subnet} --controlplane ${local.controlplane_vpc_ip} --workers ${local.workers_count} --talosconfig /tmp/talosconfig --git-token '${var.git_token}'"
    ]
  }
}
# ------------------------------------------------------------------------------
