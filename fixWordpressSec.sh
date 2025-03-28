#!/bin/sh
#
# This script configures WordPress file permissions based on recommendations
# from http://codex.wordpress.org/Hardening_WordPress#File_permissions
#
# Author: Michael Conigliaro <mike [at] conigliaro [dot] org>
#
if [ -z "$1" ]; then
    echo "Usage: $0 <wordpress_root_directory>" >&2
    exit 1
fi

WP_OWNER=nginx # <-- wordpress owner
WP_GROUP=nginx # <-- wordpress group
WP_ROOT=$1 # <-- wordpress root directory
WS_GROUP=nginx # <-- webserver group

# reset to safe defaults
find ${WP_ROOT} -exec chown ${WP_OWNER}:${WP_GROUP} {} \;
find ${WP_ROOT} -type d -exec chmod 755 {} \;
find ${WP_ROOT} -type f -exec chmod 644 {} \;
# allow wordpress to manage wp-config.php (but prevent world access)
chgrp ${WS_GROUP} ${WP_ROOT}/wp-config.php
chmod 660 ${WP_ROOT}/wp-config.php
# allow wordpress to manage wp-content
find ${WP_ROOT}/wp-content -exec chgrp ${WS_GROUP} {} \;
find ${WP_ROOT}/wp-content -type d -exec chmod 775 {} \;
find ${WP_ROOT}/wp-content -type f -exec chmod 664 {} \;

# Setup SELinux
semanage fcontext -a -t httpd_sys_content_t "$WP_ROOT(/.*)?"

# Fix wp-content
semanage fcontext -a -t httpd_sys_rw_content_t "$WP_ROOT/wp-content(/.*)?"

# Fix wp-config
semanage fcontext -a -t httpd_sys_rw_content_t "$WP_ROOT/wp-config.php"

# Restorecon
restorecon -R $WP_ROOT

