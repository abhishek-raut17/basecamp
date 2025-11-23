##################################################################################
# Network Module Outputs
#
# Exposes key resource attributes for use by other modules or the root module:
#   - vpc_id:                ID of the VPC
#   - cluster_subnet_id:     ID of the cluster subnet
#   - dmz_subnet_id:         ID of the DMZ subnet
#   - cluster_subnet_cidr:   CIDR block of the cluster subnet
#   - dmz_subnet_cidr:       CIDR block of the DMZ subnet
##################################################################################

output "vpc_details" {
  depends_on = [
    linode_vpc.vpc,
    linode_vpc_subnet.cluster_subnet
  ]
  description = "VPC and subnet details"
  value = {
    vpc_id              = linode_vpc.vpc.id
    cluster_subnet_id   = linode_vpc_subnet.cluster_subnet.id
    cluster_subnet_cidr = linode_vpc_subnet.cluster_subnet.ipv4
    dmz_subnet_id       = linode_vpc_subnet.dmz_subnet.id
    dmz_subnet_cidr     = linode_vpc_subnet.dmz_subnet.ipv4
  }
}
# ------------------------------------------------------------------------------
