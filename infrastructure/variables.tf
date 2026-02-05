##################################################################################
#
# Root Module Variables
#
# Variables:
#   - project_name:             Project name
#   - region:                   Linode region
#   - linode_token:             Linode API token
#   - public_sshkey_path:       Path to admin's SSH public key
#   - private_sshkey_path:      Path to admin's SSH private key
#   - bastion_nodetype:         Compute instance type for bastion nodes
#   - cluster_nodetype:         Compute instance type for cluster nodes
#   - bastion_nodeimage:        Node image label for bastion host
#   - cluster_nodeimage:        Node image label for cluster host
##################################################################################

## Project name
variable "project_name" {
  description = "Project Name"
  type        = string
  default     = "basecamp"

  validation {
    condition     = length(var.project_name) > 0
    error_message = "Project name must be provided."
  }
}

## Linode Region
variable "region" {
  description = "Linode Region"
  type        = string
  default     = "us-ord"

  validation {
    condition     = length(var.region) > 0
    error_message = "Linode region must be provided."
  }
}

## Cloud provider (linode) access token
variable "linode_token" {
  description = "Linode API Token"
  type        = string
  sensitive   = false

  validation {
    condition     = length(var.linode_token) > 0
    error_message = "Linode API Token must be provided."
  }
}

## Git repository for deployment manifests
variable "git_repo" {
  description = "Git repository for deployment manifests"
  type        = string

  validation {
    condition     = length(var.git_repo) > 0
    error_message = "Git repository for deployment manifests must be provided."
  }
}

## Admin SSH Key Path (public)
variable "sshkey_path" {
  description = "Path to the SSH keys for admin access (default: ~/.ssh/id_rsa.pub)"
  type        = string
  sensitive   = true

  validation {
    condition     = fileexists(var.sshkey_path)
    error_message = "Path to the SSH keys must be provided. (default: ~/.ssh/id_rsa.pub)"
  }
}

## Fluxcd SSH Key Path (public)
variable "fluxcd_sshkey_path" {
  description = "Path to the SSH keys for fluxcd access (default: ~/.ssh/devops_cd.pub)"
  type        = string
  sensitive   = true

  validation {
    condition     = fileexists(var.fluxcd_sshkey_path)
    error_message = "Path to the SSH keys must be provided. (default: ~/.ssh/devops_cd.pub)"
  }
}

## Infrastructure VPC CIDR
variable "vpc_cidr" {
  description = "VPC CIDR range for infrastructure"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && split("/", var.vpc_cidr)[1] == "16"
    error_message = "VPC CIDR must be a valid CIDR with /16 subnet mask (e.g.10.0.0.0/16)."
  }
}

## Bastion Instance Type
variable "bastion_nodetype" {
  description = "The type (category) of compute node instance for bastion host"
  type        = string

  validation {
    condition     = length(var.bastion_nodetype) > 0
    error_message = "Node type for bastion nodes must be provided"
  }
}

## Cluster Instance Types
variable "cluster_nodetype" {
  description = "The type (category) of compute node instance for cluster nodes"
  type        = string

  validation {
    condition     = length(var.cluster_nodetype) > 0
    error_message = "Node type for cluster nodes must be provided"
  }
}

## Bastion nodes node image ID
variable "bastion_img" {
  description = "Node image ID for bastion nodes"
  type        = string

  validation {
    condition     = length(var.bastion_img) > 0
    error_message = "Node ID for bastion nodes must be provided"
  }
}

## Cluster nodes node image ID
variable "cluster_img" {
  description = "Node image ID for cluster nodes"
  type        = string

  validation {
    condition     = length(var.cluster_img) > 0
    error_message = "Node ID for cluster nodes must be provided"
  }
}

## Version ID for talosctl
variable "v_talosctl" {
  description = "Version ID for talosctl"
  type        = string

  validation {
    condition     = length(var.v_talosctl) > 0 && startswith(var.v_talosctl, "v")
    error_message = "Version ID for talosctl must be provided"
  }
}

## Version ID for kubectl
variable "v_kubectl" {
  description = "Version ID for kubectl"
  type        = string

  validation {
    condition     = length(var.v_kubectl) > 0 && startswith(var.v_kubectl, "v")
    error_message = "Version ID for kubectl must be provided"
  }
}

## Version ID for k8s-gateway-api
variable "v_k8s_gateway" {
  description = "Version ID for k8s-gateway-api"
  type        = string

  validation {
    condition     = length(var.v_k8s_gateway) > 0 && startswith(var.v_k8s_gateway, "v")
    error_message = "Version ID for k8s-gateway-api must be provided"
  }
}

## Version ID for cert-manager-plugin
variable "v_cert_manager_plugin" {
  description = "Version ID for cert-manager-plugin"
  type        = string

  validation {
    condition     = length(var.v_cert_manager_plugin) > 0 && startswith(var.v_cert_manager_plugin, "v")
    error_message = "Version ID for cert-manager-plugin must be provided"
  }
}

## Version ID for kubeseal
variable "v_kubeseal" {
  description = "Version ID for kubeseal"
  type        = string

  validation {
    condition     = length(var.v_kubeseal) > 0 && startswith(var.v_kubeseal, "v")
    error_message = "Version ID for kubeseal must be provided"
  }
}

## Worker nodes count
variable "worker_nodes" {
  description = "Number of worker nodes in a cluster"
  type        = number

  validation {
    condition     = var.worker_nodes >= 3
    error_message = "Worker node count must be provided (atleast 3 nodes required)"
  }
}

## Database Admin Password - (Postgres)
variable "db_admin_pass" {
  description = "Postgres database Admin Password for cluster instance"
  type        = string

  validation {
    condition = length(var.db_admin_pass) > 5
    error_message = "Database Admin Password must be at least 6 characters long"
  }
}

# ------------------------------------------------------------------------------