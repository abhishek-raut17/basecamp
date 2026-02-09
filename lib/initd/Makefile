# ===============================================================================
# Basecamp Cluster Initialization Makefile
# ===============================================================================
#
# This Makefile provides targets for cluster initialization.
# Can be used independently - just run: make -f /path/to/Makefile [target]
#
# Targets (run in order):
#   init       - Pre-initialization and configuration validation
#   prereq     - Install prerequisites and configure talos (steps 1-4)
#   bootstrap  - Bootstrap cluster nodes and kubeconfig (steps 5-6)
#   day0       - Deploy operators, networking, storage (steps 7-16)
#   help       - Display this help message
#
# Example:
#   make init CLUSTER_NAME=basecamp CLOUD_PROVIDER_PAT=<token>
#   make prereq
#   make bootstrap
#   make day0
#

# Get the directory where this Makefile is located
MAKEFILE_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

# ===============================================================================
# Configuration Variables (can be overridden via environment or make arguments)
# ===============================================================================

# Versions
RELEASE_VERSION ?= v1.0.0
VERSION ?= v1.0.0
LOG_LEVEL ?= 0

# Directory paths
TALOS_DIR ?= /root/.talos
KUBE_DIR ?= /root/.kube
INITD ?= /usr/local/lib/initd

# Repository and credentials
GIT_REPO ?= ssh://git@github.com/abhishek-raut17/basecamp.git
FLUXCD_SSHKEY_PATH ?= /tmp/devops_cd
CLOUD_PROVIDER_PAT ?=
CLOUD_PROVIDER_REGION ?= us-ord

# Tool versions
VERSION_TALOSCTL ?= v1.11.2
VERSION_KUBECTL ?= v1.34.1
VERSION_FLUXCD ?=
VERSION_HELM ?=
VERSION_GATEWAY_API ?= v1.4.1
VERSION_CRT_MNG_PLUGIN ?= v0.2.0
VERSION_KUBESEAL ?= v0.30.0

# Download URLs
TALOSCTL_URL ?= https://github.com/siderolabs/talos/releases/download/$(VERSION_TALOSCTL)
KUBECTL_URL ?= https://dl.k8s.io/release/$(VERSION_KUBECTL)/bin/linux/amd64
FLUXCD_URL ?= https://fluxcd.io/install.sh
HELM_URL ?= https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
K8S_GATEWAY_API ?= https://github.com/kubernetes-sigs/gateway-api/releases/download/$(VERSION_GATEWAY_API)/standard-install.yaml
CERT_MNG_PLUGIN ?= https://github.com/slicen/cert-manager-webhook-linode/releases/download/$(VERSION_CRT_MNG_PLUGIN)/cert-manager-webhook-linode-$(VERSION_CRT_MNG_PLUGIN).tgz
KUBESEAL_URL ?= https://github.com/bitnami-labs/sealed-secrets/releases/download/$(VERSION_KUBESEAL)/kubeseal-$(VERSION_KUBESEAL:v%=%)-linux-amd64.tar.gz
KUBESEAL_CONTOLLER_URL ?= https://github.com/bitnami-labs/sealed-secrets/releases/download/$(VERSION_KUBESEAL)/controller.yaml

# Nginx configuration
NGINX_DIR ?= $(INITD)/modules/nginx-gateway
NGINX_CONF ?= $(NGINX_DIR)/nginx.conf
NGINX_STREAM_CONF ?= $(NGINX_DIR)/nginx-stream.conf
NGINX_TUNING_CONF ?= $(NGINX_DIR)/99-nginx-tuning.conf

# Cluster configuration
CLUSTER_NAME ?= basecamp
CLUSTER_SUBNET ?= 10.0.10.0/24
CLUSTER_ENDPOINT ?= 10.0.10.10

# Regex patterns for validation
IPHOST_REGEX := ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$$
SUBNET_REGEX := ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/([0-9]|[1-2][0-9]|3[0-2])$$

# Export all variables for use in shell commands
export RELEASE_VERSION VERSION LOG_LEVEL TALOS_DIR KUBE_DIR INITD GIT_REPO FLUXCD_SSHKEY_PATH CLOUD_PROVIDER_PAT CLOUD_PROVIDER_REGION
export VERSION_TALOSCTL VERSION_KUBECTL VERSION_FLUXCD VERSION_HELM VERSION_GATEWAY_API VERSION_CRT_MNG_PLUGIN VERSION_KUBESEAL
export TALOSCTL_URL KUBECTL_URL FLUXCD_URL HELM_URL K8S_GATEWAY_API CERT_MNG_PLUGIN KUBESEAL_URL KUBESEAL_CONTOLLER_URL
export NGINX_DIR NGINX_CONF NGINX_STREAM_CONF NGINX_TUNING_CONF
export CLUSTER_NAME CLUSTER_SUBNET CLUSTER_ENDPOINT

