##################################################################################
#
# Network Module Variables
#
# Variables:
#   - infra:                    Project name
#   - region:                   Linode cluster region
#   - vpc_cidr:                 VPC CIDR range
##################################################################################

## Infrastructure name
variable "infra" {
  description = "Infrastructure Name"
  type        = string
}

## Linode Region
variable "region" {
  description = "Linode Region"
  type        = string
}

## VPC CIDR
variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}
# ------------------------------------------------------------------------------