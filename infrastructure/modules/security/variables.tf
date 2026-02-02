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
variable "subnet" {
  description = "CIDR block for the Cluster subnet"
  type = object({
    cluster = object({
      cidr = string,
      id   = string
    })
    dmz = object({
      cidr = string,
      id   = string
    })
  })
}
# ------------------------------------------------------------------------------