# Default target
.DEFAULT_GOAL := help

.PHONY: init prereq bootstrap day0 help validate-init
.PHONY: confirm-init confirm-prereq confirm-bootstrap confirm-day0

# ===============================================================================
# Help Target
# ===============================================================================
help:
	@echo "Basecamp Cluster Initialization"
	@echo ""
	@echo "Usage: make [target] [VARIABLE=value ...]"
	@echo ""
	@echo "Targets (run in order):"
	@echo "  init       - Pre-initialization and configuration validation (prerequisite)"
	@echo "  prereq     - Install prerequisites and configure talos (steps 1-4)"
	@echo "  bootstrap  - Bootstrap cluster nodes and kubeconfig (steps 5-6)"
	@echo "  day0       - Deploy operators, networking, storage (steps 7-16)"
	@echo "  help       - Display this help message"
	@echo ""
	@echo "Configuration Variables:"
	@echo "  CLUSTER_NAME=<name>              Cluster name (default: $(CLUSTER_NAME))"
	@echo "  CLUSTER_ENDPOINT=<ip>            Cluster endpoint IP (default: $(CLUSTER_ENDPOINT))"
	@echo "  CLUSTER_SUBNET=<cidr>            Cluster subnet CIDR (default: $(CLUSTER_SUBNET))"
	@echo "  CLOUD_PROVIDER_PAT=<token>       Cloud provider API token (REQUIRED)"
	@echo "  CLOUD_PROVIDER_REGION=<region>   Cloud region (default: $(CLOUD_PROVIDER_REGION))"
	@echo "  GIT_REPO=<url>                   Git repository URL (default: $(GIT_REPO))"
	@echo "  VERSION_TALOSCTL=<version>       Talos version (default: $(VERSION_TALOSCTL))"
	@echo "  VERSION_KUBECTL=<version>        Kubectl version (default: $(VERSION_KUBECTL))"
	@echo "  VERSION_KUBESEAL=<version>       Kubeseal version (default: $(VERSION_KUBESEAL))"
	@echo "  VERSION_GATEWAY_API=<version>    Gateway API version (default: $(VERSION_GATEWAY_API))"
	@echo "  VERSION_CRT_MNG_PLUGIN=<version> Cert-manager version (default: $(VERSION_CRT_MNG_PLUGIN))"
	@echo ""
	@echo "Example Usage:"
	@echo "  $$ make init CLUSTER_NAME=basecamp CLUSTER_ENDPOINT=10.0.10.10 \\"
	@echo "       CLUSTER_SUBNET=10.0.10.0/24 CLOUD_PROVIDER_PAT=<your-token>"
	@echo "  $$ make prereq"
	@echo "  $$ make bootstrap"
	@echo "  $$ make day0"
	@echo ""
	@echo "Environment Variables:"
	@echo "  All configuration variables are exported and available to scripts."
	@echo "  After init, TALOSCONFIG and KUBECONFIG will be available at:"
	@echo "    - TALOSCONFIG=$(TALOS_DIR)/config"
	@echo "    - KUBECONFIG=$(KUBE_DIR)/config"
	@echo ""

# ===============================================================================
# Validation functions
# ===============================================================================

validate-init: 
	@echo "-> Running: Validation"
	@echo ""
	@if [ ! -d "$(INITD)" ]; then \
		echo "Error: INITD directory does not exist: $(INITD)"; \
		exit 1; \
	fi
	@if [ ! -f "$(INITD)/run.sh" ]; then \
		echo "Error: Run module not found: $(INITD)/run.sh"; \
		exit 1; \
	fi
	@if [ ! -f "$(INITD)/bin/shared/logger.sh" ]; then \
		echo "Error: Logger module not found: $(INITD)/bin/shared/logger.sh"; \
		exit 1; \
	fi
	@if [ ! -f "$(INITD)/bin/shared/utils.sh" ]; then \
		echo "Error: Utils module not found: $(INITD)/bin/shared/utils.sh"; \
		exit 1; \
	fi
	@if [ -z "$(CLOUD_PROVIDER_PAT)" ]; then \
		echo "Error: Cloud provider token not provided. Please use CLOUD_PROVIDER_PAT parameter"; \
		exit 1; \
	fi
	@if ! echo "$(CLUSTER_ENDPOINT)" | grep -qE '$(IPHOST_REGEX)'; then \
		echo "Error: Invalid cluster endpoint format: $(CLUSTER_ENDPOINT)"; \
		exit 1; \
	fi
	@if ! echo "$(CLUSTER_SUBNET)" | grep -qE '$(SUBNET_REGEX)'; then \
		echo "Error: Invalid cluster subnet format: $(CLUSTER_SUBNET)"; \
		exit 1; \
	fi
	@if [ -z "$(CLUSTER_NAME)" ]; then \
		echo "Error: Cluster name cannot be empty"; \
		exit 1; \
	fi

