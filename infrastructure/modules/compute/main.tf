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

data "local_file" "cp_machineconfig" {
  filename = "${local.machineconfig_dir}/controlplane.machineconfig.yaml"
}

data "local_file" "wkr_machineconfig" {
  count    = length(var.workers_ip)
  filename = "${local.machineconfig_dir}/worker-${count.index}.machineconfig.yaml"
}

locals {

  cluster_node_disk_size = data.linode_instance_type.node_type.disk
  storage_disk_size      = (data.linode_instance_type.node_type.disk - 20480) > 0 ? (data.linode_instance_type.node_type.disk - 20480) : 20480

  cluster_image_id = data.linode_image.node_image.id
  cluster_node_id  = data.linode_instance_type.node_type.id

  machineconfig_dir = "${path.module}/../prereq/lib/machineconfigs"
}

# ------------------------------------------------------------------------------
# Control Plane Node: Provisions control plane node(s) for k8s cluster
# ------------------------------------------------------------------------------
resource "linode_instance" "control_plane" {
  depends_on = [
    data.linode_instance_type.node_type,
    data.local_file.cp_machineconfig
  ]

  label      = "${var.infra}-control-plane"
  region     = var.region
  type       = local.cluster_node_id
  private_ip = true

  metadata {
    user_data = data.local_file.cp_machineconfig.content_base64
  }

  tags = ["test", "cluster", "control-plane", "${var.infra}"]
}

# ------------------------------------------------------------------------------
# Worker Nodes: Provisions worker node(s) for k8s cluster; default: 3 nodes
# ------------------------------------------------------------------------------
resource "linode_instance" "worker" {
  count = length(var.workers_ip)

  depends_on = [
    data.linode_instance_type.node_type,
    data.local_file.wkr_machineconfig
  ]

  label      = "${var.infra}-worker-${count.index}"
  region     = var.region
  type       = local.cluster_node_id
  private_ip = true

  metadata {
    user_data = data.local_file.wkr_machineconfig[count.index].content_base64
  }

  tags = ["test", "cluster", "worker-${count.index}", "${var.infra}"]
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
  count      = length(var.workers_ip)
  label      = "${var.infra}-boot-disk-wkr-${count.index}"
  linode_id  = linode_instance.worker[count.index].id
  size       = 20480 # default boot disk size: 20GB for worker nodes
  image      = local.cluster_image_id
  filesystem = "raw"
}

# ------------------------------------------------------------------------------
# Raw Disk (Worker Nodes): Provisions raw disk for worker nodes for k8s data
# ------------------------------------------------------------------------------
resource "linode_instance_disk" "wkr_storage_disk" {
  count      = length(var.workers_ip)
  label      = "${var.infra}-storage-disk-wkr-${count.index}"
  linode_id  = linode_instance.worker[count.index].id
  size       = local.storage_disk_size
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
      vpc     = var.controlplane_ip
      nat_1_1 = "any"
    }
  }
}

# ------------------------------------------------------------------------------
# Boot config (Worker nodes): Attach boot disk and interface to worker nodes
# ------------------------------------------------------------------------------
resource "linode_instance_config" "wkr_boot_config" {
  count     = length(var.workers_ip)
  label     = "${var.infra}-wkr-${count.index}-boot-config"
  linode_id = linode_instance.worker[count.index].id
  booted    = true
  kernel    = "linode/direct-disk"

  # Boot helpers must be disabled for Talos
  helpers {
    updatedb_disabled  = true
    distro             = false
    modules_dep        = false
    network            = false
    devtmpfs_automount = false
  }

  device {
    device_name = "sda"
    disk_id     = linode_instance_disk.wkr_boot_disk[count.index].id
  }

  device {
    device_name = "sdb"
    disk_id     = linode_instance_disk.wkr_storage_disk[count.index].id
  }

  interface {
    purpose   = "vpc"
    subnet_id = var.subnet_id
    ipv4 {
      vpc     = var.workers_ip[count.index]
      nat_1_1 = "any"
    }
  }
}

# ------------------------------------------------------------------------------
# Bootstrap cluster
# ------------------------------------------------------------------------------
# resource "terraform_data" "bootstrap_cluster" {
#   depends_on = [
#     linode_instance.control_plane,
#     linode_instance.worker,
#     linode_instance_config.cp_boot_config,
#     linode_instance_config.wkr_boot_config
#   ]

#   triggers_replace = {
#     controlplane   = linode_instance.control_plane.id
#     workers        = linode_instance.worker.*.id
#     cp_bootconfig  = linode_instance_config.cp_boot_config.id
#     wkr_bootconfig = linode_instance_config.wkr_boot_config.*.id
#   }

#   connection {
#     type        = "ssh"
#     host        = var.bastion_ip
#     user        = "root"
#     private_key = var.ssh_private_key
#     timeout     = "2m"
#   }

#   # Bootstrap cluster by running talosctl init script on bastion
#   provisioner "remote-exec" {
#     inline = [
#       "cd /root/${var.infra}/.configs/.talos",
#       "chmod 0750 init.sh",
#       "./init.sh ${var.controlplane_ip}"
#     ]
#   }
# }
# ------------------------------------------------------------------------------
