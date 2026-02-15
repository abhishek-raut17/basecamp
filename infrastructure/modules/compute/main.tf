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

locals {
  cluster_subnet_id   = [for subnet in var.subnets : subnet.id if subnet.name == "cluster"][0]
  cluster_subnet      = [for subnet in var.subnets : subnet.cidr if subnet.name == "cluster"][0]
  dmz_subnet_id       = [for subnet in var.subnets : subnet.id if subnet.name == "dmz"][0]
  dmz_subnet          = [for subnet in var.subnets : subnet.cidr if subnet.name == "dmz"][0]
  cluster_firewall_id = [for fw in var.firewalls : fw.id if fw.name == "cluster"][0]
  dmz_firewall_id     = [for fw in var.firewalls : fw.id if fw.name == "dmz"][0]
}

data "linode_instance_type" "controlplane_node_type" {
  id = var.nodes.controlplane.type
}

data "linode_instance_type" "worker_node_type" {
  id = var.nodes.worker.type
}

data "linode_instance_type" "dmz_node_type" {
  id = var.nodes.dmz.type
}

data "linode_image" "controlplane_node_image" {
  id = var.nodes.controlplane.image
}

data "linode_image" "worker_node_image" {
  id = var.nodes.worker.image
}

data "linode_image" "dmz_node_image" {
  id = var.nodes.dmz.image
}

# ------------------------------------------------------------------------------
# DMZ Access SSH Key: Provisions SSH key for secure access to DMZ nodes (bastion/gateway)
# ------------------------------------------------------------------------------
resource "linode_sshkey" "access_key" {
  label   = "${var.infra}-dmz-access-key"
  ssh_key = var.dmz_access_sshkey
}

# ------------------------------------------------------------------------------
# Control Plane Node: Provisions control plane node(s) for k8s cluster
# ------------------------------------------------------------------------------
resource "linode_instance" "control_plane" {
  depends_on = [
    data.linode_instance_type.controlplane_node_type
  ]

  count  = var.nodes.controlplane.count
  label  = "${var.infra}-control-plane-${count.index}"
  region = var.region
  type   = data.linode_instance_type.controlplane_node_type.id

  metadata {
    user_data = base64encode(file("${var.userdata_dir}/controlplane-${count.index}.machineconfig.yaml"))
  }

  tags = ["control-plane-${count.index}"]
}

# ------------------------------------------------------------------------------
# Worker Nodes: Provisions worker node(s) for k8s cluster; default: 3 nodes
# ------------------------------------------------------------------------------
resource "linode_instance" "worker" {
  count = var.nodes.worker.count

  depends_on = [
    data.linode_instance_type.worker_node_type
  ]

  label  = "${var.infra}-worker-${count.index}"
  region = var.region
  type   = data.linode_instance_type.worker_node_type.id

  metadata {
    user_data = base64encode(file("${var.userdata_dir}/worker-${count.index}.machineconfig.yaml"))
  }

  tags = ["worker-${count.index}"]
}

# ------------------------------------------------------------------------------
# Provision DMZ/gateway host for secured access to cluster and gateway
# ------------------------------------------------------------------------------
resource "linode_instance" "dmz" {
  label           = "${var.infra}-dmz-gateway"
  region          = var.region
  type            = data.linode_instance_type.dmz_node_type.id
  image           = data.linode_image.dmz_node_image.id
  root_pass       = null
  authorized_keys = [linode_sshkey.access_key.ssh_key]

  interface {
    purpose = "public"
    primary = true
  }

  interface {
    purpose   = "vpc"
    subnet_id = local.dmz_subnet_id
    ipv4 {
      vpc = cidrhost(local.dmz_subnet, 50)
    }
  }

  tags = ["${var.infra}", "bastion", "gateway"]
}

# ------------------------------------------------------------------------------
# Primary Disk (Control-Plane): Provisions boot disk for control-plane
# ------------------------------------------------------------------------------
resource "linode_instance_disk" "cp_boot_disk" {
  count      = var.nodes.controlplane.count
  label      = "${var.infra}-boot-disk-cp-${count.index}"
  linode_id  = linode_instance.control_plane[count.index].id
  size       = linode_instance.control_plane[count.index].specs.0.disk
  image      = var.nodes.controlplane.image
  filesystem = "raw"
}

# ------------------------------------------------------------------------------
# Primary Disk (Worker Nodes): Provisions boot disk for worker nodes
# ------------------------------------------------------------------------------
resource "linode_instance_disk" "wkr_boot_disk" {
  count      = var.nodes.worker.count
  label      = "${var.infra}-boot-disk-wkr-${count.index}"
  linode_id  = linode_instance.worker[count.index].id
  size       = linode_instance.worker[count.index].specs.0.disk
  image      = var.nodes.worker.image
  filesystem = "raw"
}

# ------------------------------------------------------------------------------
# Boot config (Control-Plane): Attach boot disk and interface to control-plane
# ------------------------------------------------------------------------------
resource "linode_instance_config" "cp_boot_config" {
  depends_on = [linode_instance_disk.cp_boot_disk]
  count      = var.nodes.controlplane.count
  label      = "${var.infra}-cp-boot-config-${count.index}"
  linode_id  = linode_instance.control_plane[count.index].id

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
    disk_id     = linode_instance_disk.cp_boot_disk[count.index].id
  }

  interface {
    purpose   = "vpc"
    subnet_id = local.cluster_subnet_id
    ipv4 {
      vpc     = cidrhost(local.cluster_subnet, 10 + count.index)
      nat_1_1 = "any"
    }
  }
}

# ------------------------------------------------------------------------------
# Boot config (Worker nodes): Attach boot disk and interface to worker nodes
# ------------------------------------------------------------------------------
resource "linode_instance_config" "wkr_boot_config" {
  depends_on = [linode_instance_disk.wkr_boot_disk]
  count      = var.nodes.worker.count
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
    subnet_id = local.cluster_subnet_id
    ipv4 {
      vpc     = cidrhost(local.cluster_subnet, 532 + count.index)
      nat_1_1 = "any"
    }
  }
}

# ------------------------------------------------------------------------------
# Control plane firewall: Attach control plane node to cluster subnet firewall
# ------------------------------------------------------------------------------
resource "linode_firewall_device" "controlplane_node_fw_device" {
  count       = var.nodes.controlplane.count
  firewall_id = local.cluster_firewall_id
  entity_id   = linode_instance.control_plane[count.index].id
}

# ------------------------------------------------------------------------------
# Worker nodes firewall: Attach worker nodes to cluster subnet firewall
# ------------------------------------------------------------------------------
resource "linode_firewall_device" "wkr_node_fw_device" {
  count       = var.nodes.worker.count
  firewall_id = local.cluster_firewall_id
  entity_id   = linode_instance.worker[count.index].id
}

# ------------------------------------------------------------------------------
# DMZ nodes firewall: Attach DMZ nodes to cluster subnet firewall
# ------------------------------------------------------------------------------
resource "linode_firewall_device" "dmz_node_fw_device" {
  firewall_id = local.dmz_firewall_id
  entity_id   = linode_instance.dmz.id
}

# ------------------------------------------------------------------------------
