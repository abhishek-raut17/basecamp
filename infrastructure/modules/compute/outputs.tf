##################################################################################
# Compute Module Outputs
#
# Exposes key resource attributes for use by other modules or the root module:
#   - bastion_public_ip:     Public IPV4 address for bastion host
#   - 
##################################################################################

output "controlplane_node_id" {
  depends_on = [
    linode_instance.control_plane,
    linode_instance_config.cp_boot_config
  ]
  description = "Controlplane details"
  value       = linode_instance.control_plane.id
}

output "worker_node_ids" {
  depends_on = [
    linode_instance.worker,
    linode_instance_config.wkr_boot_config
  ]
  description = "Worker nodes details"
  value       = linode_instance.worker.*.id
}
# ------------------------------------------------------------------------------
