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

wp plugin is-installed woocommerce || wp plugin install woocommerce
wp plugin activate woocommerce

wp theme is-installed storefront || wp theme install storefront
wp theme activate silkaura

wp rewrite structure '/%postname%/'
wp rewrite flush
wp option update blogdescription "Luxury silk, delivered" || true
wp option update woocommerce_default_country "$WC_COUNTRY" || true
wp option update woocommerce_currency "$WC_CURRENCY" || true
wp option update woocommerce_onboarding_profile '{"skipped":true}' --format=json || true
wp option update woocommerce_task_list_hidden yes || true
wp option update woocommerce_coming_soon no || true

# Create shop/cart/checkout/my-account pages
wp wc tool run install_pages --user="$WP_ADMIN_USER" >/dev/null 2>&1 || true

# Enable offline payment methods for local testing
wp option update woocommerce_cod_settings '{"enabled":"yes","title":"Cash on delivery"}' --format=json || true
wp option update woocommerce_bacs_settings '{"enabled":"yes","title":"Direct bank transfer"}' --format=json || true

# Sample products (only once)
if [ "$(wp wc product list --user="$WP_ADMIN_USER" --format=count)" = "0" ]; then
  CAT=$(wp wc product_cat create --name="Silk Scarves" --user="$WP_ADMIN_USER" --porcelain)
  wp wc product create --user="$WP_ADMIN_USER" --name="Mulberry Silk Scarf" --type=simple \
    --regular_price=89.00 --sku=SA-SCARF-001 --manage_stock=true --stock_quantity=25 \
    --short_description="100% Grade 6A mulberry silk, hand-rolled edges." \
    --categories="[{\"id\":$CAT}]" --porcelain
  wp wc product create --user="$WP_ADMIN_USER" --name="Silk Pillowcase" --type=simple \
    --regular_price=65.00 --sale_price=55.00 --sku=SA-PILLOW-001 --manage_stock=true --stock_quantity=40 \
    --short_description="22 momme silk, gentle on hair and skin." --porcelain
  wp wc product create --user="$WP_ADMIN_USER" --name="Silk Sleep Mask" --type=simple \
    --regular_price=29.00 --sku=SA-MASK-001 --manage_stock=true --stock_quantity=60 \
    --short_description="Breathable silk eye mask with adjustable strap." --porcelain
fi

wp cache flush
echo ""
echo "Silkaura store ready at $WP_URL  (admin: $WP_URL/wp-admin, user: $WP_ADMIN_USER)"
