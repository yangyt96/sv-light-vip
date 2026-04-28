# sv-light-vip Makefile
# Provides convenient targets for linting, formatting, and testing.
#
# Docker Usage (default):
#   make lint              # Run Verible lint via Docker
#   make format            # Auto-format via Docker
#   make format-check      # Check formatting via Docker
#   make test              # Run all regression tests via Docker (ModelSim)
#   make test-<vip>        # Run single VIP test via Docker (e.g., make test-apb_vip)
#
# Local Usage (override Docker):
#   make lint DOCKER=0     # Run Verible lint locally
#   make test DOCKER=0     # Run tests locally (requires local VUnit + ModelSim)
#
# Advanced:
#   make lint VERIBLE_IMAGE=my-verible:latest
#   make test MODELSIM_IMAGE=modelsim:2023.1
#   make clean

SHELL := /bin/bash

# ============================================================
# Docker Configuration
# ============================================================

# Set DOCKER=0 to run tools locally instead of via Docker
DOCKER ?= 1

# Docker images
VERIBLE_IMAGE   ?= ghcr.io/yangyt96/verible:latest
MODELSIM_IMAGE  ?= modelsim:20.1

# Common Docker run options
DOCKER_RUN := docker run --rm -v $(PWD):/work -w /work

# Verible commands (Docker vs local)
ifeq ($(DOCKER),1)
  VERIBLE_LINT_CMD := $(DOCKER_RUN) --entrypoint verible-verilog-lint $(VERIBLE_IMAGE)
  VERIBLE_FMT_CMD  := $(DOCKER_RUN) --entrypoint verible-verilog-format $(VERIBLE_IMAGE)
else
  VERIBLE_LINT_CMD := verible-verilog-lint
  VERIBLE_FMT_CMD  := verible-verilog-format
endif

# ModelSim test command (Docker vs local)
ifeq ($(DOCKER),1)
  TEST_PREFIX := $(DOCKER_RUN) --entrypoint /bin/bash $(MODELSIM_IMAGE) -c
else
  TEST_PREFIX :=
endif

VERIBLE_RULES ?= --rules_config_search

# Find all SystemVerilog source files (sim/ and tb/ directories)
SV_FILES := $(shell find . -name '*.sv' -not -path './vunit_out/*' -not -path './.github/*' | sort)

# VIP names extracted from tb/run.py paths (e.g., apb_vip)
VIP_NAMES := $(shell find . -name 'run.py' -path '*/tb/run.py' | sort | sed 's|^\./||;s|/tb/run.py||')

# ============================================================
# Targets
# ============================================================

.PHONY: all lint format format-check test clean list help

all: lint format-check test

# -----------------------------------------------------------
# Lint
# -----------------------------------------------------------
lint:
	@echo "=== Verible Lint ($(if $(filter 1,$(DOCKER)),Docker,Local)) ==="
	@errors=0; \
	for f in $(SV_FILES); do \
		echo "  Linting: $$f"; \
		$(VERIBLE_LINT_CMD) $(VERIBLE_RULES) "/work/$$f" || { \
			echo "  ^^^ FAILED: $$f"; \
			errors=$$((errors + 1)); \
		}; \
	done; \
	if [ $$errors -eq 0 ]; then \
		echo "  All files passed lint."; \
	else \
		echo "  $$errors file(s) failed lint."; \
		exit 1; \
	fi

# -----------------------------------------------------------
# Format (in-place)
# -----------------------------------------------------------
format:
	@echo "=== Verible Format ($(if $(filter 1,$(DOCKER)),Docker,Local)) ==="
	@for f in $(SV_FILES); do \
		echo "  Formatting: $$f"; \
		$(VERIBLE_FMT_CMD) --inplace "/work/$$f" || exit 1; \
	done
	@echo "  All files formatted."

