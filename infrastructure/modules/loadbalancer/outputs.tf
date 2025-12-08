##################################################################################
# Loadbalancer Module Outputs
#
# Exposes key resource attributes for use by other modules or the root module:
#   - 
##################################################################################

output "loadbalancer_details" {
  depends_on = [
    linode_nodebalancer.gateway_lb
  ]
  description = "Gateway loadbalancer details"
  value = {
    gateway = {
      id       = linode_nodebalancer.gateway_lb.id
      hostname = linode_nodebalancer.gateway_lb.hostname
      ip       = linode_nodebalancer.gateway_lb.ipv4
      configs = [
        {
          name = "http"
          id   = linode_nodebalancer_config.http.id
        },
        {
          name = "https"
          id   = linode_nodebalancer_config.https.id
        },
        #
        # FOR TESTING PURPOSES ONLY, DISABLED FOR PRODUCTION
        # {
        #   name = "kubectlapi"
        #   id   = linode_nodebalancer_config.kubectlapi.id
        # },
        # {
        #   name = "talosctlapi"
        #   id   = linode_nodebalancer_config.talosctlapi.id
        # }
      ]
    }
  }
}
# ------------------------------------------------------------------------------
