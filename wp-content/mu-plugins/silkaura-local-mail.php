<?php
/**
 * Plugin Name: Silkaura Local Mail
 * Description: Routes wp_mail() to Mailpit when SMTP_HOST is defined (local dev only).
 */

defined( 'ABSPATH' ) || exit;

add_action( 'phpmailer_init', function ( $phpmailer ) {
	if ( ! defined( 'SMTP_HOST' ) || 'local' !== wp_get_environment_type() ) {
		return;
	}
	$phpmailer->isSMTP();
	$phpmailer->Host     = SMTP_HOST;
	$phpmailer->Port     = defined( 'SMTP_PORT' ) ? SMTP_PORT : 1025;
	$phpmailer->SMTPAuth = false;
} );
