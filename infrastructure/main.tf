################################################################################
# Project: BaseCamp
# Description: Platform Infrastructure on Linode
#
# Infrastructure Root Module
# Orchestrates the provisioning of the entire infrastructure stack on Linode.
#
# Modules:
#   - network:      Core networking (VPC, subnets)
#   - security:     Firewalls, security groups, etc.
#   - bastion:      Provision bastion host for secured access to cluster
#   - prereq:       Prerequisite resources (Ignition files, cluster configs)
#   - compute:      Kubernetes nodes and compute resources
#   - loadbalancer: NodeBalancer in DMZ
#
# Outputs:
#   - Module outputs for downstream use
################################################################################

terraform {

  required_version = ">= 1.5.0"

  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.2.0"
    }
  }
  # TODO: Add remote backend configuration for state management (e.g., S3, Terraform Cloud)
}

# By default we use 1 controlplane for talos cluster and 1 dmz host as management gateway, STUN/TURN server and 
# SSH access for cluster management
locals {

  infra          = trimspace(chomp(var.project_name))
  region         = trimspace(chomp(var.region))
  token          = trimspace(chomp(var.cloud_provider_token))
  dmz_access_key = trimspace(chomp(file(var.dmz_access_sshkey)))
  vpc_cidr       = trimspace(chomp(var.vpc_cidr))

  # controlplane_vpc_ip = cidrhost(local.cluster_subnet_cidr, 10)
  # workers_vpc_ip      = [for val in range(var.worker_nodes) : cidrhost(local.cluster_subnet_cidr, (20 + val))]
  # bastion_vpc_ip      = cidrhost(local.dmz_subnet_cidr, 10)

}

# ------------------------------------------------------------------------------
# Providers: Linode
# ------------------------------------------------------------------------------
provider "linode" {
  token = local.token
}

# ------------------------------------------------------------------------------
# Network Module: Core networking setup (VPC, subnets)
# ------------------------------------------------------------------------------
module "network" {
  providers = { linode = linode }

  source   = "./modules/network"
  infra    = local.infra
  region   = local.region
  vpc_cidr = local.vpc_cidr
}

# ------------------------------------------------------------------------------
# Security Module: Security configurations (firewalls, security groups)
# ------------------------------------------------------------------------------
module "security" {
  providers = { linode = linode }

  depends_on = [
    module.network
  ]

  source  = "./modules/security"
  infra   = local.infra
  subnets = module.network.network_details.vpc.subnets
}

# ------------------------------------------------------------------------------
# Compute Module: Provision compute nodes to host k8s cluster
# ------------------------------------------------------------------------------
module "compute" {
  providers = { linode = linode }

  depends_on = [
    module.network,
    module.security
  ]

  source            = "./modules/compute"
  infra             = local.infra
  region            = local.region
  dmz_access_sshkey = local.dmz_access_key

  userdata_dir = "${var.data_dir}/talos"
  subnets      = module.network.network_details.vpc.subnets
  vpc          = module.network.network_details.vpc.id
  firewalls    = module.security.security_details.firewalls

  nodes = {
    controlplane = {
      type  = var.node_instance_type_controlplane,
      image = var.node_image_cluster,
      count = var.controlplane_nodecount
    },
    worker = {
      type  = var.node_instance_type_worker,
      image = var.node_image_cluster,
      count = var.worker_nodecount
    },
    dmz = {
      type  = var.node_instance_type_dmz,
      image = var.node_image_dmz,
      count = 1
    }
  }
}

# ------------------------------------------------------------------------------