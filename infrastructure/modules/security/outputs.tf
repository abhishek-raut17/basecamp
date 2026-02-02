##################################################################################
# Security Module Outputs
#
# Exposes key resource attributes for use by other modules or the root module:
#   - cluster_fw_id:  Firewall ID of the Cluster subnet firewall              
#   - dmz_fw_id:     Firewall ID of the DMZ subnet firewall
##################################################################################

output "security_details" {
  depends_on = [
    linode_firewall.cluster_fw,
    linode_firewall.dmz_fw
  ]
  description = "Firewall details"
  value = {
    firewall = {
      cluster = linode_firewall.cluster_fw.id,
      dmz     = linode_firewall.dmz_fw.id
    }
  }
}
# ------------------------------------------------------------------------------