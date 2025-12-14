# Makefile for Basecamp Project
# 
# Targets:
#   all     - Run prerequisites check and build (default)
#   prereq  - Verify required tools are installed
#	setup	- 
#	plan	-	
#   build   - Compile project and submodules
#   clean   - Remove build artifacts and clean submodules
#

# Export environment variables
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Variables
SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
ROOT_DIR := $(CURDIR)
MANIFEST_LIB := $(ROOT_DIR)/manifests
LIB := $(ROOT_DIR)/lib
INFRA_DIR := $(ROOT_DIR)/infrastructure
CLUSTER_LIB := $(LIB)/cluster
LOCAL_LIB := $(LIB)/local
SHARED_LIB := $(LIB)/shared

# Tasks
.PHONY: all help prereq setup plan build clean

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
	@echo "  plan     - Plan cluster infrastructure resources"
	@echo "  build    - Compile project and submodules"
	@echo "  clean    - Remove build artifacts and clean submodules"
	@echo "  help     - Show this help message"
	@echo ""

# Run all build/deploy/cleanup targets
all: prereq setup plan build clean

# Check and ready localhost machine for cluster management
prereq:
	@if [ ! -f $(LOCAL_LIB)/bin/prereq.sh ]; then echo "Prerequisites binary not found."; exit 1; fi
	@$(LOCAL_LIB)/bin/prereq.sh
	@if [ $$? -ne 0 ]; then echo "Prerequisites check failed"; exit 1; fi

# Setup configs for build phase
setup:
	@if [ ! -f $(CLUSTER_LIB)/bin/setup.sh ]; then echo "Cluster setup binary not found."; exit 1; fi
	@$(CLUSTER_LIB)/bin/setup.sh

# Plan infrastructure 
plan:
	@if [ ! -f $(CLUSTER_LIB)/bin/plan.sh ]; then echo "Cluster build plan binary not found."; exit 1; fi
	@$(CLUSTER_LIB)/bin/plan.sh

# Build cluster resources
build: prereq setup plan
	@if [ ! -f $(CLUSTER_LIB)/bin/build.sh ]; then echo "Cluster build binary not found."; exit 1; fi
	@$(CLUSTER_LIB)/bin/build.sh

# Cleanup stale resources
clean:
	@if [ ! -f $(LOCAL_LIB)/bin/cleanup.sh ]; then echo "Cluster setup binary not found."; exit 1; fi
	@$(LOCAL_LIB)/bin/cleanup.sh
