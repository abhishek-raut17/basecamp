################################################################################
# Project: BaseCamp
# Compute Module
#
# Provisions core computing resources on Linode:
#   - Bastion host(s) for secured maintainance access to cluster nodes
#   - Private nodes to host k8s cluster
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

data "linode_instance_type" "node_type" {
  id = var.nodetype
}

data "linode_image" "node_image" {
  id = var.nodeimage
}

locals {

  cluster_node_disk_size = data.linode_instance_type.node_type.disk
  storage_disk_size      = (data.linode_instance_type.node_type.disk - 20480) > 0 ? (data.linode_instance_type.node_type.disk - 20480) : 20480

  cluster_image_id = data.linode_image.node_image.id
  cluster_node_id  = data.linode_instance_type.node_type.id

  controlplane_userdata = base64encode(var.node_userdata.controlplane.content)
  workers_userdata      = [for w in var.node_userdata.workers : base64encode(w.content)]

}

# ------------------------------------------------------------------------------
# Control Plane Node: Provisions control plane node(s) for k8s cluster
# ------------------------------------------------------------------------------
resource "linode_instance" "control_plane" {
  depends_on = [
    data.linode_instance_type.node_type,
    local.controlplane_userdata
  ]

  label  = "${var.infra}-control-plane"
  region = var.region
  type   = local.cluster_node_id

  metadata {
    user_data = local.controlplane_userdata
  }

  tags = ["control-plane"]
}

# ------------------------------------------------------------------------------
# Worker Nodes: Provisions worker node(s) for k8s cluster; default: 3 nodes
# ------------------------------------------------------------------------------
resource "linode_instance" "worker" {
  count = length(var.vpc_ip.workers)

  depends_on = [
    data.linode_instance_type.node_type,
    local.workers_userdata
  ]

  label  = "${var.infra}-worker-${count.index}"
  region = var.region
  type   = local.cluster_node_id

  metadata {
    user_data = local.workers_userdata[count.index]
  }

  tags = ["worker-${count.index}"]
}

# ------------------------------------------------------------------------------
# Primary Disk (Control-Plane): Provisions boot disk for control-plane
# ------------------------------------------------------------------------------
resource "linode_instance_disk" "cp_boot_disk" {
  label      = "${var.infra}-boot-disk-cp"
  linode_id  = linode_instance.control_plane.id
  size       = local.cluster_node_disk_size
  image      = local.cluster_image_id
  filesystem = "raw"
}

# ------------------------------------------------------------------------------
# Primary Disk (Worker Nodes): Provisions boot disk for worker nodes
# ------------------------------------------------------------------------------
resource "linode_instance_disk" "wkr_boot_disk" {
  count      = length(var.vpc_ip.workers)
  label      = "${var.infra}-boot-disk-wkr-${count.index}"
  linode_id  = linode_instance.worker[count.index].id
  size       = local.cluster_node_disk_size
  image      = local.cluster_image_id
  filesystem = "raw"
}

# ------------------------------------------------------------------------------
# Boot config (Control-Plane): Attach boot disk and interface to control-plane
# ------------------------------------------------------------------------------
resource "linode_instance_config" "cp_boot_config" {
  depends_on = [linode_instance_disk.cp_boot_disk]
  label      = "${var.infra}-cp-boot-config"
  linode_id  = linode_instance.control_plane.id

  # Boot helpers must be disabled for Talos
  helpers {
    updatedb_disabled  = true
    distro             = false
    modules_dep        = false
    network            = false
    devtmpfs_automount = false
  }

  root_device = "/dev/sda"
  booted      = true
  kernel      = "linode/direct-disk"

  device {
    device_name = "sda"
    disk_id     = linode_instance_disk.cp_boot_disk.id
  }

  interface {
    purpose   = "vpc"
    subnet_id = var.subnet_id
    ipv4 {
      vpc     = var.vpc_ip.controlplane
      nat_1_1 = "any"
    }
  }
}

# ------------------------------------------------------------------------------
# Boot config (Worker nodes): Attach boot disk and interface to worker nodes
# ------------------------------------------------------------------------------
resource "linode_instance_config" "wkr_boot_config" {
  depends_on = [linode_instance_disk.wkr_boot_disk]
  count      = length(var.vpc_ip.workers)
  label      = "${var.infra}-wkr-${count.index}-boot-config"
  linode_id  = linode_instance.worker[count.index].id


  # Boot helpers must be disabled for Talos
  helpers {
    updatedb_disabled  = true
    distro             = false
    modules_dep        = false
    network            = false
    devtmpfs_automount = false
  }

  root_device = "/dev/sda"
  booted      = true
  kernel      = "linode/direct-disk"

  device {
    device_name = "sda"
    disk_id     = linode_instance_disk.wkr_boot_disk[count.index].id
  }

  interface {
    purpose   = "vpc"
    subnet_id = var.subnet_id
    ipv4 {
      vpc     = var.vpc_ip.workers[count.index]
      nat_1_1 = "any"
    }
  }
}

# ------------------------------------------------------------------------------
# Control plane firewall: Attach control plane node to cluster subnet firewall
# ------------------------------------------------------------------------------
resource "linode_firewall_device" "controlplane_fw_device" {
  firewall_id = var.firewall_id
  entity_id   = linode_instance.control_plane.id
}

# ------------------------------------------------------------------------------
# Worker nodes firewall: Attach worker nodes to cluster subnet firewall
# ------------------------------------------------------------------------------
resource "linode_firewall_device" "wkr_node_fw_device" {
  count       = length(var.vpc_ip.workers)
  firewall_id = var.firewall_id
  entity_id   = linode_instance.worker[count.index].id
}

# ------------------------------------------------------------------------------
