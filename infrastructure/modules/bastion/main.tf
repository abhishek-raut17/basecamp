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

  talosconfig        = trimspace(chomp("${path.module}/../prereq/lib/generated/talosconfig"))
  talosctl_bootstrap = trimspace(chomp("${path.module}/../prereq/lib/scripts/talosctl_bootstrap.sh"))
}

data "linode_instance_networking" "bastion_network" {
  depends_on = [linode_instance.bastion]
  linode_id  = linode_instance.bastion.id
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
# Install talosctl on bastion host and copy machine config files
# ------------------------------------------------------------------------------
# data "local_file" "talosconfig" {
#   filename = local.talosconfig
# }

# resource "terraform_data" "setup_bastion" {
#   depends_on = [
#     linode_instance.bastion,
#     linode_firewall_device.bastion_fw_device,
#     data.local_file.talosconfig
#   ]

#   triggers_replace = {
#     bastion_id       = linode_instance.bastion.id,
#     talosconfig_hash = data.local_file.talosconfig.content_md5
#   }

#   connection {
#     type        = "ssh"
#     host        = local.public_ip
#     user        = "root"
#     private_key = var.ssh_private_key
#     timeout     = "2m"
#   }

#   # Step 1: Create route to cluster subnet if it doesnt exist
#   provisioner "remote-exec" {
#     inline = [
#       "ip route add ${var.cluster_subnet} dev eth1 2>/dev/null || echo ' --- Route may already exist --- '",
#       "ip route show"
#     ]
#   }

#   # Step 2: Install the required toolset for cluster management (talosctl and kubectl)
#   provisioner "remote-exec" {
#     inline = [
#       "mkdir -m 0755 -p /root/${var.infra}/.configs/.talos /root/${var.infra}/.configs/.kube",
#       "touch /root/${var.infra}/.configs/.talos/config",
#       "touch /root/${var.infra}/.configs/.kube/config",
#       "echo 'export TALOSCONFIG=/root/${var.infra}/.configs/.talos/config' >> /root/.bashrc",
#       "echo 'export KUBECONFIG=/root/${var.infra}/.configs/.kube/config' >> /root/.bashrc",
#       "cd $(mktemp -d) && echo $(pwd)",
#       "curl -LO https://github.com/siderolabs/talos/releases/download/${var.talosctl_version}/talosctl-linux-amd64",
#       "curl -LO https://github.com/siderolabs/talos/releases/download/${var.talosctl_version}/sha256sum.txt",
#       "curl -LO https://dl.k8s.io/release/${var.kubectl_version}/bin/linux/amd64/kubectl",
#       "curl -LO https://dl.k8s.io/release/${var.kubectl_version}/bin/linux/amd64/kubectl.sha256",
#       "grep talosctl-linux-amd64 sha256sum.txt | sha256sum -c -",
#       "echo $(cat kubectl.sha256) kubectl | sha256sum -c -",
#       "chmod 0750 talosctl-linux-amd64 kubectl",
#       "mv talosctl-linux-amd64 /usr/local/bin/talosctl",
#       "mv kubectl /usr/local/bin/kubectl",
#       "talosctl version --client",
#       "kubectl version --client"
#     ]
#   }

#   # Step 3: Send talosconfig file to bastion to use later
#   provisioner "file" {
#     source      = local.talosconfig
#     destination = "/root/${var.infra}/.configs/.talos/config"
#   }

#   # Step 4: Send talosctl_bootstrap file to bastion to use later
#   provisioner "file" {
#     source      = local.talosctl_bootstrap
#     destination = "/root/${var.infra}/.configs/.talos/init.sh"
#   }
# }
# ------------------------------------------------------------------------------