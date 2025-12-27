################################################################################
# Project: BaseCamp
# Loadbalancer Module
#
# Provisions core nodebalancer resources on Linode:
#   - Nodebalancer to distribute traffic to cluster nodes
#
# Inputs:
#   - project_name:             Project name
#   - region:                   Linode cluster region
#   - ssh_key:                  SSH public key to access instances
#   - node_img:                 Linux Image label
#   - talos_img:                Talos OS Image ID
#   - cluster_node_type_id:     Compute instance type for cluster nodes
#   - bastion_node_type_id:     Compute instance type for bastion host
#   - dmz_subnet_id:            ID of the DMZ subnet
#   - cluster_subnet_id:        ID of the Cluster subnet
#   - worker_node_count:        Number of worker nodes in the cluster
#
# Outputs:
#   - Bastion host node ID and public IP
#   - Control plane and worker node IDs and private IPs
################################################################################

terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.2.0"
    }
  }
  required_version = ">= 1.5.0"
}

# ------------------------------------------------------------------------------
# Provision nodebalancer in DMZ as gateway to cluster
# ------------------------------------------------------------------------------
resource "linode_nodebalancer" "gateway_lb" {
  label                    = "${var.infra}-gateway-lb"
  region                   = var.region
  client_conn_throttle     = 10
  client_udp_sess_throttle = 20
}

# ------------------------------------------------------------------------------
# Configure nodebalancer ports
# ------------------------------------------------------------------------------
resource "linode_nodebalancer_config" "http" {
  nodebalancer_id = linode_nodebalancer.gateway_lb.id
  protocol        = "tcp"
  port            = 80
  algorithm       = "roundrobin"
  stickiness      = "none"
  proxy_protocol  = "none"
}

resource "linode_nodebalancer_config" "https" {
  nodebalancer_id = linode_nodebalancer.gateway_lb.id
  protocol        = "tcp"
  port            = 443
  algorithm       = "roundrobin"
  stickiness      = "none"
  proxy_protocol  = "none"
}

# ------------------------------------------------------------------------------
# Loadbalancer firewall: Attach nodebalancer to dmz firewall
# ------------------------------------------------------------------------------
resource "linode_firewall_device" "gateway_fw_device" {

  firewall_id = var.firewall_id
  entity_id   = linode_nodebalancer.gateway_lb.id
  entity_type = "nodebalancer"
}

# ------------------------------------------------------------------------------
