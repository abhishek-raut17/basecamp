##################################################################################
# Loadbalancer Module Outputs
#
# Exposes key resource attributes for use by other modules or the root module:
#   - 
##################################################################################

output "loadbalancer_details" {
  depends_on  = [linode_nodebalancer.gateway_lb]
  description = "Gateway loadbalancer details"
  value = {
    loadbalancer_id       = linode_nodebalancer.gateway_lb.id
    loadbalancer_hostname = linode_nodebalancer.gateway_lb.hostname
    loadbalancer_ip       = linode_nodebalancer.gateway_lb.ipv4

    http_config_id        = linode_nodebalancer_config.http.id
    https_config_id       = linode_nodebalancer_config.https.id
    kubectlapi_config_id  = linode_nodebalancer_config.kubectlapi.id
    talosctlapi_config_id = linode_nodebalancer_config.talosctlapi.id
  }
}
# ------------------------------------------------------------------------------
