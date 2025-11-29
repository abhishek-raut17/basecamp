# BaseCamp

#TODO: write a good readme
Home lab for hosting private next cloud with side apps for personal, friends and family use

Prerequsities:

1. Linode (Akamai) Account
2. Talos Image in Linode Images (this is needed since no native image in linode)
3. Access to sshkeys and linode token
4. Tools/CLI: curl, terraform, talosctl, kubectl
---

TODO: 
Create a make file to 
1. cp terraform.tfstate to a secure location after apply
---

Steps:
1. Generate SSH keys for linode cluster management and fluxcd access to git
2. Generate Personal Access Token PAT in linode for IaC
3. Install necessary tools: terraform, git, talosctl, kubectl
4. Add public key for fluxcd to deploy keys in github
5. Download and add Talos image from talos and update into linode custom images
6. Validate all required variables for terraform
7. run terraform apply