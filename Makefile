.PHONY: help test test-mariadb test-all test-unit test-file shell db down rebuild fmt

# `docker compose` when docker is installed, otherwise `podman compose`.
# Override: make test COMPOSE="podman compose"
COMPOSE ?= $(if $(shell command -v docker 2>/dev/null),docker compose,podman compose)

help:
	@grep -E '^[a-zA-Z-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

test: ## Run the full suite against PostgreSQL (the default)
	$(COMPOSE) run --rm tests

test-mariadb: ## Run the same suite against MariaDB
	$(COMPOSE) --profile mariadb run --rm tests-mariadb; rc=$$?; $(COMPOSE) --profile mariadb down; exit $$rc

test-all: test test-mariadb ## Run the suite against every supported engine

test-unit: ## Run DB-free unit tests natively (fastest feedback loop)
	dart test test/unit

test-file: ## Run one file: make test-file FILE=test/integration/query_test.dart
	$(COMPOSE) run --rm tests dart test $(FILE)

shell: ## Shell in the ODBC environment (try: isql -v postgres odbc_test odbc_test)
	$(COMPOSE) run --rm --entrypoint bash tests

db: ## Start only the database, for running `dart test` natively
	$(COMPOSE) up -d db

down: ## Stop everything and remove volumes
	$(COMPOSE) down -v

rebuild: ## Rebuild the runner image from scratch
	$(COMPOSE) build --no-cache tests

fmt: ## Format and analyze
	dart format . && dart analyze
