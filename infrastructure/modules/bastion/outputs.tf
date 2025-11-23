##################################################################################
# Bastion Module Outputs
#
# Exposes key resource attributes for use by other modules or the root module:
#   - bastion_id:                ID of Bastion host
#   - bastion_public_ip:         Public IP address of Bastion host
#   - bastion_private_ip:        Private IP address of Bastion host
##################################################################################

output "bastion_details" {
  depends_on = [
    linode_instance.bastion,
    data.linode_instance_networking.bastion_network
  ]
  description = "Bastion Host details"
  value = {
    id        = linode_instance.bastion.id,
    public_ip = local.public_ip,
    vpc_ip    = local.vpc_ip
  }
}
# ------------------------------------------------------------------------------
