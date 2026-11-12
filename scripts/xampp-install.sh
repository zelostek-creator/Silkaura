#!/usr/bin/env bash
# Install the Silkaura WooCommerce store into XAMPP (macOS or Linux).
#
#   bash scripts/xampp-install.sh
#
# Start Apache and MySQL in the XAMPP control panel first.
# Override defaults with env vars, e.g.:
#   SITE=shop ADMIN_PASSWORD=secret bash scripts/xampp-install.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "${XAMPP_DIR:-}" ]; then
  for d in /Applications/XAMPP/xamppfiles /opt/lampp; do [ -d "$d" ] && XAMPP_DIR="$d" && break; done
fi
[ -n "${XAMPP_DIR:-}" ] && [ -d "$XAMPP_DIR" ] || { echo "XAMPP not found. Set XAMPP_DIR=/path/to/xampp"; exit 1; }

SITE="${SITE:-silkaura}"
DB_NAME="${DB_NAME:-silkaura}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_HOST="${DB_HOST:-127.0.0.1}"
PORT="${PORT:-80}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
export WC_COUNTRY="${WC_COUNTRY:-US:CA}" WC_CURRENCY="${WC_CURRENCY:-USD}"

HOST="localhost"; [ "$PORT" != "80" ] && HOST="localhost:$PORT"
URL="http://$HOST/$SITE"
PHP="$XAMPP_DIR/bin/php"
MYSQL="$XAMPP_DIR/bin/mysql"
DOCROOT="$XAMPP_DIR/htdocs/$SITE"
TOOLS="$REPO/.tools"
WPCLI="$TOOLS/wp-cli.phar"

step() { printf '\n==> %s\n' "$*"; }
ROOT_FLAG=(); [ "$(id -u)" = "0" ] && ROOT_FLAG=(--allow-root)  # XAMPP on Linux is often run with sudo
wp() { "$PHP" -d memory_limit=512M "$WPCLI" --path="$DOCROOT" "${ROOT_FLAG[@]}" "$@"; }

step "Checking XAMPP at $XAMPP_DIR"
[ -x "$PHP" ] || { echo "PHP not found at $PHP"; exit 1; }
"$PHP" -n -r 'exit(PHP_VERSION_ID >= 70400 ? 0 : 1);' || { echo "PHP 7.4+ is required, but $PHP is PHP $("$PHP" -n -r 'echo PHP_VERSION;'). Install a newer XAMPP (PHP 8.x)."; exit 1; }
MYSQL_ARGS=(-h "$DB_HOST" -u "$DB_USER"); [ -n "$DB_PASSWORD" ] && MYSQL_ARGS+=(-p"$DB_PASSWORD")
"$MYSQL" "${MYSQL_ARGS[@]}" -e 'SELECT 1' >/dev/null 2>&1 || { echo "Can't connect to MySQL. Start MySQL in the XAMPP control panel."; exit 1; }
echo "PHP $("$PHP" -r 'echo PHP_VERSION;'), MySQL OK"

step "Getting WP-CLI"
mkdir -p "$TOOLS"
[ -f "$WPCLI" ] || curl -fsSL -o "$WPCLI" https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
wp --version

step "Downloading WordPress into $DOCROOT"
if [ ! -f "$DOCROOT/wp-load.php" ]; then
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/wp.zip" https://downloads.wordpress.org/release/wordpress-latest.zip
  unzip -q "$tmp/wp.zip" -d "$tmp"
  mkdir -p "$DOCROOT" && cp -R "$tmp/wordpress/." "$DOCROOT/"
  rm -rf "$tmp"
else
  echo "Already present"
fi

step "Creating database '$DB_NAME'"
"$MYSQL" "${MYSQL_ARGS[@]}" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"

step "Configuring WordPress"
if [ ! -f "$DOCROOT/wp-config.php" ]; then
  wp config create --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASSWORD" --dbhost="$DB_HOST" --skip-check
  wp config set WP_ENVIRONMENT_TYPE local
  wp config set WP_DEBUG true --raw
  wp config set WP_DEBUG_LOG true --raw
  wp config set WP_DEBUG_DISPLAY false --raw
  wp config set FS_METHOD direct
fi
cat > "$DOCROOT/.htaccess" <<HT
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /$SITE/
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /$SITE/index.php [L]
</IfModule>
# END WordPress
HT

step "Installing WordPress"
wp core is-installed 2>/dev/null || wp core install --url="$URL" --title="Silkaura" \
  --admin_user="$ADMIN_USER" --admin_password="$ADMIN_PASSWORD" --admin_email="$ADMIN_EMAIL" --skip-email

step "Linking Silkaura theme and mu-plugins from the repo"
link() { # link <repo path> <wp path>
  if [ "$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")" = "$(cd "$(dirname "$2")" && pwd -P)/$(basename "$2")" ]; then
    # The repo is the site folder (cloned into htdocs), so the files are already in place.
    if [ ! -e "$2" ]; then
      # An earlier version of this script renamed the folder away; put it back.
      bak="$(ls -d "$2".bak.* 2>/dev/null | sort | tail -1)"
      [ -n "$bak" ] || { echo "$2 is missing from the repo. Download the repo again."; exit 1; }
      mv "$bak" "$2" && echo "Restored $2 from $(basename "$bak")"
    else
      echo "$2 already in place"
    fi
    return
  fi
  if [ -L "$2" ]; then rm "$2"; elif [ -e "$2" ]; then mv "$2" "$2.bak.$(date +%s)"; fi
  ln -s "$1" "$2" && echo "$2 -> $1"
}
link "$REPO/wp-content/themes/silkaura" "$DOCROOT/wp-content/themes/silkaura"
link "$REPO/wp-content/mu-plugins" "$DOCROOT/wp-content/mu-plugins"

step "Installing WooCommerce + Storefront and setting up the store"
wp eval-file "$REPO/scripts/provision.php"

# Apache in XAMPP runs as a different user; let it write uploads, plugins and updates.
chmod -R a+rwX "$DOCROOT/wp-content" 2>/dev/null || true

cat <<DONE

Silkaura is running in XAMPP
  Store:  $URL
  Admin:  $URL/wp-admin   (user: $ADMIN_USER, password: $ADMIN_PASSWORD)
DONE
