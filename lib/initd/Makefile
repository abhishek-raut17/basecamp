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
#   make init --cluster-name=basecamp --ccm-token=<token>
#   make prereq
#   make bootstrap
#   make day0
#

# Get the directory where this Makefile is located
MAKEFILE_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

# Color output
BOLD := \033[1m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
RESET := \033[0m

# Default target
.DEFAULT_GOAL := help

.PHONY: init prereq bootstrap day0 help
.PHONY: confirm-init confirm-prereq confirm-bootstrap confirm-day0

# ===============================================================================
# Help Target
# ===============================================================================
help:
	@echo "$(BOLD)$(BLUE)Basecamp Cluster Initialization$(RESET)"
	@echo ""
	@echo "$(BOLD)Usage: make [target] [options]$(RESET)"
	@echo ""
	@echo "$(BOLD)Targets (run in order):$(RESET)"
	@echo "  $(GREEN)init$(RESET)       - Pre-initialization and configuration validation (prerequisite)"
	@echo "  $(GREEN)prereq$(RESET)     - Install prerequisites and configure talos (steps 1-4)"
	@echo "  $(GREEN)bootstrap$(RESET)  - Bootstrap cluster nodes and kubeconfig (steps 5-6)"
	@echo "  $(GREEN)day0$(RESET)       - Deploy operators, networking, storage (steps 7-16)"
	@echo "  $(GREEN)help$(RESET)       - Display this help message"
	@echo ""
	@echo "$(BOLD)Configuration Variables (passed to init):$(RESET)"
	@echo "  --cluster-name=<name>              Cluster name (default: basecamp)"
	@echo "  --cluster-endpoint=<ip>            Cluster endpoint IP (default: 10.0.10.10)"
	@echo "  --cluster-subnet=<cidr>            Cluster subnet CIDR (default: 10.0.10.0/24)"
	@echo "  --ccm-token=<token>                Cloud provider API token (REQUIRED)"
	@echo "  --cloud-region=<region>            Cloud region (default: us-ord)"
	@echo "  --git-repo=<url>                   Git repository URL"
	@echo "  --talos-version=<version>          Talos version (default: v1.11.2)"
	@echo "  --kube-version=<version>           Kubectl version (default: v1.34.1)"
	@echo "  --kubeseal-version=<version>       Kubeseal version (default: v0.30.0)"
	@echo "  --k8s-gateway-version=<version>    Gateway API version (default: v1.4.1)"
	@echo "  --cert-manager-plugin-version=<version>  Cert-manager version (default: v0.2.0)"
	@echo ""
	@echo "$(BOLD)Example Usage:$(RESET)"
	@echo "  $$ make init --cluster-name=basecamp --cluster-endpoint=10.0.10.10 \\\\"
	@echo "       --cluster-subnet=10.0.10.0/24 --ccm-token=<your-token>"
	@echo "  $$ make prereq"
	@echo "  $$ make bootstrap"
	@echo "  $$ make day0"
	@echo ""
	@echo "$(BOLD)Environment Setup:$(RESET)"
	@echo "  After running these targets, the following environment variables"
	@echo "  will be set and available in /root/.bashrc:"
	@echo "    - TALOSCONFIG=/root/.talos/config"
	@echo "    - KUBECONFIG=/root/.kube/config"
	@echo ""

# ===============================================================================
# Init Target: Prerequisite for all other targets
# ===============================================================================
init: confirm-init
	@echo "$(BOLD)$(BLUE) -> Running: init - Pre-initialization and configuration validation$(RESET)"
	@echo ""
	@if [ ! -f "$(MAKEFILE_DIR)bin/init.sh" ]; then \
		echo "$(BOLD)Error: init.sh not found at $(MAKEFILE_DIR)bin/init.sh$(RESET)"; \
		exit 1; \
	fi
	@chmod +x "$(MAKEFILE_DIR)bin/init.sh"
	@"$(MAKEFILE_DIR)bin/init.sh" $(ARGS)
	@echo ""
	@echo "$(BOLD)$(GREEN) + + + Init completed successfully + + + $(RESET)"
	@echo ""

# ===============================================================================
# Prereq Target: Steps 1-4
# ===============================================================================
prereq: init confirm-prereq
	@echo "$(BOLD)$(BLUE) -> Running: prereq - Prerequisites and Talos configuration$(RESET)"
	@echo ""
	@if [ ! -f "$(MAKEFILE_DIR)bin/prereq.sh" ]; then \
		echo "$(BOLD)Error: prereq.sh not found at $(MAKEFILE_DIR)bin/prereq.sh$(RESET)"; \
		exit 1; \
	fi
	@chmod +x "$(MAKEFILE_DIR)bin/prereq.sh"
	@"$(MAKEFILE_DIR)bin/prereq.sh"
	@echo ""
	@echo "$(BOLD)$(GREEN) + + + Prereq completed successfully + + + $(RESET)"
	@echo ""

# ===============================================================================
# Bootstrap Target: Steps 5-6
# ===============================================================================
bootstrap: prereq confirm-bootstrap
	@echo "$(BOLD)$(BLUE) -> Running: bootstrap - Cluster and kubeconfig initialization$(RESET)"
	@echo ""
	@if [ ! -f "$(MAKEFILE_DIR)bin/bootstrap.sh" ]; then \
		echo "$(BOLD)Error: bootstrap.sh not found at $(MAKEFILE_DIR)bin/bootstrap.sh$(RESET)"; \
		exit 1; \
	fi
	@chmod +x "$(MAKEFILE_DIR)bin/bootstrap.sh"
	@"$(MAKEFILE_DIR)bin/bootstrap.sh"
	@echo ""
	@echo "$(BOLD)$(GREEN) + + + Bootstrap completed successfull + + + $(RESET)"
	@echo ""

# ===============================================================================
# Day0 Target: Steps 7-16
# ===============================================================================
day0: confirm-day0
	@echo "$(BOLD)$(BLUE) -> Running: day0 - Operators, networking, storage, and services deployment$(RESET)"
	@echo ""
	@if [ ! -f "$(MAKEFILE_DIR)day0.sh" ]; then \
		echo "$(BOLD)Error: day0.sh not found at $(MAKEFILE_DIR)bin/day0.sh$(RESET)"; \
		exit 1; \
	fi
	@chmod +x "$(MAKEFILE_DIR)bin/day0.sh"
	@"$(MAKEFILE_DIR)bin/day0.sh"
	@echo ""
	@echo "$(BOLD)$(GREEN) + + + Day0 completed successfully + + + $(RESET)"
	@echo ""

# ===============================================================================
# Confirmation Targets
# ===============================================================================

confirm-init:
	@echo "$(BOLD)$(YELLOW)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(BOLD)$(BLUE)Init - Pre-initialization and Configuration Validation$(RESET)"
	@echo "$(BOLD)$(YELLOW)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@read -p "$(BOLD)Continue with init? (y/n): $(RESET)" confirm; \
	if [ "$$confirm" != "y" ]; then \
		echo "$(YELLOW)✗ Aborted by user$(RESET)"; \
		exit 1; \
	fi

confirm-prereq:
	@echo "$(BOLD)$(YELLOW)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(BOLD)$(BLUE)Prerequisites - Install binaries and configure Talos$(RESET)"
	@echo "$(BOLD)$(YELLOW)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@read -p "$(BOLD)Continue with prereq? (y/n): $(RESET)" confirm; \
	if [ "$$confirm" != "y" ]; then \
		echo "$(YELLOW)✗ Aborted by user$(RESET)"; \
		exit 1; \
	fi

confirm-bootstrap:
	@echo "$(BOLD)$(YELLOW)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(BOLD)$(BLUE)Bootstrap - Initialize cluster and kubeconfig$(RESET)"
	@echo "$(BOLD)$(YELLOW)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@read -p "$(BOLD)Continue with bootstrap? (y/n): $(RESET)" confirm; \
	if [ "$$confirm" != "y" ]; then \
		echo "$(YELLOW)✗ Aborted by user$(RESET)"; \
		exit 1; \
	fi

confirm-day0:
	@echo "$(BOLD)$(YELLOW)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(BOLD)$(BLUE)Day0 - Deploy Operators, Networking, Storage, and Services$(RESET)"
	@echo "$(BOLD)$(YELLOW)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@read -p "$(BOLD)Continue with day0? (y/n): $(RESET)" confirm; \
	if [ "$$confirm" != "y" ]; then \
		echo "$(YELLOW)✗ Aborted by user$(RESET)"; \
		exit 1; \
	fi

# ===============================================================================
