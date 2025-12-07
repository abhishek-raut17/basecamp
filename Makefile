# Makefile for Basecamp Project
# 
# Targets:
#   all     - Run prerequisites check and build (default)
#   prereq  - Verify required tools are installed
#   build   - Compile project and submodules
#   clean   - Remove build artifacts and clean submodules
#
# Usage:
#   make           # Build project
#   make clean     # Clean build files
#   make prereq    # Check prerequisites only

# Export environment variables
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Variables
ROOT_DIR := $(CURDIR)
MANIFEST_LIB := $(ROOT_DIR)/manifests
LIB := $(ROOT_DIR)/lib
CLUSTER_LIB := $(LIB)/cluster
LOCAL_LIB := $(LIB)/local
SHARED_LIB := $(LIB)/shared

.PHONY: help all prereq setup build clean

# Generate help man page
help:
	@echo "Project - Make Targets"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Run prerequisites check and build (default)"
	@echo "  prereq   - Verify required tools are installed"
	@echo "  setup    - Setup machine configs for cluster nodes"
	@echo "  build    - Compile project and submodules"
	@echo "  clean    - Remove build artifacts and clean submodules"
	@echo "  help     - Show this help message"
	@echo ""

# Run all build/deploy/cleanup targets
all: prereq setup build clean

# Check and ready localhost machine for cluster management
prereq:
	@if [ ! -f $(LOCAL_LIB)/bin/prereq.sh ]; then echo "Prerequisites binary not found."; exit 1; fi
	@$(LOCAL_LIB)/bin/prereq.sh
	@if [ $$? -ne 0 ]; then echo "Prerequisites check failed"; exit 1; fi

# Setup configs for build phase
setup:
	@$(CLUSTER_LIB)/bin/setup.sh

# Plan and deploy infrastructure including CNI plugin and fluxcd
build: prereq setup

# Cleanup stale resources
clean:
	@$(LOCAL_LIB)/bin/cleanup.sh
