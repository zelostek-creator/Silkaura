<?php
/**
 * Silkaura theme functions.
 *
 * @package Silkaura
 */

defined( 'ABSPATH' ) || exit;

add_action( 'wp_enqueue_scripts', function () {
	$parent = wp_get_theme( 'storefront' );
	wp_enqueue_style( 'storefront-style', get_template_directory_uri() . '/style.css', array(), $parent->get( 'Version' ) );
	wp_enqueue_style( 'silkaura-fonts', 'https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@500;600&display=swap', array(), null );
	wp_enqueue_style( 'silkaura-style', get_stylesheet_uri(), array( 'storefront-style' ), wp_get_theme()->get( 'Version' ) );
}, 20 );

add_action( 'after_setup_theme', function () {
	load_child_theme_textdomain( 'silkaura', get_stylesheet_directory() . '/languages' );
} );

// 4 products per row, 12 per page on shop archives.
add_filter( 'loop_shop_columns', fn() => 4 );
add_filter( 'loop_shop_per_page', fn() => 12 );

// Footer credit.
add_filter( 'storefront_credit_link', '__return_false' );
add_filter( 'storefront_copyright_text', fn() => '&copy; ' . gmdate( 'Y' ) . ' Silkaura' );
