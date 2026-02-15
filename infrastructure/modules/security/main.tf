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
  required_version = ">= 1.5.0"
}

locals {

  cluster_cidr = [for subnet in var.subnets : subnet.cidr if subnet.name == "cluster"]
  dmz_cidr     = [for subnet in var.subnets : subnet.cidr if subnet.name == "dmz"]
}

# ------------------------------------------------------------------------------
# Firewall: Cluster Subnet Firewall for internal/cluster resources
# ------------------------------------------------------------------------------
resource "linode_firewall" "cluster_firewall" {
  label = "${var.infra}-cluster-firewall-rules"

  # Allow TCP from cluster subnet for internal cluster communication
  inbound {
    label    = "allow-tcp-from-cluster-subnet"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = local.cluster_cidr
  }

  # Allow UDP from cluster subnet for internal cluster communication
  inbound {
    label    = "allow-udp-from-cluster-subnet"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = local.cluster_cidr
  }

  # Allow TCP from DMZ subnet for cluster management
  inbound {
    label    = "allow-access-from-dmz-subnet"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "6443,50000"
    ipv4     = local.dmz_cidr
  }

  # Allow TCP from DMZ subnet for public service traffic
  inbound {
    label    = "allow-tcp-from-dmz-subnet"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "8000,8443"
    ipv4     = local.dmz_cidr
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = ["cluster", "restricted", var.infra]
}

# ------------------------------------------------------------------------------
# Firewall: DMZ Subnet Firewall for access to bastion and loadbalancer
# ------------------------------------------------------------------------------
resource "linode_firewall" "dmz_firewall" {
  label = "${var.infra}-dmz-firewall-rules"

  # Allow SSH from internet (for cluster management access to bastion host in DMZ)
  inbound {
    label    = "allow-ssh-from-internet"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = ["0.0.0.0/0"]
  }

  # Accept TCP (public traffic) from internet (as cluster gateway and TURN TLS for WebRTC)
  inbound {
    label    = "accept-tcp-from-internet"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "80,443,5349"
    ipv4     = ["0.0.0.0/0"]
  }

  # Accept UDP (public traffic) from internet (as STUN/TURN for WebRTC)
  inbound {
    label    = "accept-udp-from-internet"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "3478,5349,49152-65535"
    ipv4     = ["0.0.0.0/0"]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = ["dmz", "public", var.infra]
}

# ------------------------------------------------------------------------------