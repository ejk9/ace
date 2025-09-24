.PHONY: help setup start stop restart logs clean deps compile test format lint check db-start db-setup db-migrate db-rollback db-reset db-seed assets

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Docker & Infrastructure
setup: ## Initial project setup - start all services, install deps, setup database
	docker compose up -d
	@echo "Waiting for PostgreSQL to be ready..."
	@until docker compose exec -T postgres pg_isready -U postgres; do sleep 1; done
	mix deps.get
	mix ecto.create
	mix ecto.migrate
	mix assets.setup
	@echo "Setup complete! Run 'make start' to start the server."

db-start: ## Start the database container
	docker compose up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@until docker compose exec -T postgres pg_isready -U postgres; do sleep 1; done

start: ## Start all services (database, screenshot service) and Phoenix server
	docker compose up -d
	@echo "Waiting for services to be ready..."
	@until docker compose exec -T postgres pg_isready -U postgres; do sleep 1; done
	@echo "Services ready! Starting Phoenix server..."
	mix phx.server

start-iex: ## Start all services and Phoenix server in IEx (with database, screenshot service)
	docker compose up -d
	@echo "Waiting for services to be ready..."
	@until docker compose exec -T postgres pg_isready -U postgres; do sleep 1; done
	@echo "Services ready! Starting Phoenix server in IEx..."
	iex -S mix phx.server

stop: ## Stop all services
	docker compose down

restart: clean-processes ## Restart all services (with process cleanup)
	docker compose restart
	@echo "Waiting for database to be ready..."
	@sleep 2
	mix phx.server

logs: ## Show database logs
	docker compose logs -f postgres

clean: ## Clean build artifacts and stop services
	mix clean
	docker compose down -v
	docker system prune -f

clean-processes: ## Kill all Elixir/Phoenix processes to prevent port conflicts
	@echo "Killing Phoenix server processes..."
	-pkill -f "mix phx.server" 2>/dev/null || true
	-pkill -f "phx.server" 2>/dev/null || true
	@echo "Killing Erlang/Elixir processes..."
	-pkill -f "beam.smp" 2>/dev/null || true
	-pkill -f "erl_child_setup" 2>/dev/null || true
	-pkill -f "inet_gethost" 2>/dev/null || true
	@echo "Checking for processes on port 4000..."
	-lsof -ti:4000 | xargs kill -9 2>/dev/null || true
	@echo "Process cleanup complete!"

clean-all: clean-processes clean ## Complete cleanup - processes, build artifacts, and services

# Dependencies
deps: ## Install/update dependencies
	mix deps.get
	mix deps.compile

compile: ## Compile the project
	mix compile

# Testing & Quality
test: ## Run tests
	MIX_ENV=test mix test

test-watch: ## Run tests in watch mode
	MIX_ENV=test mix test.watch

format: ## Format code
	mix format

lint: ## Run linter
	mix credo --strict

check: format lint test ## Run all checks (format, lint, test)

# Database
db-setup: ## Setup database (create + migrate)
	mix ecto.create
	mix ecto.migrate

db-migrate: ## Run pending migrations
	mix ecto.migrate

db-rollback: ## Rollback last migration
	mix ecto.rollback

db-reset: ## Reset database (drop, create, migrate, seed)
	mix ecto.reset

db-seed: ## Run database seeds
	mix run priv/repo/seeds.exs

seed-dev: ## Reset database and seed with comprehensive test data (perfect for development)
	@echo "🔄 Resetting database and seeding with test data..."
	mix ecto.reset
	@echo ""
	@echo "🎉 Development environment ready with sample drafts!"
	@echo "Check the output above for test URLs and draft information."

# Assets
assets: ## Build assets
	mix assets.build

assets-watch: ## Watch and build assets
	mix assets.setup
	mix assets.deploy

# Development helpers
dev-setup: setup ## Alias for setup
	@echo "Development environment ready!"

shell: ## Open database shell
	docker compose exec postgres psql -U postgres -d ace_app_dev

# Production helpers
release: ## Build release
	MIX_ENV=prod mix release

# Git hooks (optional)
install-hooks: ## Install git pre-commit hooks
	@echo "Installing git hooks..."
	@echo '#!/bin/sh\nmake check' > .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Git hooks installed!"