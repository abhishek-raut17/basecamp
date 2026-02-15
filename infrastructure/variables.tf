##################################################################################
#
# Root Module Variables
#
# Variables:
#   - project_name:             Project name
#   - region:                   Linode region
#   - cloud_provider_token:             Linode API token
#   - public_sshkey_path:       Path to admin's SSH public key
#   - private_sshkey_path:      Path to admin's SSH private key
#   - node_instance_type_dmz:         Compute instance type for bastion nodes
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

## Data directory path
variable "data_dir" {
  description = "Path to the data directory for storing generated files (e.g. inventory files, SSH keys, etc.)"
  type        = string
  default     = "~/.local/share/basecamp"

  validation {
    condition     = length(var.data_dir) > 0
    error_message = "Data directory path must be provided (e.g. ./data)."
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
variable "cloud_provider_token" {
  description = "Cloud provider API Token"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cloud_provider_token) > 0
    error_message = "Cloud provider API Token must be provided."
  }
}

## SSH Key to access DMZ nodes (public nodes)
variable "dmz_access_sshkey" {
  description = "Path to the SSH keys for admin access to DMZ nodes (default: ~/.ssh/id_rsa.pub)"
  type        = string
  sensitive   = true

  validation {
    condition     = fileexists(var.dmz_access_sshkey)
    error_message = "Path to the SSH keys must be provided. (default: ~/.ssh/id_rsa.pub)"
  }
}

## Infrastructure VPC CIDR range
variable "vpc_cidr" {
  description = "VPC CIDR range for infrastructure"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && split("/", var.vpc_cidr)[1] == "8"
    error_message = "VPC CIDR must be a valid CIDR with /8 subnet mask (e.g.10.0.0.0/8)."
  }
}

## Node instance type: DMZ nodes
variable "node_instance_type_dmz" {
  description = "The type (category) of compute node instance for dmz nodes"
  type        = string

  validation {
    condition     = length(var.node_instance_type_dmz) > 0
    error_message = "Node instance type for dmz nodes must be provided"
  }
}

## Node instance type: control-plane nodes
variable "node_instance_type_controlplane" {
  description = "The type (category) of compute node instance for control-plane nodes"
  type        = string

  validation {
    condition     = length(var.node_instance_type_controlplane) > 0
    error_message = "Node instance type for control-plane nodes must be provided"
  }
}

## Node instance type: DMZ nodes
variable "node_instance_type_worker" {
  description = "The type (category) of compute node instance for worker nodes"
  type        = string

  validation {
    condition     = length(var.node_instance_type_worker) > 0
    error_message = "Node instance type for worker nodes must be provided"
  }
}

## Nodes isntance image ID: DMZ nodes
variable "node_image_dmz" {
  description = "The image ID for compute node instance for dmz nodes"
  type        = string

  validation {
    condition     = length(var.node_image_dmz) > 0
    error_message = "Node ID for dmz nodes must be provided"
  }
}

## Nodes intance image ID: cluster nodes
variable "node_image_cluster" {
  description = "The image ID for compute node instance for cluster nodes"
  type        = string

  validation {
    condition     = length(var.node_image_cluster) > 0
    error_message = "Node ID for cluster nodes must be provided"
  }
}

## Control-plane nodes count
variable "controlplane_nodecount" {
  description = "Number of control-plane nodes in a cluster"
  type        = number

  validation {
    condition     = var.controlplane_nodecount >= 1 && var.controlplane_nodecount % 2 != 0
    error_message = "Control-plane node count must be provided (atleast 1 node required and must be an odd number)"
  }
}

## Worker nodes count
variable "worker_nodecount" {
  description = "Number of worker nodes in a cluster"
  type        = number

  validation {
    condition     = var.worker_nodecount >= 3
    error_message = "Worker node count must be provided (atleast 3 nodes required)"
  }
}

# ------------------------------------------------------------------------------