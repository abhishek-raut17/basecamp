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

## Cluster Subnet ID for cluster nodes
variable "subnet_id" {
  description = "ID of the Cluster subnet"
  type        = string
}

## Static VPC ipv4 for controlplane node
variable "vpc_ip" {
  description = "Static VPC ipv4 for cluster node"
  type = object({
    controlplane = string,
    workers      = list(string)
  })
}

## Firewall ID for cluster nodes
variable "firewall_id" {
  description = "Firewall rule ID for cluster nodes"
  type        = string
}

## Cloud-init styled user data for node configuration
variable "node_userdata" {
  description = "Cloud-init styled user data for node configuration"
  type = object({
    controlplane = object({
      filename = string,
      content  = string
    }),
    workers = list(object({
      filename = string,
      content  = string
    }))
  })
}

# ------------------------------------------------------------------------------