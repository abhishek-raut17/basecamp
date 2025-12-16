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
  backend "local" {
    path = "terraform.tfstate"
  }
}

locals {
  # By default we use 1 controlplane for talos cluster and 1 bastion host
  # as management gateway and SSH management access for cluster
  #
  # Variables
  infra  = trimspace(chomp(var.project_name))
  region = trimspace(chomp(var.region))
  token  = trimspace(chomp(var.linode_token))

  public_key  = trimspace(chomp(file(var.sshkey_path)))
  private_key = trimspace(chomp(file(replace(var.sshkey_path, ".pub", ""))))

  devops_cd_sshkey      = trimspace(chomp(file(var.fluxcd_sshkey_path)))
  devops_cd_private_key = trimspace(chomp(file(replace(var.fluxcd_sshkey_path, ".pub", ""))))

  # talosctl_version = trimspace(chomp(var.talosctl_version))
  # kubectl_version  = trimspace(chomp(var.kubectl_version))

  vpc_cidr          = trimspace(chomp(var.vpc_cidr))
  cluster_subnet    = module.network.network_details.vpc.subnets[0].cidr
  dmz_subnet        = module.network.network_details.vpc.subnets[1].cidr
  cluster_subnet_id = module.network.network_details.vpc.subnets[0].id
  dmz_subnet_id     = module.network.network_details.vpc.subnets[1].id

  controlplane_vpc_ip = cidrhost(local.cluster_subnet, 10)
  workers_vpc_ip      = [for val in range(var.worker_nodes) : cidrhost(local.cluster_subnet, (20 + val))]
  bastion_vpc_ip      = cidrhost(local.dmz_subnet, 10)
  # bastion_public_ip      = module.bastion.bastion_details.public_ip
  # loadbalancer_public_ip = module.loadbalancer.loadbalancer_details.loadbalancer_ip

  cluster_firewall_id = module.security.security_details.firewall.cluster
  dmz_firewall_id     = module.security.security_details.firewall.dmz
  loadbalancer_fw_id  = module.security.security_details.firewall.loadbalancer

  git_repo = trimspace(chomp(var.git_repo))

  # loadbalancer_id = module.loadbalancer.loadbalancer_details.loadbalancer_id
  # bastion_id      = module.bastion.bastion_details.id
  # controlplane_id = module.compute.controlplane_node_id
  # workers_ids     = module.compute.worker_node_ids

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

  source = "./modules/security"
  infra  = local.infra
  subnet = {
    cluster = local.cluster_subnet,
    dmz     = local.dmz_subnet
  }
}

# ------------------------------------------------------------------------------
# Loadbalancer Module: Loadbalancer configurations for cluster traffic
# ------------------------------------------------------------------------------
module "loadbalancer" {
  providers = { linode = linode }

  depends_on = [
    module.network,
    module.security
  ]

  source      = "./modules/loadbalancer"
  infra       = local.infra
  region      = local.region
  firewall_id = local.loadbalancer_fw_id
}

# ------------------------------------------------------------------------------
# Prereq Module: Generates prerequsities and config required for infrastructure
# ------------------------------------------------------------------------------
module "prereq" {
  providers = { linode = linode }

  depends_on = [
    module.network,
    module.loadbalancer,
    module.security
  ]

  source       = "./modules/prereq"
  infra        = local.infra
  worker_count = var.worker_nodes
}

# ------------------------------------------------------------------------------
# Compute Module: Provision compute nodes to host k8s cluster
# ------------------------------------------------------------------------------
module "compute" {
  providers = { linode = linode }

  depends_on = [
    module.network,
    module.loadbalancer,
    module.prereq,
    module.security
  ]

  source               = "./modules/compute"
  infra                = local.infra
  region               = local.region
  ssh_key              = local.public_key
  ssh_private_key      = local.private_key
  nodetype             = var.cluster_nodetype
  nodeimage            = var.cluster_img
  controlplane_ip      = local.controlplane_vpc_ip
  workers_ip           = local.workers_vpc_ip
  subnet_id            = local.cluster_subnet_id
  firewall_id          = local.cluster_firewall_id
  node_userdata        = module.prereq.prereq_details
  gateway_nodebalancer = module.loadbalancer.loadbalancer_details
}

# ------------------------------------------------------------------------------
# Bastion Module: Provision bastion host for secured access to cluster
# ------------------------------------------------------------------------------
module "bastion" {
  providers = { linode = linode }

  depends_on = [
    module.network,
    module.security,
    module.loadbalancer,
    module.prereq,
    module.compute
  ]

  source           = "./modules/bastion"
  infra            = local.infra
  region           = local.region
  ssh_key          = local.public_key
  private_key      = local.private_key
  nodetype         = var.bastion_nodetype
  nodeimage        = var.bastion_img
  vpc_ip           = local.bastion_vpc_ip
  subnet_id        = local.dmz_subnet_id
  cluster_subnet   = local.cluster_subnet
  cluster_endpoint = local.controlplane_vpc_ip
  firewall_id      = local.dmz_firewall_id
  git_repo         = local.git_repo
  devops_cd_sshkey = local.devops_cd_private_key
}

# ------------------------------------------------------------------------------