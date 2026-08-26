SHELL := /bin/bash

PACKAGE ?= gitops-stack
XRD_DIR := apis/gitopsstacks
COMPOSITION := $(XRD_DIR)/composition.yaml
DEFINITION := $(XRD_DIR)/definition.yaml
CONFIGURATION := $(XRD_DIR)/configuration.yaml
EXAMPLE_DEFAULT := examples/gitopsstacks/standard.yaml
RENDER_TESTS := $(wildcard tests/test-*)
E2E_TESTS := $(wildcard tests/e2etest-*)

clean:
	rm -rf _output
	rm -rf .up
	rm -f $(CONFIGURATION)

build:
	up project build

generate-configuration:
	@set -euo pipefail; \
	hops validate generate-configuration --path . --api-path "$(XRD_DIR)"

# Examples list - mirrors GitHub Actions workflow
# Format: example_path::observed_resources_path (observed_resources_path is optional)
EXAMPLES := \
    examples/gitopsstacks/minimal.yaml:: \
    examples/gitopsstacks/standard.yaml:: \
    examples/gitopsstacks/nodepool.yaml:: \
    examples/gitopsstacks/standard.yaml::examples/test/mocks/observed-resources/standard/steps/1/ \
    examples/gitopsstacks/standard.yaml::examples/test/mocks/observed-resources/standard/steps/2/ \
    examples/gitopsstacks/eso.yaml:: \
    examples/gitopsstacks/eso.yaml::examples/test/mocks/observed-resources/eso/steps/1/ \
    examples/gitopsstacks/eso.yaml::examples/test/mocks/observed-resources/eso/steps/2/ \
    examples/gitopsstacks/eso.yaml::examples/test/mocks/observed-resources/eso/steps/3/ \
    examples/gitopsstacks/zitadel-oidc.yaml:: \
    examples/gitopsstacks/zitadel-oidc.yaml::examples/test/mocks/observed-resources/zitadel-oidc/steps/1/

# Render all examples (parallel execution, output shown per-job when complete)
render\:all:
	@tmpdir=$$(mktemp -d); \
	pids=""; \
	for entry in $(EXAMPLES); do \
		example=$${entry%%::*}; \
		observed=$${entry#*::}; \
		outfile="$$tmpdir/$$(echo $$entry | tr '/:' '__')"; \
		( \
			if [ -n "$$observed" ]; then \
				echo "=== Rendering $$example with observed-resources $$observed ==="; \
				up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example --observed-resources=$$observed; \
			else \
				echo "=== Rendering $$example ==="; \
				up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example; \
			fi; \
			echo "" \
		) > "$$outfile" 2>&1 & \
		pids="$$pids $$!:$$outfile"; \
	done; \
	failed=0; \
	for pair in $$pids; do \
		pid=$${pair%%:*}; \
		outfile=$${pair#*:}; \
		if ! wait $$pid; then failed=1; fi; \
		cat "$$outfile"; \
	done; \
	rm -rf "$$tmpdir"; \
	exit $$failed

# Validate all examples (parallel execution, output shown per-job when complete)
validate\:all: generate-configuration
	@tmpdir=$$(mktemp -d); \
	pids=""; \
	for entry in $(EXAMPLES); do \
		example=$${entry%%::*}; \
		observed=$${entry#*::}; \
		outfile="$$tmpdir/$$(echo $$entry | tr '/:' '__')"; \
		( \
			if [ -n "$$observed" ]; then \
				echo "=== Validating $$example with observed-resources $$observed ==="; \
				up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example \
					--observed-resources=$$observed --include-full-xr --quiet | \
					crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -; \
			else \
				echo "=== Validating $$example ==="; \
				up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example \
					--include-full-xr --quiet | \
					crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -; \
			fi; \
			echo "" \
		) > "$$outfile" 2>&1 & \
		pids="$$pids $$!:$$outfile"; \
	done; \
	failed=0; \
	for pair in $$pids; do \
		pid=$${pair%%:*}; \
		outfile=$${pair#*:}; \
		if ! wait $$pid; then failed=1; fi; \
		cat "$$outfile"; \
	done; \
	rm -rf "$$tmpdir"; \
	exit $$failed

# Shorthand aliases
.PHONY: render validate generate-configuration
render: ; @$(MAKE) 'render:all'
validate: ; @$(MAKE) generate-configuration 'validate:all'

# Single example targets
render\:%:
	@example="examples/gitopsstacks/$*.yaml"; \
	up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example

validate\:%: generate-configuration
	@example="examples/gitopsstacks/$*.yaml"; \
	up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example \
		--include-full-xr --quiet | \
		crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -

test:
	up test run $(RENDER_TESTS)

e2e:
	up test run $(E2E_TESTS) --e2e

publish:
	@if [ -z "$(tag)" ]; then echo "Error: tag is not set. Usage: make publish tag=<version>"; exit 1; fi
	up project build --push --tag $(tag)
