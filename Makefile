# Wrappers around the same commands CI runs, so a local check and a pipeline
# check cannot drift apart.
.DEFAULT_GOAL := help
SHELL := /bin/bash

MODULES := modules/network modules/security modules/storage modules/compute
DIRS    := $(MODULES) bootstrap envs/dev envs/localstack
ENV     ?= dev

.PHONY: help fmt fmt-check validate lint security test localstack-up localstack-test localstack-down docs clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

fmt: ## Format every configuration
	terraform fmt -recursive

fmt-check: ## Fail if anything is unformatted
	terraform fmt -recursive -check -diff

validate: ## Initialise and validate every directory
	@for d in $(DIRS); do \
		echo "==> $$d"; \
		terraform -chdir=$$d init -backend=false -input=false > /dev/null || exit 1; \
		terraform -chdir=$$d validate || exit 1; \
	done

lint: ## Run tflint across the repository
	tflint --init && tflint --recursive --format compact

security: ## Run the policy scanner
	checkov --directory . --config-file .checkov.yml

test: ## Run terraform test for every module that has tests
	@for m in modules/network modules/security modules/storage; do \
		echo "==> $$m"; \
		terraform -chdir=$$m init -input=false > /dev/null || exit 1; \
		terraform -chdir=$$m test || exit 1; \
	done

localstack-up: ## Start LocalStack in the background
	docker run -d --name localstack -p 4566:4566 \
		-e SERVICES=ec2,s3,iam,sts localstack/localstack:3.8

localstack-test: ## Apply the stack against LocalStack and tear it down
	terraform -chdir=envs/localstack init -input=false
	terraform -chdir=envs/localstack apply -auto-approve
	terraform -chdir=envs/localstack destroy -auto-approve

localstack-down: ## Stop LocalStack
	docker rm -f localstack

docs: ## Regenerate the per-module documentation tables
	@for m in $(MODULES); do terraform-docs markdown table --output-file README.md $$m; done

clean: ## Remove local Terraform working directories
	find . -type d -name .terraform -prune -exec rm -rf {} +
	find . -type f -name tfplan -delete
