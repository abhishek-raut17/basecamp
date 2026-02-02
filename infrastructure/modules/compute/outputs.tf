##################################################################################
# Compute Module Outputs
#
# Exposes key resource attributes for use by other modules or the root module:
#   - compute_details:     Public IPV4 address for bastion host
##################################################################################

output "compute_details" {
  depends_on = [
    linode_instance.control_plane,
    linode_instance.worker,
    linode_instance_config.cp_boot_config,
    linode_instance_config.wkr_boot_config
  ]
  description = "Compute details for cluster nodes"
  value = {
    controlplane = linode_instance.control_plane.id,
    workers      = [for wkr in linode_instance.worker : wkr.id]
  }
}

# ------------------------------------------------------------------------------
