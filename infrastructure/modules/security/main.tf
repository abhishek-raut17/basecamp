################################################################################
# Project: BaseCamp
# Security Module
#
# Provisions security resources on Linode:
#   - Creates firewalls for dmz and cluster subnets
#
# Outputs:
#   - Firewall IDs per subnet
################################################################################

terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.2.0"
    }
  }
  required_version = ">= 1.0.0"
}

# ------------------------------------------------------------------------------
# Firewall: Cluster Subnet Firewall for internal/cluster resources
# ------------------------------------------------------------------------------
resource "linode_firewall" "cluster_fw" {
  label = "${var.infra}-cluster-firewall"

  # Allow TCP from cluster subnet for internal cluster communication
  inbound {
    label    = "allow-tcp-from-cluster-subnet"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = [var.cluster_subnet]
  }

  # Allow UDP from cluster subnet for internal cluster communication
  inbound {
    label    = "allow-udp-from-cluster-subnet"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = [var.cluster_subnet]
  }

  # Allow TCP from DMZ subnet for cluster management
  inbound {
    label    = "allow-tcp-from-dmz-subnet"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "6443,50000"
    ipv4     = [var.dmz_subnet]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = ["cluster", "k8s"]
}

# ------------------------------------------------------------------------------
# Firewall: DMZ Subnet Firewall for secure access to cluster resources
# ------------------------------------------------------------------------------
resource "linode_firewall" "dmz_fw" {
  label = "${var.infra}-dmz-firewall"

  # Allow SSH from internet
  inbound {
    label    = "allow-ssh-from-internet"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = ["0.0.0.0/0"]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = ["dmz", "access"]
}

# ------------------------------------------------------------------------------
# Firewall: Loadbalancer Firewall for traffic to services in the cluster
# ------------------------------------------------------------------------------
resource "linode_firewall" "loadbalancer_fw" {
  label = "${var.infra}-lb-fw"

  # Accept TCP (HTTP/S) from internet
  inbound {
    label    = "accept-tcp-from-internet"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "80,443"
    ipv4     = ["0.0.0.0/0"]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = ["dmz", "access"]
}
# ------------------------------------------------------------------------------