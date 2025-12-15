##################################################################################
#
# Loadbalancer Module Variables
#
# Variables:
#   - infra:                    Infrastructure name
#   - region:                   Linode cluster region
#   - firewall_id:              Firewall ID for nodebalancer (gateway-lb)
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

## Firewall ID for nodebalancer (gateway-lb)
variable "firewall_id" {
  description = "Firewall ID for Nodebalancer"
  type        = string
}
# ------------------------------------------------------------------------------