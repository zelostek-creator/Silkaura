.PHONY: up install down reset logs wp shell

up:            ## Start WordPress, DB and Mailpit
	@test -f .env || cp .env.example .env
	docker compose up -d

install: up    ## Install WordPress + WooCommerce + Silkaura theme (idempotent)
	docker compose run --rm --entrypoint sh wpcli /scripts/install.sh

down:          ## Stop containers
	docker compose down

reset:         ## Stop and DELETE database + WordPress volumes
	docker compose down -v

logs:
	docker compose logs -f wordpress

wp:            ## Run WP-CLI: make wp ARGS="plugin list"
	docker compose run --rm wpcli $(ARGS)

pma:           ## Start phpMyAdmin on :8081
	docker compose --profile tools up -d phpmyadmin