# -----------------------------------------------------------
# Format Check
# -----------------------------------------------------------
format-check:
	@echo "=== Verible Format Check ($(if $(filter 1,$(DOCKER)),Docker,Local)) ==="
	@errors=0; \
	for f in $(SV_FILES); do \
		echo "  Checking: $$f"; \
		$(VERIBLE_FMT_CMD) --verify --inplace "/work/$$f" 2>/dev/null || { \
			echo "  ^^^ Needs formatting: $$f"; \
			errors=$$((errors + 1)); \
		}; \
	done; \
	if [ $$errors -eq 0 ]; then \
		echo "  All files are correctly formatted."; \
	else \
		echo "  $$errors file(s) need formatting (run 'make format')."; \
		exit 1; \
	fi

# -----------------------------------------------------------
# Test - Run all VIP regression tests
# -----------------------------------------------------------
test:
	@echo "=== Running All VIP Regression Tests ($(if $(filter 1,$(DOCKER)),Docker,Local)) ==="
ifeq ($(DOCKER),1)
	$(TEST_PREFIX) "cd /work && python3 run_all.py"
else
	python3 run_all.py
endif

# -----------------------------------------------------------
# Per-VIP test targets (e.g., make test-apb_vip)
# -----------------------------------------------------------
# $(1) = vip_name (e.g., apb_vip)
# The run.py is at <vip_name>/tb/run.py
define GEN_VIP_TARGET
test-$(1):
	@echo "=== Running $(1) ($(if $(filter 1,$(DOCKER)),Docker,Local)) ==="
ifeq ($(DOCKER),1)
	$(TEST_PREFIX) "cd /work/$(1)/tb && python3 run.py"
else
	cd $(1)/tb && python3 run.py
endif
endef

$(foreach name,$(VIP_NAMES),$(eval $(call GEN_VIP_TARGET,$(name))))

# -----------------------------------------------------------
# List available targets
# -----------------------------------------------------------
list:
	@echo "Available VIP test targets:"
	@for name in $(VIP_NAMES); do \
		echo "  make test-$$name"; \
	done
	@echo ""
	@echo "Other targets:"
	@echo "  make lint"
	@echo "  make format"
	@echo "  make format-check"
	@echo "  make test"
	@echo "  make clean"
	@echo ""
	@echo "Docker mode: $(if $(filter 1,$(DOCKER)),enabled,disabled)"
	@echo "  make ... DOCKER=0    # Run locally instead of Docker"

# -----------------------------------------------------------
# Clean
# -----------------------------------------------------------
clean:
	@echo "=== Cleaning ==="
	@find . -type d -name 'vunit_out' -exec rm -rf {} + 2>/dev/null
	@find . -name 'transcript' -delete
	@find . -name '*.wlf' -delete
	@find . -name 'vsim.wlf' -delete
	@rm -f modelsim.ini
	@echo "  Done."

# -----------------------------------------------------------
# Help
# -----------------------------------------------------------
help:
	@echo "sv-light-vip Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make lint              Run Verible lint on all .sv files"
	@echo "  make format            Auto-format all .sv files in-place"
	@echo "  make format-check      Check formatting (non-modifying)"
	@echo "  make test              Run all VIP regression tests"
	@echo "  make test-<vip>        Run a single VIP test"
	@echo "  make list              List available VIP test targets"
	@echo "  make clean             Remove simulation artifacts"
	@echo "  make help              Show this help"
	@echo ""
	@echo "Docker mode (default):"
	@echo "  Verible image:  $(VERIBLE_IMAGE)"
	@echo "  ModelSim image: $(MODELSIM_IMAGE)"
	@echo ""
	@echo "Examples:"
	@echo "  make test-apb_vip                        # Run APB test via Docker"
	@echo "  make test-axi4_full_vip                  # Run AXI4-Full test via Docker"
	@echo "  make test DOCKER=0                       # Run all tests locally"
	@echo "  make lint DOCKER=0                       # Run lint locally"
	@echo "  make test MODELSIM_IMAGE=modelsim:2023.1 # Use different ModelSim image"
	@echo "  make format VERIBLE_IMAGE=verible:latest # Use different Verible image"
