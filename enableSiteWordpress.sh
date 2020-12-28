#!/bin/sh
# Exit in case of failure
set -e

FQDN=$1
WWW_PATH=/var/www/html
ACME_SH_PATH=/root/.acme.sh

echo Creating directory
mkdir -p $WWW_PATH/$FQDN

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

