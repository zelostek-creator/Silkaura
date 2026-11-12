#!/bin/sh
# Runs inside the wpcli container. Idempotent: safe to re-run.
set -eu
cd /var/www/html

echo "Waiting for WordPress files..."
i=0; until [ -f wp-config.php ]; do i=$((i+1)); [ $i -gt 60 ] && { echo "wp-config.php not found"; exit 1; }; sleep 2; done

if ! wp core is-installed 2>/dev/null; then
  wp core install \
    --url="$WP_URL" --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" \
    --admin_email="$WP_ADMIN_EMAIL" --skip-email
fi

wp eval-file /scripts/provision.php
