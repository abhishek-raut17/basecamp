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
# ------------------------------------------------------------------------------