.PHONY: help test test-mariadb test-all test-unit test-file shell db down rebuild fmt

help:
	@grep -E '^[a-zA-Z-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

test: ## Run the full suite against PostgreSQL (the default)
	docker compose run --rm tests

test-mariadb: ## Run the same suite against MariaDB
	docker compose --profile mariadb run --rm tests-mariadb

test-all: test test-mariadb ## Run the suite against every supported engine

test-unit: ## Run DB-free unit tests natively (fastest feedback loop)
	dart test test/unit

test-file: ## Run one file: make test-file FILE=test/integration/query_test.dart
	docker compose run --rm tests dart test $(FILE)

shell: ## Shell in the ODBC environment (try: isql -v postgres odbc_test odbc_test)
	docker compose run --rm --entrypoint bash tests

db: ## Start only the database, for running `dart test` natively
	docker compose up -d db

down: ## Stop everything and remove volumes
	docker compose down -v

rebuild: ## Rebuild the runner image from scratch
	docker compose build --no-cache tests

fmt: ## Format and analyze
	dart format . && dart analyze
