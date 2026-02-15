##################################################################################
#
# Compute Module Variables
#
# Variables:
#   - infra:                    Infrastructure name
#   - region:                   Linode cluster region
#   - ssh_key:                  SSH public key to access instances
#   - node_img:                 Linux Image label
#   - talos_img:                Talos OS Image ID
#   - cluster_node_type_id:     Compute instance type for cluster nodes
#   - bastion_node_type_id:     Compute instance type for bastion host
#   - dmz_subnet_id:            ID of the DMZ subnet
#   - cluster_subnet_id:        ID of the Cluster subnet
#   - worker_node_count:        Number of worker nodes in the cluster
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

## SSH Key to access DMZ nodes (public nodes)
variable "dmz_access_sshkey" {
  description = "Path to the SSH keys for admin access to DMZ nodes (default: ~/.ssh/id_rsa.pub)"
  type        = string
  sensitive   = true
}

## Nodes details: instance types, images and count for control plane, worker, and DMZ nodes
variable "nodes" {
  description = "Nodes details: instance types, images and count for control plane, worker, and DMZ nodes"
  type = object({
    controlplane = object({
      type  = string,
      image = string,
      count = number
    }),
    worker = object({
      type  = string,
      image = string,
      count = number
    }),
    dmz = object({
      type  = string,
      image = string,
      count = number
    })
  })
}

## Subnet details
variable "subnets" {
  description = "Subnet details for cluster and DMZ subnets"
  type = list(object({
    name = string,
    id   = string,
    cidr = string
  }))
}

## VPC ID for infrastructure
variable "vpc" {
  description = "VPC ID for infrastructure"
  type        = string
}

## Firewall ID for cluster nodes
variable "firewalls" {
  description = "Firewall rule for cluster and DMZ nodes"
  type = list(object({
    name = string,
    id   = string
  }))
}

## Cloud-init styled user data for node configuration
variable "userdata_dir" {
  description = "Cloud-init styled user data for node configuration"
  type        = string
}

# ------------------------------------------------------------------------------