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

output "loadbalancer_details" {
  description = "Loadbalancer: Gateway loadbalancer details"
  value       = module.loadbalancer.loadbalancer_details
}

output "security_details" {
  description = "Security: Firewalls details"
  value       = module.security.security_details
}

output "prereq_details" {
  description = "Prereq: Node metadata and machineconfig details"
  value       = module.prereq.prereq_details
}

# output "bastion-bastion_details" {
#   description = "Bastion host details"
#   value       = module.bastion.bastion_details
# }

# output "bootstrap-controlplane_node" {
#   description = "Controlplane network details"
#   value       = module.bootstrap.controlplane_node
# }

# output "bootstrap-worker_nodes" {
#   description = "Worker nodes network details"
#   value       = module.bootstrap.worker_nodes
# }
# ------------------------------------------------------------------------------