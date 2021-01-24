#!/bin/sh
# Exit in case of failure
set -e

FQDN=$1
NON_FQDN=`echo $1 | cut -f 1 -d .`
WWW_PATH=/var/www/html
ACME_SH_PATH=/root/.acme.sh

#Creating the directory first will move Wordpress with wrong path
#echo "Creating directory"
#mkdir -p $WWW_PATH/$FQDN

# Setup Database
PASSWORD=`cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-' | head -c 16`
echo "Generated database password: $PASSWORD"

MYSQL_PASSWORD="$2"

echo "Creating MariaDB/MySQL databases"
mysql -u root -p$MYSQL_PASSWORD -e "create database wrdprs_$NON_FQDN"
mysql -u root -p$MYSQL_PASSWORD -e "GRANT ALL PRIVILEGES ON wrdprs_$NON_FQDN.* TO \"usr_$NON_FQDN\"@\"localhost\" IDENTIFIED BY \"$PASSWORD\""
mysql -u root -p$MYSQL_PASSWORD -e "FLUSH PRIVILEGES"

# Install Wordpress on $WWW_PATH
SITE_URL=$1
echo "Site URL: $SITE_URL"
curl -O https://wordpress.org/latest.tar.gz
tar zxvf latest.tar.gz
mv wordpress $WWW_PATH/$SITE_URL
rm -f $WWW_PATH/$SITE_URL/wp-config.php

# Create wp-config.php
TABLE_PREFIX=`cat /dev/urandom | tr -dc '0-9a-zA-Z' | head -c 6`
echo "Generated table prefix: $TABLE_PREFIX"
cat > $WWW_PATH/$SITE_URL/wp-config.php << EOF
<?php
/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the
 * installation. You don't have to use the web site, you can
 * copy this file to "wp-config.php" and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * MySQL settings
 * * Secret keys
 * * Database table prefix
 * * ABSPATH
 *
 * @link https://codex.wordpress.org/Editing_wp-config.php
 *
 * @package WordPress
 */

// ** MySQL settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define('DB_NAME', 'wrdprs_$NON_FQDN');

/** MySQL database username */
define('DB_USER', 'usr_$NON_FQDN');

/** MySQL database password */
define('DB_PASSWORD', '$PASSWORD');

/** MySQL hostname */
define('DB_HOST', 'localhost');

/** Database Charset to use in creating database tables. */
define('DB_CHARSET', 'utf8mb4');

/** The Database Collate type. Don't change this if in doubt. */
define('DB_COLLATE', '');

/**#@+
 * Authentication Unique Keys and Salts.
 *
 * Change these to different unique phrases!
 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
EOF

curl https://api.wordpress.org/secret-key/1.1/salt/ >> $WWW_PATH/$SITE_URL/wp-config.php

cat >> $WWW_PATH/$SITE_URL/wp-config.php << EOF

/**#@-*/

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
\$table_prefix  = '${TABLE_PREFIX}_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the Codex.
 *
 * @link https://codex.wordpress.org/Debugging_in_WordPress
 */
define('WP_DEBUG', false);

/** Enable proper support for updates without FTP/FTPS. */
define('FS_METHOD','direct');

/* That's all, stop editing! Happy blogging. */

/** Absolute path to the WordPress directory. */
if ( !defined('ABSPATH') )
        define('ABSPATH', dirname(__FILE__) . '/');

/** Sets up WordPress vars and included files. */
require_once(ABSPATH . 'wp-settings.php');
EOF

# Setup SELinux
echo Setting up SELinux labels
semanage fcontext -a -t httpd_sys_content_t "$WWW_PATH/$SITE_URL(/.*)?"

# Fix wp-content
semanage fcontext -a -t httpd_sys_rw_content_t "$WWW_PATH/$SITE_URL/wp-content(/.*)?"

# Fix wp-config
semanage fcontext -a -t httpd_sys_rw_content_t "$WWW_PATH/$SITE_URL/wp-config.php"

# Restorecon
restorecon -R $WWW_PATH/$SITE_URL

echo Generating SSL certificates using the default website
$ACME_SH_PATH/acme.sh --issue --stateless -k ec-384 -d $FQDN -d www.$FQDN

echo Installing certificates
$ACME_SH_PATH/acme.sh --install-cert -d $FQDN --ecc --key-file /etc/pki/tls/private/$FQDN.key --fullchain-file /etc/pki/tls/certs/$FQDN.cer --reloadcmd "systemctl reload nginx"

echo Generating nginx configuration
cat > /etc/nginx/sites.d/$FQDN.conf << EOF
server {
	listen 80;
	server_name $FQDN
		    www.$FQDN;

        # Let's encrypt
        # Stateless support is only needed here since curl reads over http
        include conf.d/letsencrypt.conf;

	location / {
		return 301 https://$FQDN$request_uri;
	}
}

server {
	listen 443 ssl http2;
	server_name www.$FQDN;

	ssl_certificate		/etc/pki/tls/certs/$FQDN.cer;
	ssl_certificate_key	/etc/pki/tls/private/$FQDN.key;

	location / {
		return 301 https://$FQDN$request_uri;
	}
}

server {
	listen 443 ssl http2;
	server_name $FQDN;

	# Root path of the site
	root $WWW_PATH/$FQDN;

	# Enable PHP serving in index.php
	index index.php;

	access_log /var/log/nginx/$FQDN.access.log;

	ssl_certificate		/etc/pki/tls/certs/$FQDN.cer;
	ssl_certificate_key	/etc/pki/tls/private/$FQDN.key;

	ssl_stapling on;
	ssl_trusted_certificate	/etc/pki/tls/certs/lets-encrypt-ca.cer;
	resolver 146.164.29.4 146.164.29.3;

	# Include security SSL features
	include conf.d/sslsec.conf;

	# Include custom error pages
	include conf.d/errors.conf;

        # Global restrictions
        include conf.d/restrictions.conf;

        # Enable Wordpress
        include conf.d/wordpress.conf;
}
EOF

echo Reloading nginx
systemctl restart nginx

echo Done

