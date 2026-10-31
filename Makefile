# casebooks-solr — image build & push to ECR
#
#   make push DEPLOY=production
#
# Every image is tagged <branch>, git_<sha> and by_<user>. Any of these can be overridden:
#   make push BRANCH=main SHA=abc1234 WHO=someone REGION=eu-west-2 REGISTRY=... IMAGE=...
#
# Builds use --pull --no-cache by default; FRESH=0 reuses cached layers and local base images.
#
# Per-deployment settings go in <DEPLOY>.env.make (gitignored), e.g.
#   AWS_ACCOUNT_ID=<aws-account-id>
#   IMAGE=<ecr-namespace>/<repository-name>
#   AWS=<command that runs the AWS CLI with your credentials>
# Without DEPLOY, .env.make is read if present. If neither AWS_ACCOUNT_ID nor REGISTRY is set,
# the account is looked up with `aws sts`.
#
# Recipes run in a non-interactive bash, so shell aliases/functions for `aws` are not visible;
# set AWS to a command that works there.
#
# Local dev runs this Solr and ../casebooks-search as separate compose projects:
#   make dev-up ARCH=arm64 API_ENV=other.env API_DIR=../casebooks-search
# ARCH defaults to DOCKER_DEFAULT_PLATFORM. API_ENV is relative to API_DIR.

SHELL := /bin/bash
.DEFAULT_GOAL := help

ifdef DEPLOY
include $(DEPLOY).env.make
else
-include .env.make
endif

REGION ?= eu-west-1
IMAGE  ?= casebooks/solr
FRESH  ?= 1
AWS    ?= aws
ifneq ($(filter login build push,$(MAKECMDGOALS)),)
ifndef REGISTRY
ifndef AWS_ACCOUNT_ID
AWS_ACCOUNT_ID := $(shell $(AWS) sts get-caller-identity --query Account --output text 2>/dev/null)
ifeq ($(AWS_ACCOUNT_ID),)
$(error Could not look up AWS_ACCOUNT_ID with '$(AWS) sts get-caller-identity'; check your AWS credentials or set AWS_ACCOUNT_ID or REGISTRY)
endif
endif
REGISTRY := $(AWS_ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com
endif
endif

API_DIR ?= ../casebooks-search
API_ENV ?= .env
ARCH    ?=
DEV_PLATFORM := $(if $(ARCH),DOCKER_DEFAULT_PLATFORM=linux/$(ARCH))
SOLR_COMPOSE := $(DEV_PLATFORM) docker compose
API_COMPOSE  := $(DEV_PLATFORM) docker compose -f $(API_DIR)/docker-compose.yml --env-file $(API_DIR)/$(API_ENV)

BRANCH := $(shell git branch --show-current 2>/dev/null | tr '/' '-')
SHA    := $(shell git rev-parse --short HEAD)
WHO    := $(shell whoami)
TAGS   := $(BRANCH) git_$(SHA) by_$(WHO)

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

.PHONY: login
login: ## Docker login to ECR
	$(AWS) ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(REGISTRY)

.PHONY: build
build: ## Build with branch, git sha and user tags
	docker build $(if $(filter 1,$(FRESH)),--pull --no-cache) --platform linux/amd64 $(foreach t,$(TAGS),-t $(REGISTRY)/$(IMAGE):$(t)) ./docker

.PHONY: push
push: login build ## Log in, build and push all tags
	@set -e; for t in $(TAGS); do docker push $(REGISTRY)/$(IMAGE):$$t; done

.PHONY: dev-up
dev-up: ## Build and start local Solr and API (detached)
	$(SOLR_COMPOSE) up -d --build --force-recreate
	$(API_COMPOSE) up -d --build --force-recreate

.PHONY: dev-down
dev-down: ## Stop local Solr and API
	$(API_COMPOSE) down
	$(SOLR_COMPOSE) down
