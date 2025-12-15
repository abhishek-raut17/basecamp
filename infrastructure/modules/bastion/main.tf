################################################################################
# Project: BaseCamp
# Bastion Module
#
# Provisions bastion host resources on Linode for secured access to cluster:
#   - Creates new Linode instance as bastion host
#   - Attaches firewall to bastion host
#   - Installs and configures Squid proxy on bastion host for cluster subnet proxy
#
# Inputs:
#   - project_name:             Project name
#   - region:                   Linode cluster region
#   - ssh_key:                  SSH public key to access instances
#   - node_type:                Linode instance type for bastion host
#   - node_img:                 Linode instance image for bastion host
#   - subnet_id:                Subnet ID for bastion host
#   - firewall_id:              Firewall ID to attach to bastion host
#
# Outputs:
#   - bastion_id:               Linode instance ID of bastion host
#   - bastion_public_ip:        Public IP address of bastion host
#   - bastion_private_ip:       Private IP address of bastion host
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

  # Bastion IPs
  vpc_ip = trimspace(chomp(var.vpc_ip))
  public_ip = [for ipv in data.linode_instance_networking.bastion_network.ipv4 :
  ipv.public[0].address if ipv.public != []][0]

  # Paths to files to copy to bastion
  generated_dir = trimspace(chomp("${path.module}/../../../manifests/generated"))
  talosconfig   = trimspace(chomp("${local.generated_dir}/talosconfig"))
  bastion_initd = trimspace(chomp("${path.module}/initd"))
}

data "linode_instance_networking" "bastion_network" {
  depends_on = [linode_instance.bastion]
  linode_id  = linode_instance.bastion.id
}

data "local_file" "talosconfig" {
  filename = local.talosconfig
}

data "local_file" "init" {
  filename = "${local.bastion_initd}/init.sh"
}

# ------------------------------------------------------------------------------
# Admin SSH Key: Import admin's SSH public key for secure access to bastion host
# ------------------------------------------------------------------------------
resource "linode_sshkey" "admin_sshkey" {
  label   = "${var.infra}-admin-access-sshkey"
  ssh_key = var.ssh_key
}

# ------------------------------------------------------------------------------
# Provision bastion host for secured access to cluster and NAT gateway
# ------------------------------------------------------------------------------
resource "linode_instance" "bastion" {
  label           = "${var.infra}-bastion"
  region          = var.region
  type            = var.nodetype
  image           = var.nodeimage
  root_pass       = null
  authorized_keys = [var.ssh_key]

  interface {
    purpose = "public"
    primary = true
  }

  interface {
    purpose   = "vpc"
    subnet_id = var.subnet_id
    ipv4 {
      vpc = local.vpc_ip
    }
  }

  tags = [var.infra, "bastion"]
}

# ------------------------------------------------------------------------------
# Attach Firewall (Bastion host): Attach firewall to bastion host
# ------------------------------------------------------------------------------
resource "linode_firewall_device" "bastion_fw_device" {
  firewall_id = var.firewall_id
  entity_id   = linode_instance.bastion.id
}

# ------------------------------------------------------------------------------
# Install talosctl on bastion host and copy machine config files
# ------------------------------------------------------------------------------
resource "terraform_data" "setup_bastion" {
  depends_on = [
    linode_instance.bastion,
    linode_firewall_device.bastion_fw_device,
    data.local_file.talosconfig,
    data.local_file.init
  ]

  triggers_replace = {
    bastion_id        = linode_instance.bastion.id,
    talosconfig_hash  = data.local_file.talosconfig.content_md5,
    bastion_init_hash = data.local_file.init.content_md5
  }

  connection {
    type        = "ssh"
    host        = local.public_ip
    user        = "root"
    private_key = var.private_key
    timeout     = "2m"
  }

  # Step 1: Send talosconfig file to bastion to use with talosctl
  provisioner "file" {
    source      = local.talosconfig
    destination = "/tmp/talosconfig"
  }

  # Step 2: Send initd dir to bastion to use to setup bastion for cluster access
  provisioner "file" {
    source      = local.bastion_initd
    destination = "/usr/local/bin"
  }

  # Step 3: Set execute permissions on initd scripts
  provisioner "remote-exec" {
    inline = [
      "chmod 0750 /usr/local/bin/initd/*"
    ]
  }

  # Step 4: Run initd script to setup bastion for cluster access
  provisioner "remote-exec" {
    inline = [
      "/usr/local/bin/initd/init.sh --cluster-endpoint ${var.cluster_endpoint} --cluster-subnet ${var.cluster_subnet}"
    ]
  }
}

# ------------------------------------------------------------------------------