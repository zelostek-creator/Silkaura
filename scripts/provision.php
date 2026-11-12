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

/**
 * Run a WP-CLI command in a fresh PHP process, streaming its output to the console.
 *
 * Not WP_CLI::runcommand(): with output captured it reads stdout to the end before
 * stderr, so a child that writes a lot of warnings (e.g. PHP 8.5 deprecations from
 * WP-CLI's own libraries) fills the stderr pipe and both processes hang, which is
 * easy to hit on Windows. Arguments go as an array, so no shell quoting is involved.
 */
$run = function ( array $args, bool $fatal = true ) {
	WP_CLI::log( '> wp ' . implode( ' ', $args ) );
	$cmd = array_merge(
		array( PHP_BINARY, '-d', 'memory_limit=512M', '-d', 'error_reporting=' . ( E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED ) ),
		array( realpath( $GLOBALS['argv'][0] ) ?: $GLOBALS['argv'][0], '--path=' . ABSPATH ),
		( function_exists( 'posix_geteuid' ) && 0 === posix_geteuid() ) ? array( '--allow-root' ) : array(),
		$args
	);
	$proc = proc_open( $cmd, array( 0 => STDIN, 1 => STDOUT, 2 => STDERR ), $pipes );
	$code = is_resource( $proc ) ? proc_close( $proc ) : 1;
	if ( 0 !== $code ) {
		$msg = 'wp ' . implode( ' ', $args ) . " failed (exit $code). See the messages above.";
		$fatal ? WP_CLI::error( $msg ) : WP_CLI::warning( $msg );
	}
};

// WooCommerce and Storefront. --force repairs a copy left half-installed by an interrupted run.
$wc_dir = WP_PLUGIN_DIR . '/woocommerce';
if ( ! file_exists( "$wc_dir/woocommerce.php" ) ) {
	$run( array_merge( array( 'plugin', 'install', getenv( 'WOOCOMMERCE_ZIP' ) ?: 'woocommerce' ), is_dir( $wc_dir ) ? array( '--force' ) : array() ) );
}
$sf_dir = get_theme_root() . '/storefront';
if ( ! file_exists( "$sf_dir/style.css" ) ) {
	$run( array_merge( array( 'theme', 'install', getenv( 'STOREFRONT_ZIP' ) ?: 'storefront' ), is_dir( $sf_dir ) ? array( '--force' ) : array() ) );
}
$run( array( 'plugin', 'activate', 'woocommerce' ) );
$run( array( 'theme', 'activate', 'silkaura' ) );

// Store setup needs WooCommerce loaded, so it runs in a fresh process.
$run( array( 'eval-file', __DIR__ . '/setup-store.php' ) );