# ===============================================================================
# Init Target: Prerequisite for all other targets
# ===============================================================================
init: validate-init confirm-init
	@echo "-> Configuration Validation Complete"
	@echo ""
	@echo "Cluster Configuration Summary:"
	@echo "  Cluster name      : $(CLUSTER_NAME)"
	@echo "  Cluster endpoint  : $(CLUSTER_ENDPOINT)"
	@echo "  Cluster subnet    : $(CLUSTER_SUBNET)"
	@echo "  Talos version     : $(VERSION_TALOSCTL)"
	@echo "  Kubectl version   : $(VERSION_KUBECTL)"
	@echo "  Cloud region      : $(CLOUD_PROVIDER_REGION)"
	@echo "  Git repo          : $(GIT_REPO)"
	@echo ""
	@echo "+ + + Init completed successfully + + +"
	@echo ""

# ===============================================================================
# Prereq Target: Steps 1-4
# ===============================================================================
prereq: init confirm-prereq
	@echo "-> Running: prereq - Prerequisites and Talos configuration"
	@echo ""
	@if [ ! -f "$(MAKEFILE_DIR)bin/prereq.sh" ]; then \
		echo "Error: prereq.sh not found at $(MAKEFILE_DIR)bin/prereq.sh"; \
		exit 1; \
	fi
	@chmod +x "$(MAKEFILE_DIR)bin/prereq.sh"
	@echo "Using exported configuration variables:"
	@echo "  CLUSTER_NAME=$(CLUSTER_NAME)"
	@echo "  CLUSTER_ENDPOINT=$(CLUSTER_ENDPOINT)"
	@echo "  CLUSTER_SUBNET=$(CLUSTER_SUBNET)"
	@echo ""
	@"$(MAKEFILE_DIR)bin/prereq.sh"
	@echo ""
	@echo "+ + + Prereq completed successfully + + +"
	@echo ""

# ===============================================================================
# Bootstrap Target: Steps 5-6
# ===============================================================================
bootstrap: prereq confirm-bootstrap
	@echo "-> Running: bootstrap - Cluster and kubeconfig initialization"
	@echo ""
	@if [ ! -f "$(MAKEFILE_DIR)bin/bootstrap.sh" ]; then \
		echo "Error: bootstrap.sh not found at $(MAKEFILE_DIR)bin/bootstrap.sh"; \
		exit 1; \
	fi
	@chmod +x "$(MAKEFILE_DIR)bin/bootstrap.sh"
	@"$(MAKEFILE_DIR)bin/bootstrap.sh"
	@echo ""
	@echo "+ + + Bootstrap completed successfully + + +"
	@echo ""

# ===============================================================================
# Day0 Target: Steps 7-16
# ===============================================================================
day0: confirm-day0
	@echo "-> Running: day0 - Operators, networking, storage, and services deployment"
	@echo ""
	@if [ ! -f "$(MAKEFILE_DIR)bin/day0.sh" ]; then \
		echo "Error: day0.sh not found at $(MAKEFILE_DIR)bin/day0.sh"; \
		exit 1; \
	fi
	@chmod +x "$(MAKEFILE_DIR)bin/day0.sh"
	@"$(MAKEFILE_DIR)bin/day0.sh"
	@echo ""
	@echo "+ + + Day0 completed successfully + + +"
	@echo ""

# ===============================================================================
# Confirmation Targets
# ===============================================================================

confirm-init:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Init - Pre-initialization and Configuration Validation"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo ""
	@read -p "Continue with init? (y/n): " confirm; \
	if [ "$$confirm" != "y" ]; then \
		echo "Aborted by user"; \
		exit 1; \
	fi

confirm-prereq:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Prerequisites - Install binaries and configure Talos"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo ""
	@read -p "Continue with prereq? (y/n): " confirm; \
	if [ "$$confirm" != "y" ]; then \
		echo "Aborted by user"; \
		exit 1; \
	fi

confirm-bootstrap:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Bootstrap - Initialize cluster and kubeconfig"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo ""
	@read -p "Continue with bootstrap? (y/n): " confirm; \
	if [ "$$confirm" != "y" ]; then \
		echo "Aborted by user"; \
		exit 1; \
	fi

confirm-day0:
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "Day0 - Deploy Operators, Networking, Storage, and Services"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo ""
	@read -p "Continue with day0? (y/n): " confirm; \
	if [ "$$confirm" != "y" ]; then \
		echo "Aborted by user"; \
		exit 1; \
	fi

# ===============================================================================
