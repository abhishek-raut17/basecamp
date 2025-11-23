##################################################################################
# Bootstrap Module Outputs
#
# Exposes key resource attributes for use by other modules or the root module:
#   - controlplane_node:     Private IPV4 address for controlplane node
#   - worker_nodes:          Private IPV4 addresses for worker nodes
##################################################################################

output "controlplane_node" {
  depends_on = [
    linode_firewall_device.cp_fw_device
  ]
  description = "Controlplane details"
  value = {
    host_id = [for net in data.linode_instance_networking.cp_network.ipv4 : net.vpc[0].linode_id if net.vpc != []][0],
    # private_ip = [for net in data.linode_instance_networking.cp_network.ipv4 : net.private[0].address if net.private != []][0],
    vpc_ip  = [for net in data.linode_instance_networking.cp_network.ipv4 : net.vpc[0].address if net.vpc != []][0],
    nat_1_1 = [for net in data.linode_instance_networking.cp_network.ipv4 : net.vpc[0].nat_1_1 if net.vpc != []][0],
  }
}

output "worker_nodes" {
  depends_on = [
    linode_firewall_device.wkr_fw_device
  ]
  description = "Worker nodes details"
  value = [
    for wkr in data.linode_instance_networking.wkr_network :
    {
      host_id = [for net in wkr.ipv4 : net.vpc[0].linode_id if net.vpc != []][0],
      # private_ip = [for net in wkr.ipv4 : net.private[0].address if net.private != []][0],
      vpc_ip  = [for net in wkr.ipv4 : net.vpc[0].address if net.vpc != []][0],
      nat_1_1 = [for net in wkr.ipv4 : net.vpc[0].nat_1_1 if net.vpc != []][0],
    }
  ]
}
# ------------------------------------------------------------------------------
