#!/bin/sh
#
# Reapplies the canonical permission scheme used on the shared web server:
#
#   - Code is root-owned and read-only for the site's php-fpm user
#     (wrdprs_<site>), so WordPress cannot modify its own code
#   - nginx reads everything through the "nginx" group (setgid dirs) plus
#     a named group ACL entry, which survives directories created over
#     NFSv3 (the setgid bit is lost on mkdir over NFSv3)
#   - wp-content/uploads belongs to the php-fpm user (media uploads work)
#   - wp-config.php is root-owned, readable by the php-fpm user only,
#     and carries no ACL (nginx must not read database credentials)
#   - Webmaster ACL entries (see grantSiteAccess.sh) are preserved and
#     their masks are restored after the chmod pass
#
if [ -z "$1" ]; then
    echo "Usage: $0 <wordpress_root_directory>" >&2
    exit 1
fi

WP_ROOT=$(realpath "$1")
FQDN=$(basename "$WP_ROOT")
NON_FQDN=$(echo "$FQDN" | cut -f 1 -d .)
WP_USER=wrdprs_$NON_FQDN
WS_GROUP=nginx

if ! getent passwd $WP_USER > /dev/null; then
    echo "User $WP_USER does not exist; create the php-fpm pool user first" >&2
    exit 1
fi

set -e

echo "Resetting ownership and modes (code: root, uploads: $WP_USER)"
chown -R root:$WS_GROUP "$WP_ROOT"
find "$WP_ROOT" -type d -exec chmod 2750 {} +
find "$WP_ROOT" -type f -exec chmod 640 {} +

if [ -d "$WP_ROOT/wp-content/uploads" ]; then
    chown -R $WP_USER:$WS_GROUP "$WP_ROOT/wp-content/uploads"
fi

echo "Applying ACLs and recomputing masks"
setfacl -R -m u:$WP_USER:rX,g:$WS_GROUP:rX "$WP_ROOT"
find "$WP_ROOT" -type d -exec setfacl -m d:u:$WP_USER:rX,d:g:$WS_GROUP:rX {} +

if [ -f "$WP_ROOT/wp-config.php" ]; then
    setfacl -b "$WP_ROOT/wp-config.php"
    chown root:$WP_USER "$WP_ROOT/wp-config.php"
    chmod 640 "$WP_ROOT/wp-config.php"
fi

# Setup SELinux (-a fails if the rule already exists, fall back to -m)
echo "Setting up SELinux labels"
semanage fcontext -a -t httpd_sys_content_t "$WP_ROOT(/.*)?" 2>/dev/null \
    || semanage fcontext -m -t httpd_sys_content_t "$WP_ROOT(/.*)?"

# Fix wp-content
semanage fcontext -a -t httpd_sys_rw_content_t "$WP_ROOT/wp-content(/.*)?" 2>/dev/null \
    || semanage fcontext -m -t httpd_sys_rw_content_t "$WP_ROOT/wp-content(/.*)?"

# Fix wp-config
semanage fcontext -a -t httpd_sys_rw_content_t "$WP_ROOT/wp-config.php" 2>/dev/null \
    || semanage fcontext -m -t httpd_sys_rw_content_t "$WP_ROOT/wp-config.php"

# Restorecon
restorecon -R "$WP_ROOT"

echo Done
