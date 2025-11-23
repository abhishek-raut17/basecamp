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
  required_version = ">= 1.0.0"
}

locals {
  vpc_cidr       = trimspace(chomp(var.vpc_cidr))
  dmz_subnet     = cidrsubnet(local.vpc_cidr, 8, 2)
  cluster_subnet = cidrsubnet(local.vpc_cidr, 8, 10)
}

# ------------------------------------------------------------------------------
# VPC: Virtual Private Cloud for project isolation
# ------------------------------------------------------------------------------
resource "linode_vpc" "vpc" {
  label       = "${var.infra}-vpc"
  description = "VPC for ${var.infra}"
  region      = var.region
}

# ------------------------------------------------------------------------------
# Subnet: DMZ Subnet for public facing (jump proxy/bastion host) resources
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