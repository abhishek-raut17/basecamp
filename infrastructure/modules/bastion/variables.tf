##################################################################################
#
# Bastion Module Variables
#
# Variables:
#   - infra:                    Infrastructure name
#   - region:                   Linode cluster region
#   - ssh_key:                  SSH public key to access instances
#   - node_type:                Linode instance type for bastion host
#   - node_img:                 Linode instance image for bastion host
#   - subnet_id:                Subnet ID for bastion host
#   - firewall_id:              Firewall ID to attach to bastion host
##################################################################################

## Infrastructure name
variable "infra" {
  description = "Infrastructure Name"
  type        = string
}

## Linode Region
variable "region" {
  description = "Linode Region"
  type        = string
}

## SSH Public Key
variable "ssh_key" {
  description = "SSH Key to access instances"
  type        = string
  sensitive   = true
}

## SSH Private Key
variable "private_key" {
  description = "SSH Private Key to access bastion host"
  type        = string
  sensitive   = true
}

## Devops SSH Private Key
variable "devops_cd_sshkey" {
  description = "SSH Private Key to bootstrap fluxcd"
  type        = string
  sensitive   = true
}

## Instance Type
variable "nodetype" {
  description = "The type (category) of compute node instance for bastion host"
  type        = string
}

## Nodes image; default: Debian 12
variable "nodeimage" {
  description = "Base Linux Image for instances"
  type        = string
}

# ## Version ID for talosctl
# variable "talosctl_version" {
#   description = "Version ID for talosctl"
#   type        = string
# }

# ## Version ID for kubectl
# variable "kubectl_version" {
#   description = "Version ID for kubectl"
#   type        = string
# }

## Cluster endpoint
variable "cluster_endpoint" {
  description = "Controlplane endpoint for cluster access"
  type        = string
}

## VPC IPV4 for bastion node
variable "vpc_ip" {
  description = "VPC IPV4 for bastion node"
  type        = string
}

## Subnet ID for bastion host
variable "subnet_id" {
  description = "Subnet ID for bastion host"
  type        = string
}

## Cluster Subnet CIDR
variable "cluster_subnet" {
  description = "CIDR block for the Cluster subnet"
  type        = string
}

## Firewall ID for bastion host
variable "firewall_id" {
  description = "Firewall ID for bastion host"
  type        = string
}

## Git repository for deployment manifests
variable "git_repo" {
  description = "Git repository for deployment manifests"
  type        = string
}
# ------------------------------------------------------------------------------