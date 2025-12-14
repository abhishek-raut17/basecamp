# BaseCamp

#TODO: write a good readme
Home lab for hosting private next cloud with side apps for personal, friends and family use

## Prerequsities:

1. Linode (Akamai) Account
2. Talos Image in Linode Images (this is needed since no native image in linode)
3. Generate ssh-key for secured access to bastion host for cluster maintainance and linode token
4. Tools/CLI: curl, terraform, talosctl, kubectl, helm
---

## TODO: 
1. cp terraform.tfstate to a secure location after apply
---

## Repository steps:
1. Generate Personal Access Token PAT in linode for IaC and github for CD (fluxcd)
2. Download and add Talos image from talos and update into linode custom images
3. Run make
    3.0. Check and validate required variables, tool vesions and paths in .env file
    3.1. Download all the required binaries for operations (talosctl, kubectl, helm)
    3.2. Generate SSH keys to be used for bastion access
    3.3. Generate and validate machineconfigs for cluster nodes (along with CNI plugin)
    3.4. Build and run cluster provisioning with terraform
    3.5. Bootstrap cluster via bastion
    3.6. Install and provision FluxCD components
4. Provision traefik via fluxcd using manifests/helm
5. Provision cert-manager via fluxcd using manifests/helm
6. Provision headlamp via fluxcd using manifests/helm
7. Provision longhorn via fluxcd using manifests/helm
8. Make sure that there is a `cni.secret.yaml` at the `manifests/patches/` path. This will be used by cilium for secrets
9. Helm template should be run before of `make all` and the generated `cni.cilium.yaml` should be split into `custom.cni.yaml` and `cni.secret.yaml` and stored in respective places
10. Update `infrastructure/terraform.tfvars` with the required values. Refer to `infrastructure/terraform.tfvars.template` for required variables
11. Refer to `.env.template` for env variables for make file

## Helm command for generating template of CNI plugin (Cilium)

```
helm template cilium cilium/cilium \
  --version 1.18.0 \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.tls.auto.enabled=true \
  --set hubble.tls.auto.method=cronJob \
  --set kubeProxyReplacement=true \
  --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
  --set cgroup.autoMount.enabled=false \
  --set cgroup.hostRoot=/sys/fs/cgroup \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=7445 \
  --set gatewayAPI.enabled=true \
  --set gatewayAPI.enableAlpn=true \
  --set gatewayAPI.enableAppPrototcol=true \
  > custom.cni.yaml
```
