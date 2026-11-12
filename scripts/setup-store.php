<?php
/**
 * Configures WooCommerce and seeds sample products.
 * Called by provision.php in a process where WooCommerce is active.
 */

if ( ! class_exists( 'WooCommerce' ) ) {
	WP_CLI::error( 'WooCommerce is not active.' );
}

$options = array(
	'blogdescription'                => 'Luxury silk, delivered',
	'woocommerce_default_country'    => getenv( 'WC_COUNTRY' ) ?: 'US:CA',
	'woocommerce_currency'           => getenv( 'WC_CURRENCY' ) ?: 'USD',
	'woocommerce_task_list_hidden'   => 'yes',
	'woocommerce_coming_soon'        => 'no',
	'woocommerce_onboarding_profile' => array( 'skipped' => true ),
	'woocommerce_cod_settings'       => array( 'enabled' => 'yes', 'title' => 'Cash on delivery' ),
	'woocommerce_bacs_settings'      => array( 'enabled' => 'yes', 'title' => 'Direct bank transfer' ),
);
foreach ( $options as $key => $value ) {
	update_option( $key, $value );
}
WP_CLI::log( 'Store settings saved.' );

// Shop / Cart / Checkout / My Account pages (skips ones that already exist).
WC_Install::create_pages();
WP_CLI::log( 'Store pages ready.' );

// Sample products, only on an empty store.
$existing = wc_get_products( array( 'limit' => 1, 'return' => 'ids', 'status' => 'any' ) );
if ( empty( $existing ) ) {
	$term   = term_exists( 'Silk Scarves', 'product_cat' ) ?: wp_insert_term( 'Silk Scarves', 'product_cat' );
	$cat_id = (int) $term['term_id'];

	$products = array(
		array( 'Mulberry Silk Scarf', '89.00', '', 'SA-SCARF-001', 25, '100% Grade 6A mulberry silk, hand-rolled edges.', array( $cat_id ) ),
		array( 'Silk Pillowcase', '65.00', '55.00', 'SA-PILLOW-001', 40, '22 momme silk, gentle on hair and skin.', array() ),
		array( 'Silk Sleep Mask', '29.00', '', 'SA-MASK-001', 60, 'Breathable silk eye mask with adjustable strap.', array() ),
	);
	foreach ( $products as [ $name, $price, $sale, $sku, $qty, $desc, $cats ] ) {
		$p = new WC_Product_Simple();
		$p->set_name( $name );
		$p->set_regular_price( $price );
		if ( $sale ) {
			$p->set_sale_price( $sale );
		}
		$p->set_sku( $sku );
		$p->set_manage_stock( true );
		$p->set_stock_quantity( $qty );
		$p->set_short_description( $desc );
		if ( $cats ) {
			$p->set_category_ids( $cats );
		}
		$p->set_status( 'publish' );
		WP_CLI::log( "Created product #{$p->save()}: $name" );
	}
}

global $wp_rewrite;
$wp_rewrite->set_permalink_structure( '/%postname%/' );
flush_rewrite_rules( false );
wp_cache_flush();
WP_CLI::success( 'Silkaura store ready at ' . home_url( '/' ) . ' (admin: ' . admin_url() . ')' );
