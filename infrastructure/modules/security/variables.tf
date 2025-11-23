##################################################################################
#
# Security Module Variables
#
# Variables:
#   - infra:                    Infrastructure name
#   - cluster_subnet_cidr:      CIDR for cluster subnet
#   - dmz_subnet_cidr:          CIDR for DMZ subnet
##################################################################################

## Infrastructure name
variable "infra" {
  description = "Infrastructure Name"
  type        = string
}

## Cluster Subnet CIDR
variable "cluster_subnet" {
  description = "CIDR block for the Cluster subnet"
  type        = string
}

## DMZ Subnet CIDR
variable "dmz_subnet" {
  description = "CIDR block for the DMZ subnet"
  type        = string
}
# ------------------------------------------------------------------------------