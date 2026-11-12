<?php
/**
 * Silkaura store provisioning (works with Docker, XAMPP, or any WP install).
 *
 *   wp eval-file scripts/provision.php
 *
 * Run after WordPress core is installed. Idempotent: safe to re-run.
 * Optional env: WC_COUNTRY (default US:CA), WC_CURRENCY (default USD),
 * WOOCOMMERCE_ZIP / STOREFRONT_ZIP: install from a local .zip instead of WordPress.org.
 */

$run = function ( string $cmd, bool $fatal = true ) {
	WP_CLI::log( "> wp $cmd" );
	$r = WP_CLI::runcommand( $cmd, array( 'return' => 'all', 'exit_error' => false, 'launch' => true ) );
	if ( '' !== trim( $r->stdout ) ) {
		WP_CLI::log( trim( $r->stdout ) );
	}
	if ( 0 !== $r->return_code ) {
		$fatal ? WP_CLI::error( trim( $r->stderr ) ) : WP_CLI::warning( trim( $r->stderr ) );
	}
};

if ( ! is_dir( WP_PLUGIN_DIR . '/woocommerce' ) ) {
	$run( 'plugin install ' . ( getenv( 'WOOCOMMERCE_ZIP' ) ? escapeshellarg( getenv( 'WOOCOMMERCE_ZIP' ) ) : 'woocommerce' ) );
}
if ( ! wp_get_theme( 'storefront' )->exists() ) {
	$run( 'theme install ' . ( getenv( 'STOREFRONT_ZIP' ) ? escapeshellarg( getenv( 'STOREFRONT_ZIP' ) ) : 'storefront' ) );
}
$run( 'plugin activate woocommerce' );
$run( 'theme activate silkaura' );

// Store setup needs WooCommerce loaded, so it runs in a fresh process.
$run( 'eval-file ' . escapeshellarg( __DIR__ . '/setup-store.php' ) );
