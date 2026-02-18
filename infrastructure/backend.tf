terraform {

  required_version = ">= 1.5.0"
  backend "local" {
    path = "/home/sentinel/.local/share/basecamp/state/terraform/terraform.tfstate"
  }
  # TODO: Add remote backend configuration for state management (e.g., S3, Terraform Cloud)
}