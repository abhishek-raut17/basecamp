##################################################################################
#
# Bootstrap Module Variables
#
# Variables:
#   - infra:                    Infrastructure name
#   - region:                   Linode cluster region
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

## Github PAT for fluxcd git access
variable "git_token" {
  description = "Github PAT for fluxcd git access"
  type        = string
}

## Number of worker nodes
variable "workers_count" {
  description = "Number of worker nodes in the cluster"
  type        = number
}

## Cluster Subnet CIDR
variable "cluster_subnet" {
  description = "CIDR block for the Cluster subnet"
  type        = string
}

## Bootstrap components
variable "components" {
  description = "Map of bootstrap components and their configurations"
  type = map(object({
    firewall_id = string
    entity_ids  = list(string)
    config_ids = optional(object({
      http         = number
      https        = number
      kubectl_api  = number
      talosctl_api = number
    }))
  }))
}

# Bastion bootstrap details
variable "bastion_bootstrap" {
  description = "SSH and bootstrap details for the bastion host"
  sensitive   = false
  type = object({
    public_ip       = string
    private_key     = string
    controlplane_ip = string
  })
}
# ------------------------------------------------------------------------------