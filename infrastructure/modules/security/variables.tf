##################################################################################
#
# Security Module Variables
#
# Variables:
#   - infra:                    Infrastructure name
#   - subnet:                   Subnet CIDRs
##################################################################################

## Infrastructure name
variable "infra" {
  description = "Infrastructure Name"
  type        = string
}

## Subnet CIDRs
variable "subnets" {
  description = "CIDR block for the subnets (cluster and DMZ)"
  type = list(object({
    name = string
    id   = string
    cidr = string
  }))
}
# ------------------------------------------------------------------------------