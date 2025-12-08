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

output "network_details" {
  depends_on = [
    linode_vpc.vpc,
    linode_vpc_subnet.cluster_subnet,
    linode_vpc_subnet.dmz_subnet
  ]
  description = "VPC and subnet details"
  value = {
    vpc = {
      id = linode_vpc.vpc.id
      subnets = [
        {
          name = "cluster_subnet"
          id   = linode_vpc_subnet.cluster_subnet.id
          cidr = linode_vpc_subnet.cluster_subnet.ipv4
        },
        {
          name = "dmz_subnet"
          id   = linode_vpc_subnet.dmz_subnet.id
          cidr = linode_vpc_subnet.dmz_subnet.ipv4
        }
      ]
    }
  }
}
# ------------------------------------------------------------------------------
