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

  public_key  = trimspace(chomp(file("${var.public_sshkey_path}")))
  private_key = trimspace(chomp(file("${var.private_sshkey_path}")))

  talosctl_version = trimspace(chomp(var.talosctl_version))
  kubectl_version  = trimspace(chomp(var.kubectl_version))

  vpc_cidr          = trimspace(chomp(var.vpc_cidr))
  cluster_subnet    = module.network.vpc_details.cluster_subnet_cidr
  cluster_subnet_id = module.network.vpc_details.cluster_subnet_id
  dmz_subnet        = module.network.vpc_details.dmz_subnet_cidr
  dmz_subnet_id     = module.network.vpc_details.dmz_subnet_id

  controlplane_vpc_ip    = cidrhost(module.network.vpc_details.cluster_subnet_cidr, 10)
  workers_vpc_ip         = [for val in range(var.worker_nodes) : cidrhost(module.network.vpc_details.cluster_subnet_cidr, (20 + val))]
  bastion_vpc_ip         = cidrhost(module.network.vpc_details.dmz_subnet_cidr, 10)
  bastion_public_ip      = module.bastion.bastion_details.public_ip
  loadbalancer_public_ip = module.loadbalancer.loadbalancer_details.loadbalancer_ip

  cluster_firewall_id = module.security.firewall_details.cluster_fw_id
  dmz_firewall_id     = module.security.firewall_details.dmz_fw_id
  loadbalancer_fw_id  = module.security.firewall_details.loadbalancer_fw_id

  loadbalancer_id = module.loadbalancer.loadbalancer_details.loadbalancer_id
  bastion_id      = module.bastion.bastion_details.id
  controlplane_id = module.compute.controlplane_node_id
  workers_ids     = module.compute.worker_node_ids

}

# ------------------------------------------------------------------------------
# Providers: Linode
# ------------------------------------------------------------------------------
provider "linode" {

  token = local.token
}

# ------------------------------------------------------------------------------
# Admin SSH Key: Import admin's SSH public key for secure access to bastion host
# ------------------------------------------------------------------------------
resource "linode_sshkey" "public_sshkey" {

  label   = "${local.infra}-admin-access-sshkey"
  ssh_key = local.public_key
}

# ------------------------------------------------------------------------------
# Network Module: Core networking setup (VPC, subnets)
# ------------------------------------------------------------------------------
module "network" {

  source = "./modules/network"
  infra  = local.infra
  region = local.region

  vpc_cidr = local.vpc_cidr

  providers = { linode = linode }
}

# ------------------------------------------------------------------------------
# Loadbalancer Module: Loadbalancer configurations for cluster traffic
# ------------------------------------------------------------------------------
module "loadbalancer" {

  source = "./modules/loadbalancer"
  infra  = local.infra
  region = local.region

  providers = { linode = linode }
}

# ------------------------------------------------------------------------------
# Security Module: Security configurations (firewalls, security groups)
# ------------------------------------------------------------------------------
module "security" {
  depends_on = [
    module.network
  ]

  source = "./modules/security"
  infra  = local.infra

  cluster_subnet = local.cluster_subnet
  dmz_subnet     = local.dmz_subnet

  providers = { linode = linode }
}

# ------------------------------------------------------------------------------
# Prereq Module: Generates prerequsities and config required for infrastructure
# ------------------------------------------------------------------------------
module "prereq" {
  depends_on = [
    module.network
  ]

  source       = "./modules/prereq"
  infra        = local.infra
  cluster_ip   = local.controlplane_vpc_ip
  worker_count = length(local.workers_vpc_ip)
  providers    = { linode = linode }
}

# ------------------------------------------------------------------------------
# Bastion Module: Provision bastion host for secured access to cluster
# ------------------------------------------------------------------------------
module "bastion" {
  depends_on = [
    linode_sshkey.public_sshkey,
    module.network,
    module.prereq,
    module.security
  ]
  source  = "./modules/bastion"
  infra   = local.infra
  region  = local.region
  ssh_key = linode_sshkey.public_sshkey.ssh_key

  nodetype  = var.bastion_nodetype
  nodeimage = var.bastion_nodeimage

  vpc_ip    = local.bastion_vpc_ip
  subnet_id = local.dmz_subnet_id

  providers = { linode = linode }
}

# ------------------------------------------------------------------------------
# Compute Module: Provision compute nodes to host k8s cluster
# ------------------------------------------------------------------------------
module "compute" {
  depends_on = [
    linode_sshkey.public_sshkey,
    module.network,
    module.loadbalancer,
    module.prereq,
    module.security
  ]

  source          = "./modules/compute"
  infra           = local.infra
  region          = local.region
  ssh_key         = linode_sshkey.public_sshkey.ssh_key
  ssh_private_key = local.private_key

  nodetype  = var.cluster_nodetype
  nodeimage = var.cluster_nodeimage

  controlplane_ip = local.controlplane_vpc_ip
  workers_ip      = local.workers_vpc_ip

  subnet_id   = local.cluster_subnet_id
  firewall_id = local.cluster_firewall_id

  providers = { linode = linode }
}

# ------------------------------------------------------------------------------
# Bootstarp Module: Bootraps resources to initialize k8s cluster
# ------------------------------------------------------------------------------
module "bootstrap" {
  depends_on = [
    linode_sshkey.public_sshkey,
    module.network,
    module.loadbalancer,
    module.prereq,
    module.security,
    module.bastion,
    module.compute
  ]

  source         = "./modules/bootstrap"
  infra          = local.infra
  region         = local.region
  git_token      = var.git_token
  workers_count  = length(local.workers_vpc_ip)
  cluster_subnet = local.cluster_subnet

  components = {
    gateway = {
      firewall_id = local.loadbalancer_fw_id
      entity_ids  = [local.loadbalancer_id]
      config_ids = {
        http         = module.loadbalancer.loadbalancer_details.http_config_id,
        https        = module.loadbalancer.loadbalancer_details.https_config_id,
        kubectl_api  = module.loadbalancer.loadbalancer_details.kubectlapi_config_id,
        talosctl_api = module.loadbalancer.loadbalancer_details.talosctlapi_config_id
      }
    }
    controlplane = {
      firewall_id = local.cluster_firewall_id
      entity_ids  = [local.controlplane_id]
    }
    workers = {
      firewall_id = local.cluster_firewall_id
      entity_ids  = local.workers_ids
    }
    bastion = {
      firewall_id = local.dmz_firewall_id
      entity_ids  = [local.bastion_id]
    }
  }

  bastion_bootstrap = {
    public_ip       = local.bastion_public_ip
    private_key     = local.private_key
    controlplane_ip = local.controlplane_vpc_ip
  }

  providers = { linode = linode }
}
# ------------------------------------------------------------------------------