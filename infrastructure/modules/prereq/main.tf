################################################################################
# Project: BaseCamp
# Prereq Module
#
# Provisions prerequsities required for infrastructure bootstrap
#   - Generate talos machineconfig files for cluster nodes
#   - Patch machineconfig files according to predefined ips
#
# Outputs:
#   - Local directory containing patched machineconfigs for cluster nodes
#   - Talosconfig file to bootstrap talos cluster via bastion (talosctl)
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
  root_dir               = abspath("${path.module}/../../..")
  machineconfig_dir      = "${local.root_dir}/manifests/machineconfig"
  cp_machineconfig_path  = "${local.machineconfig_dir}/controlplane.machineconfig.yaml"
  wkr_machineconfig_path = "${local.machineconfig_dir}/wkr.machineconfig.yaml"

  controlplane_base_config = yamldecode(file(local.cp_machineconfig_path))
  worker_base_config       = yamldecode(file(local.wkr_machineconfig_path))

  patched_controlplane_config = merge(
    local.controlplane_base_config,
    {
      machine = merge(
        try(local.controlplane_base_config.machine, {}),
        {
          network = merge(
            try(local.controlplane_base_config.machine.network, {}),
            {
              hostname = "${var.infra}-controlplane"
            }
          )
        }
      )
    }
  )

  patched_worker_config = [for i in range(var.worker_count) : merge(
    local.worker_base_config,
    {
      machine = merge(
        try(local.worker_base_config.machine, {}),
        {
          network = merge(
            try(local.worker_base_config.machine.network, {}),
            {
              hostname = "${var.infra}-worker-${i}"
            }
          )
        }
      )
    }
  )]
}

# ------------------------------------------------------------------------------
# Generate patches machineconfig files with predefined hostnames
# ------------------------------------------------------------------------------
resource "local_file" "cp_machineconfig" {
  filename = local.cp_machineconfig_path
  content  = yamlencode(local.patched_controlplane_config)
}

resource "local_file" "wkr_machineconfig" {
  count    = var.worker_count
  filename = local.wkr_machineconfig_path
  content  = yamlencode(local.patched_worker_config[count.index])
}
# ------------------------------------------------------------------------------