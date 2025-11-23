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
  required_version = ">= 1.0.0"
}

locals {
  lib_dir           = "${path.module}/lib"
  patch_dir         = "${local.lib_dir}/patches"
  generated_dir     = "${local.lib_dir}/generated"
  machineconfig_dir = "${local.lib_dir}/machineconfigs"

  # Talos machineconfig patches
  machineconfig_path = "${local.patch_dir}/machine.patch.yaml.tftpl"

  # Base generated talosconfigs
  cp_machineconfig_path  = "${local.generated_dir}/controlplane.yaml"
  wkr_machineconfig_path = "${local.generated_dir}/worker.yaml"
  talosconfig_path       = "${local.generated_dir}/talosconfig"
}

# ------------------------------------------------------------------------------
# Generate initial machine config files for Talos Linux as cluster nodeimage
# ------------------------------------------------------------------------------
resource "terraform_data" "generate_machineconfig" {

  # Step 1: Create generated directory if not present
  provisioner "local-exec" {
    command = "mkdir -m 0750 -p '${local.generated_dir}'"
  }

  # Step 2: Generate secrets for Talos cluster communications
  provisioner "local-exec" {
    command = "talosctl gen secrets --force -o '${local.generated_dir}/secrets.yaml'"
  }

  # Step 3: Generate base machineconfigs for controlplane and worker nodes
  provisioner "local-exec" {
    command = <<-EOT
      talosctl gen config ${var.infra}-cluster https://${var.cluster_ip}:6443 \
        --output-dir "${local.generated_dir}" \
        --with-secrets "${local.generated_dir}/secrets.yaml" \
        --with-examples=false \
        --with-docs=false \
        --force
    EOT
  }

  # Step 4: Generate/update talosconfig to point to cluster endpoint
  provisioner "local-exec" {
    command = "talosctl config endpoint ${var.cluster_ip} --talosconfig='${local.generated_dir}/talosconfig'"
  }

  # Step 5: Merge generated talosconfig with environment talosconfig (default: ~/.talos/config)
  provisioner "local-exec" {
    command = "talosctl config merge '${local.generated_dir}/talosconfig'"
  }

  triggers_replace = {
    machineconfig_hash = filemd5(local.machineconfig_path)
  }

  lifecycle {
    precondition {
      condition     = fileexists(local.machineconfig_path)
      error_message = "Base machineconfig patch required for setting up Talos cluster"
    }
  }
}

# ------------------------------------------------------------------------------
# Generate patches for Talos nodes with predefined arrtibutes
# ------------------------------------------------------------------------------
resource "local_file" "generate_cp_patch" {
  filename = "${local.generated_dir}/controlplane-patched.yaml"
  content = templatefile(local.machineconfig_path, {
    hostname = "${var.infra}-controlplane"
  })
}

resource "local_file" "generate_wkr_patch" {
  count    = var.worker_count
  filename = "${local.generated_dir}/worker-${count.index}-patched.yaml"
  content = templatefile(local.machineconfig_path, {
    hostname = "${var.infra}-worker-${count.index}"
  })
}

# ------------------------------------------------------------------------------
# Apply patches to base machineconfig to create bootstrap files
# ------------------------------------------------------------------------------
resource "terraform_data" "generate_cp_bootstrap" {
  depends_on = [
    terraform_data.generate_machineconfig,
    local_file.generate_cp_patch
  ]

  triggers_replace = {
    machineconfig_hash      = terraform_data.generate_machineconfig.triggers_replace.machineconfig_hash
    controlplane_patch_hash = local_file.generate_cp_patch.content_md5
  }

  provisioner "local-exec" {
    command = "mkdir -m 0750 -p '${local.machineconfig_dir}'"
  }

  provisioner "local-exec" {
    command = <<-EOT
      talosctl machineconfig patch "${local.cp_machineconfig_path}" \
        --patch @"${local_file.generate_cp_patch.filename}" \
        --output "${local.machineconfig_dir}/controlplane.machineconfig.yaml"
    EOT
  }
}

resource "terraform_data" "generate_wkr_bootstrap" {
  count = var.worker_count

  depends_on = [
    terraform_data.generate_machineconfig,
    local_file.generate_wkr_patch
  ]

  triggers_replace = {
    machineconfig_hash = terraform_data.generate_machineconfig.triggers_replace.machineconfig_hash
    worker_patch_hash  = local_file.generate_wkr_patch[count.index].content_md5
  }

  provisioner "local-exec" {
    command = <<-EOT
      talosctl machineconfig patch ${local.wkr_machineconfig_path} \
        --patch @"${local_file.generate_wkr_patch[count.index].filename}" \
        --output ${local.machineconfig_dir}/worker-${count.index}.machineconfig.yaml
    EOT
  }
}
# ------------------------------------------------------------------------------