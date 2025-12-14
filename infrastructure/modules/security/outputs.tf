##################################################################################
# Security Module Outputs
#
# Exposes key resource attributes for use by other modules or the root module:
#   - cluster_fw_id:  Firewall ID of the Cluster subnet firewall              
#   - dmz_fw_id:     Firewall ID of the DMZ subnet firewall
#   - lb_fw_id:      Firewall ID of the Loadbalancer firewall
##################################################################################

output "security_details" {
  depends_on = [
    linode_firewall.cluster_fw,
    linode_firewall.dmz_fw,
    linode_firewall.loadbalancer_fw
  ]
  description = "Firewall details"
  value = {
    firewall = {
      cluster      = linode_firewall.cluster_fw.id,
      dmz          = linode_firewall.dmz_fw.id,
      loadbalancer = linode_firewall.loadbalancer_fw.id
    }
  }
}
# ------------------------------------------------------------------------------