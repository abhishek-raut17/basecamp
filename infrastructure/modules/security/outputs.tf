##################################################################################
# Security Module Outputs
#
# Exposes key resource attributes for use by other modules or the root module:
#   - cluster_fw_id:  Firewall ID of the Cluster subnet firewall              
#   - dmz_fw_id:     Firewall ID of the DMZ subnet firewall
##################################################################################

output "security_details" {
  depends_on = [
    linode_firewall.cluster_firewall,
    linode_firewall.dmz_firewall
  ]
  description = "Firewall details"
  value = {
    firewalls = [
      {
        name = "cluster"
        id   = linode_firewall.cluster_firewall.id
      },
      {
        name = "dmz"
        id   = linode_firewall.dmz_firewall.id
      }
    ]
  }
}
# ------------------------------------------------------------------------------