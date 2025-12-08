##################################################################################
# Prereq Module Outputs
#
# Exposes key resource attributes for use by other modules or the root module
#
##################################################################################

output "prereq_details" {
  depends_on = [
    local_file.cp_machineconfig,
    local_file.wkr_machineconfig
  ]
  description = "Node metadata and machineconfig details"
  value = {
    controlplane = {
      filename = local_file.cp_machineconfig.filename,
      content  = local_file.cp_machineconfig.content

    },
    workers = [
      for i in range(var.worker_count) : {
        filename = local_file.wkr_machineconfig[i].filename,
        content  = local_file.wkr_machineconfig[i].content
      }
    ]
  }
}
# ------------------------------------------------------------------------------
