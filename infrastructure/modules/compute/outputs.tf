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

# output "controlplane_node" {
#   depends_on = [
#     linode_firewall_device.cp_fw_device
#   ]
#   description = "Controlplane details"
#   value = {
#     host_id = [for net in data.linode_instance_networking.cp_network.ipv4 : net.vpc[0].linode_id if net.vpc != []][0],
#     # private_ip = [for net in data.linode_instance_networking.cp_network.ipv4 : net.private[0].address if net.private != []][0],
#     vpc_ip  = [for net in data.linode_instance_networking.cp_network.ipv4 : net.vpc[0].address if net.vpc != []][0],
#     nat_1_1 = [for net in data.linode_instance_networking.cp_network.ipv4 : net.vpc[0].nat_1_1 if net.vpc != []][0],
#   }
# }

# output "worker_nodes" {
#   depends_on = [
#     linode_firewall_device.wkr_fw_device
#   ]
#   description = "Worker nodes details"
#   value = [
#     for wkr in data.linode_instance_networking.wkr_network :
#     {
#       host_id = [for net in wkr.ipv4 : net.vpc[0].linode_id if net.vpc != []][0],
#       # private_ip = [for net in wkr.ipv4 : net.private[0].address if net.private != []][0],
#       vpc_ip  = [for net in wkr.ipv4 : net.vpc[0].address if net.vpc != []][0],
#       nat_1_1 = [for net in wkr.ipv4 : net.vpc[0].nat_1_1 if net.vpc != []][0],
#     }
#   ]
# }

# ------------------------------------------------------------------------------
