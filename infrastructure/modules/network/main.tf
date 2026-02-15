################################################################################
# Project: BaseCamp
# Network Module
#
# Provisions networking resources on Linode:
#   - VPC for project isolation
#   - 2 subnets: DMZ and Cluster
#
# Outputs:
#   - VPC and subnet IDs
#   - Subnet CIDRs (after creation for references)
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
  dmz_subnet     = cidrsubnet(var.vpc_cidr, 8, 2) # (default: 10.2.0.0/16)
  cluster_subnet = cidrsubnet(var.vpc_cidr, 8, 5) # (default: 10.5.0.0/16)
}

# ------------------------------------------------------------------------------
# VPC: Virtual Private Cloud for project isolation
# ------------------------------------------------------------------------------
resource "linode_vpc" "vpc" {
  label       = "${var.infra}-vpc"
  description = "VPC network for ${var.infra}"
  region      = var.region
}

# ------------------------------------------------------------------------------
# Subnet: DMZ Subnet for public facing (jump proxy/bastion host/gateway/TURN server)
# ------------------------------------------------------------------------------
resource "linode_vpc_subnet" "dmz_subnet" {
  label  = "${var.infra}-dmz-subnet"
  vpc_id = linode_vpc.vpc.id
  ipv4   = local.dmz_subnet
}

# ------------------------------------------------------------------------------
# Subnet: Cluster Subnet for internal/cluster resources
# ------------------------------------------------------------------------------
resource "linode_vpc_subnet" "cluster_subnet" {
  label  = "${var.infra}-cluster-subnet"
  vpc_id = linode_vpc.vpc.id
  ipv4   = local.cluster_subnet
}
# ------------------------------------------------------------------------------