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

# By default we use 1 controlplane for talos cluster and 1 bastion host
# as management gateway and SSH management access for cluster
locals {

  infra  = trimspace(chomp(var.project_name))
  region = trimspace(chomp(var.region))
  token  = trimspace(chomp(var.linode_token))
  db_pass = trimspace(chomp(var.db_admin_pass))

  public_key  = trimspace(chomp(file(var.sshkey_path)))
  private_key = trimspace(chomp(file(replace(var.sshkey_path, ".pub", ""))))

  devops_cd_sshkey      = trimspace(chomp(file(var.fluxcd_sshkey_path)))
  devops_cd_private_key = trimspace(chomp(file(replace(var.fluxcd_sshkey_path, ".pub", ""))))

  vpc_cidr            = trimspace(chomp(var.vpc_cidr))
  cluster_subnet_cidr = module.network.network_details.vpc.subnets[0].cidr
  dmz_subnet_cidr     = module.network.network_details.vpc.subnets[1].cidr
  cluster_subnet_id   = module.network.network_details.vpc.subnets[0].id
  dmz_subnet_id       = module.network.network_details.vpc.subnets[1].id

  controlplane_vpc_ip = cidrhost(local.cluster_subnet_cidr, 10)
  workers_vpc_ip      = [for val in range(var.worker_nodes) : cidrhost(local.cluster_subnet_cidr, (20 + val))]
  bastion_vpc_ip      = cidrhost(local.dmz_subnet_cidr, 10)

  cluster_firewall_id = module.security.security_details.firewall.cluster
  dmz_firewall_id     = module.security.security_details.firewall.dmz

  git_repo = trimspace(chomp(var.git_repo))

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
    cluster = {
      cidr = local.cluster_subnet_cidr,
      id   = local.cluster_subnet_id
    },
    dmz = {
      cidr = local.dmz_subnet_cidr,
      id   = local.dmz_subnet_id
    }
  }
}

# ------------------------------------------------------------------------------
# Prereq Module: Generates prerequsities and config required for infrastructure
# ------------------------------------------------------------------------------
module "prereq" {
  providers = { linode = linode }

  depends_on = [
    module.network,
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
    module.prereq,
    module.security
  ]

  source        = "./modules/compute"
  infra         = local.infra
  region        = local.region
  nodetype      = var.cluster_nodetype
  nodeimage     = var.cluster_img
  node_userdata = module.prereq.prereq_details
  subnet_id     = local.cluster_subnet_id
  vpc_ip = {
    controlplane = local.controlplane_vpc_ip,
    workers      = local.workers_vpc_ip
  }
  firewall_id = local.cluster_firewall_id
}

# ------------------------------------------------------------------------------
# Bastion Module: Provision bastion host for secured access to cluster
# ------------------------------------------------------------------------------
module "bastion" {
  providers = { linode = linode }

  depends_on = [
    module.network,
    module.security,
    module.prereq,
    module.compute
  ]

  source                      = "./modules/bastion"
  token                       = local.token
  db_admin_pass               = local.db_pass
  infra                       = local.infra
  region                      = local.region
  ssh_key                     = local.public_key
  private_key                 = local.private_key
  nodetype                    = var.bastion_nodetype
  nodeimage                   = var.bastion_img
  vpc_ip                      = local.bastion_vpc_ip
  subnet_id                   = local.dmz_subnet_id
  cluster_subnet              = local.cluster_subnet_cidr
  cluster_endpoint            = local.controlplane_vpc_ip
  firewall_id                 = local.dmz_firewall_id
  git_repo                    = local.git_repo
  devops_cd_sshkey            = local.devops_cd_private_key
  talosctl_version            = var.v_talosctl
  kubectl_version             = var.v_kubectl
  k8s_gateway_version         = var.v_k8s_gateway
  cert_manager_plugin_version = var.v_cert_manager_plugin
  kubeseal_version            = var.v_kubeseal
}

# ------------------------------------------------------------------------------