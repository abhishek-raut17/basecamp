##################################################################################
#
# Root Module Outputs
#
# Exposes outputs from all following modules
#   - vpc_id
#   - subnet_cluster
#   - subnet_dmz
#   - 
##################################################################################

output "network_details" {
  description = "Network: VPC and subnet details"
  value       = module.network.network_details
}

output "security_details" {
  description = "Security: Firewalls details"
  value       = module.security.security_details
}

output "compute_details" {
  description = "Compute: Cluster node details"
  value       = module.compute.compute_details
}

# ------------------------------------------------------------------------------