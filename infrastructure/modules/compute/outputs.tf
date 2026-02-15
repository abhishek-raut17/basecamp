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
    linode_instance.dmz,
    linode_instance_config.cp_boot_config,
    linode_instance_config.wkr_boot_config,
    linode_firewall_device.controlplane_node_fw_device,
    linode_firewall_device.wkr_node_fw_device,
    linode_firewall_device.dmz_node_fw_device
  ]
  description = "Compute details for cluster and DMZ nodes"
  value = {
    controlplane = [for cp in linode_instance.control_plane : {
      id     = cp.id
      ipv4   = cp.ipv4
      type   = cp.type
      image  = cp.image
      region = cp.region
      status = cp.status
    }]
    worker = [for wkr in linode_instance.worker : {
      id     = wkr.id
      ipv4   = wkr.ipv4
      type   = wkr.type
      image  = wkr.image
      region = wkr.region
      status = wkr.status
    }]
    dmz = {
      id     = linode_instance.dmz.id
      ipv4   = linode_instance.dmz.ipv4
      type   = linode_instance.dmz.type
      image  = linode_instance.dmz.image
      region = linode_instance.dmz.region
      status = linode_instance.dmz.status
    }
  }
}

# ------------------------------------------------------------------------------
