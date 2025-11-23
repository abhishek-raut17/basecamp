##################################################################################
# Security Module Outputs
#
# Exposes key resource attributes for use by other modules or the root module:
#   - cluster_fw_id:  Firewall ID of the Cluster subnet firewall              
#   - dmz_fw_id:     Firewall ID of the DMZ subnet firewall
#   - lb_fw_id:      Firewall ID of the Loadbalancer firewall
##################################################################################

output "firewall_details" {
  depends_on = [
    linode_firewall.cluster_fw,
    linode_firewall.dmz_fw,
    linode_firewall.loadbalancer_fw
  ]
  description = "Firewall details"
  value = {
    cluster_fw_id      = linode_firewall.cluster_fw.id
    dmz_fw_id          = linode_firewall.dmz_fw.id
    loadbalancer_fw_id = linode_firewall.loadbalancer_fw.id
  }
}
# ------------------------------------------------------------------------------