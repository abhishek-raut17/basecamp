##################################################################################
#
# Prereq Module Variables
#
# Variables:
#   - infra:                    Infrastructure name
##################################################################################

## Infrastructure name
variable "infra" {
  description = "Infrastructure Name"
  type        = string
}

## Public IPV4 address for nodebalancer which accesses controlplane node
variable "cluster_ip" {
  description = "Public IPV4 address for nodebalancer node"
  type        = string
}

## Number of worker nodes in the cluster
variable "worker_count" {
  description = "Number of worker nodes in the cluster"
  type        = number
}
# ------------------------------------------------------------------------------