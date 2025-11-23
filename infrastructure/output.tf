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

output "network-vpc_details" {
  description = "VPC and subnet details"
  value       = module.network.vpc_details
}

output "loadbalancer-gateway_lb_details" {
  description = "Gateway loadbalancer details"
  value       = module.loadbalancer.loadbalancer_details
}

output "security-firewall_details" {
  description = "Firewalls details"
  value       = module.security.firewall_details
}

output "bastion-bastion_details" {
  description = "Bastion host details"
  value       = module.bastion.bastion_details
}

output "bootstrap-controlplane_node" {
  description = "Controlplane network details"
  value       = module.bootstrap.controlplane_node
}

output "bootstrap-worker_nodes" {
  description = "Worker nodes network details"
  value       = module.bootstrap.worker_nodes
}
# ------------------------------------------------------------------------------