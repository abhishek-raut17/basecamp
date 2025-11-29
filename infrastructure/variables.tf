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
  sensitive   = true

  validation {
    condition     = length(var.linode_token) > 0
    error_message = "Linode API Token must be provided."
  }
}

## Github PAT for fluxcd git access
variable "git_token" {
  description = "Github PAT for fluxcd git access"
  type        = string
  sensitive   = false

  validation {
    condition     = length(var.git_token) > 0
    error_message = "Github PAT must be provided."
  }
}

## Admin SSH Key Path (public)
variable "public_sshkey_path" {
  description = "Path to the admin's SSH public key"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.public_sshkey_path) > 0
    error_message = "Path to the admin's SSH public key must be provided."
  }
}

## Admin SSH Key Path (private)
variable "private_sshkey_path" {
  description = "Path to the admin's SSH private key"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.private_sshkey_path) > 0
    error_message = "Path to the admin's SSH private key must be provided."
  }
}

## Infrastructure VPC CIDR
variable "vpc_cidr" {
  description = "VPC CIDR range for infrastructure"
  type        = string

  validation {
    condition     = length(var.vpc_cidr) > 0
    error_message = "VPC CIDR range must be provided."
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
variable "bastion_nodeimage" {
  description = "Node image ID for bastion nodes"
  type        = string

  validation {
    condition     = length(var.bastion_nodeimage) > 0
    error_message = "Node ID for bastion nodes must be provided"
  }
}

## Cluster nodes node image ID
variable "cluster_nodeimage" {
  description = "Node image ID for cluster nodes"
  type        = string

  validation {
    condition     = length(var.cluster_nodeimage) > 0
    error_message = "Node ID for cluster nodes must be provided"
  }
}

## Version ID for talosctl
variable "talosctl_version" {
  description = "Version ID for talosctl"
  type        = string

  validation {
    condition     = length(var.talosctl_version) > 0
    error_message = "Version ID for talosctl must be provided"
  }
}

## Version ID for kubectl
variable "kubectl_version" {
  description = "Version ID for kubectl"
  type        = string

  validation {
    condition     = length(var.kubectl_version) > 0
    error_message = "Version ID for kubectl must be provided"
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
# ------------------------------------------------------------------------------