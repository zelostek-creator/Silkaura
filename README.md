# Silkaura — WordPress + WooCommerce

Local development stack for the Silkaura store, built on Docker.

| Service    | URL                          | Notes                                  |
|------------|------------------------------|----------------------------------------|
| WordPress  | http://localhost:8080        | Admin at `/wp-admin`                   |
| Mailpit    | http://localhost:8025        | Catches all outgoing store emails      |
| phpMyAdmin | http://localhost:8081        | Optional: `make pma`                   |

## Requirements
- Docker with Docker Compose v2
- `make` (or run the commands in the `Makefile` by hand)

## Quick start
```bash
cp .env.example .env      # set admin password etc.
make install
```
`make install` is idempotent. It:
1. Starts MariaDB, WordPress (PHP 8.3) and Mailpit
2. Installs WordPress core
3. Installs and activates **WooCommerce** and the **Storefront** parent theme
4. Activates the **Silkaura** child theme
5. Sets pretty permalinks, store country/currency, skips onboarding
6. Creates Shop / Cart / Checkout / My Account pages
7. Enables Cash on Delivery and Bank Transfer for test orders
8. Seeds 3 sample silk products

## Everyday commands
```bash
make up                         # start
make down                       # stop
make logs                       # tail WordPress logs
make wp ARGS="plugin list"      # any WP-CLI command
make wp ARGS="wc product list --user=admin"
make reset                      # stop and DELETE all data
```

## What's in the repo
```
docker-compose.yml               # db, wordpress, wpcli, phpmyadmin, mailpit
.env.example                     # configuration (copy to .env)
config/uploads.ini               # PHP limits (64M uploads, 512M memory)
scripts/install.sh               # WP-CLI provisioning script
wp-content/themes/silkaura/      # Storefront child theme (your code lives here)
  woocommerce/                   # WooCommerce template overrides
wp-content/mu-plugins/           # Must-use plugins (local mail → Mailpit)
```
WordPress core and third-party plugins live in a Docker volume and are **not**
committed. Only the custom theme and mu-plugins are version-controlled.

## Going to production
- Use strong, unique values for every password in `.env`; set `WP_DEBUG=0`.
- Configure a real payment gateway (e.g. WooCommerce Payments, Stripe, PayPal)
  and disable COD/BACS if not needed.
- Set up real SMTP (the Mailpit mu-plugin only runs when `WP_ENVIRONMENT_TYPE=local`).
- Put the site behind HTTPS and update `WP_URL` / Site Address.
