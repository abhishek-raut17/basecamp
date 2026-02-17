# Makefile for Basecamp Project - Modular & Orchestration-Driven
#
# Architecture:
#   - Makefile: Orchestration layer (env validation, error handling, sequencing)
#   - lib/shared/: Common utilities (logging, validation, file operations)
#   - lib/scripts/: Modular components (install_tool.sh, configure_*.sh, etc.)
#   - lib/tests/: Test suite for each component
#
# Usage: make [target]

# ============================================================================
# Environment Setup
# ============================================================================

SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.EXPORT_ALL_VARIABLES:

ROOT_DIR := $(CURDIR)
INFRA_DIR := $(ROOT_DIR)/infrastructure
LIB_DIR := $(ROOT_DIR)/lib
SCRIPTS_DIR := $(LIB_DIR)/scripts
TESTS_DIR := $(LIB_DIR)/tests

# Load environment variables from .env if it exists
ifneq (,$(wildcard .env))
    include .env
endif
export

# ============================================================================
# Color Output & Logging
# ============================================================================

COLOR_RESET := \033[0m
COLOR_INFO := \033[1;34m
COLOR_SUCCESS := \033[1;32m
COLOR_ERROR := \033[1;31m
COLOR_WARN := \033[1;33m

define log_info
	printf "%b\n" "$(COLOR_INFO)[INFO ]$(COLOR_RESET) $$(date '+%Y-%m-%d %H:%M:%S') - $(1)" >&2
endef

define log_success
	printf "%b\n" "$(COLOR_SUCCESS)[OK   ]$(COLOR_RESET) $$(date '+%Y-%m-%d %H:%M:%S') - $(1)" >&2
endef

define log_error
	printf "%b\n" "$(COLOR_ERROR)[ERROR]$(COLOR_RESET) $$(date '+%Y-%m-%d %H:%M:%S') - $(1)" >&2
endef

define log_warn
	printf "%b\n" "$(COLOR_WARN)[WARN ]$(COLOR_RESET) $$(date '+%Y-%m-%d %H:%M:%S') - $(1)" >&2
endef

# ============================================================================
# Utility Functions
# ============================================================================

# Validate that a required file exists
define validate_file
	@if [ ! -f "$(1)" ]; then \
		$(call log_error,Required file not found: $(1)); \
		exit 1; \
	fi
endef

# Validate that a directory exists
define validate_dir
	@if [ ! -d "$(1)" ]; then \
		$(call log_error,Required directory not found: $(1)); \
		exit 1; \
	fi
endef

# ============================================================================
# Validation Targets
# ============================================================================

.PHONY: validate-make validate test-prereq test-setup test-plan test

validate-make:
	@$(call log_info,Validating required files for make)
	@$(call validate_dir,$(SCRIPTS_DIR))
	@$(call validate_dir,$(TESTS_DIR))
	@$(call validate_file,$(SCRIPTS_DIR)/validate_env.sh)
	@$(call log_success,Required files for make are valid)

validate: validate-make
	@$(SCRIPTS_DIR)/validate_env.sh
	@$(SCRIPTS_DIR)/sshkey_gen.sh

test-prereq:
	@$(TESTS_DIR)/test-prereq.sh

test-setup:
	@$(TESTS_DIR)/test-setup.sh

test-plan:
	@${TESTS_DIR}/test-plan.sh

test: test-prereq test-setup test-plan

# ============================================================================
# Core Targets
# ============================================================================

.PHONY: all prereq setup plan build post-build

# Default core target
all: build post-build

prereq: validate
	@$(SCRIPTS_DIR)/prereq.sh

setup: prereq test-prereq
	@$(SCRIPTS_DIR)/setup.sh

plan: setup test-setup
	@$(SCRIPTS_DIR)/plan.sh

build: plan test-plan
	@$(SCRIPTS_DIR)/build.sh

post-build:
	@$(SCRIPTS_DIR)/post_build.sh

# ============================================================================
# Maintainance Targets
# ============================================================================

.PHONY: clean destroy

clean: destroy
	@$(SCRIPTS_DIR)/cleanup.sh

destroy:
	@$(SCRIPTS_DIR)/destroy.sh

# ============================================================================
# Info Targets
# ============================================================================

.PHONY: help info

help:
	@printf "%b\n" "$(COLOR_INFO)════════════════════════════════════════════════════════════$(COLOR_RESET)" >&2
	@printf "%b\n" "$(COLOR_INFO)Basecamp Project [Release: $(RELEASE_VERSION)] - Makefile Targets$(COLOR_RESET)" >&2
	@printf "%b\n" "$(COLOR_INFO)════════════════════════════════════════════════════════════$(COLOR_RESET)" >&2
	@echo ""
	@printf "%b\n" "$(COLOR_SUCCESS)Core Targets:$(COLOR_RESET)" >&2
	@printf "%b\n" "  make all              - Run full setup (prereq → setup → plan → build)" >&2
	@printf "%b\n" "  make prereq           - Verify and install required tools" >&2
	@printf "%b\n" "  make setup            - Configure local and remote nodes" >&2
	@printf "%b\n" "  make plan             - Plan infrastructure resources" >&2
	@printf "%b\n" "  make build            - Deploy cluster infrastructure" >&2
	@echo ""
	@printf "%b\n" "$(COLOR_SUCCESS)Validation Targets:$(COLOR_RESET)" >&2
	@printf "%b\n" "  make test             - Run all test suites" >&2
	@printf "%b\n" "  make validate         - Validate environment and files" >&2
	@echo ""
	@printf "%b\n" "$(COLOR_SUCCESS)Maintenance Targets:$(COLOR_RESET)" >&2
	@printf "%b\n" "  make clean            - Remove build artifacts" >&2
	@printf "%b\n" "  make destroy          - Destroy infrastructure (CRITICAL)" >&2
	@echo ""
	@printf "%b\n" "$(COLOR_SUCCESS)Info:$(COLOR_RESET)" >&2
	@printf "%b\n" "  make info             - Display environment and configuration info" >&2
	@printf "%b\n" "  make help             - Show this help message" >&2
	@echo ""

info:
	$(call log_info,Configuration Information)
	@printf "%b\n" "  Cluster Name:         $(CLUSTER_NAME)" >&2
	@printf "%b\n" "  Scripts Directory:    $(SCRIPTS_DIR)" >&2
	@printf "%b\n" "  Tests Directory:      $(TESTS_DIR)" >&2
	@echo ""

# ============================================================================
