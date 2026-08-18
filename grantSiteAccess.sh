#!/bin/sh
#
# Grants (or revokes) read/write access on a site's directory tree for a
# webmaster user, without touching the site's ownership scheme. Run on
# the web server, never through the NFS mount.
#
# Sites are managed over an NFSv3 mount (sec=sys) on the login server,
# where permission checks are done by numeric UID. AD users usually do
# not resolve on the web server, so get the UID on the login server
# first with: id -u <user>
#
# The access ACL covers existing files; default ACLs make every new file
# and directory inherit the grant, so nothing needs to be reapplied. A
# named "nginx" group entry is also (re)applied because mkdir over NFSv3
# loses the setgid bit, which would otherwise leave nginx unable to read
# files inside directories the webmaster creates.
#
# On WordPress sites, FS_CHMOD_FILE/FS_CHMOD_DIR are added to
# wp-config.php so files written by WordPress keep group-class rw and
# the webmaster ACL stays effective (WordPress's default chmod 0644
# would drop the ACL mask to r--).
#
if [ -z "$2" ]; then
    echo "Usage: $0 <fqdn> <uid|username> [--revoke]" >&2
    exit 1
fi

WWW_PATH=/var/www/html
WS_GROUP=nginx

FQDN=$1
SITE=$WWW_PATH/$FQDN

if [ ! -d "$SITE" ]; then
    echo "Site directory $SITE not found" >&2
    exit 1
fi

case $2 in
    *[!0-9]*)
        TARGET_UID=$(getent passwd "$2" | cut -d : -f 3)
        if [ -z "$TARGET_UID" ]; then
            echo "User $2 does not resolve here; pass the numeric UID (run: id -u $2 on the login server)" >&2
            exit 1
        fi
        ;;
    *)
        TARGET_UID=$2
        ;;
esac

set -e

if [ "$3" = "--revoke" ]; then
    echo "Revoking access of uid $TARGET_UID on $SITE"
    setfacl -R -x u:$TARGET_UID "$SITE"
    find "$SITE" -type d -exec setfacl -x d:u:$TARGET_UID {} +
    echo Done
    exit 0
fi

echo "Granting rw to uid $TARGET_UID on $SITE"
setfacl -R -m u:$TARGET_UID:rwX,g:$WS_GROUP:rX "$SITE"
find "$SITE" -type d -exec setfacl -m d:u:$TARGET_UID:rwX,d:g:$WS_GROUP:rX {} +

WP_CONFIG=$SITE/wp-config.php
if [ -f "$WP_CONFIG" ] && ! grep -q FS_CHMOD_FILE "$WP_CONFIG"; then
    if grep -q FS_METHOD "$WP_CONFIG"; then
        BACKUP=/root/wp-config.php.$FQDN.$(date +%F)
        cp -p "$WP_CONFIG" "$BACKUP"
        OWNERSHIP=$(stat -c %U:%G "$WP_CONFIG")
        MODE=$(stat -c %a "$WP_CONFIG")
        # sed -i does not preserve owner/group; restore them afterwards
        sed -i "/FS_METHOD/a define('FS_CHMOD_FILE', 0660);\ndefine('FS_CHMOD_DIR', 02770);" "$WP_CONFIG"
        chown "$OWNERSHIP" "$WP_CONFIG"
        chmod "$MODE" "$WP_CONFIG"
        command -v php > /dev/null && php -l "$WP_CONFIG"
        echo "Added FS_CHMOD_FILE/FS_CHMOD_DIR to wp-config.php (backup: $BACKUP)"
    else
        echo "WARNING: no FS_METHOD line in wp-config.php;" >&2
        echo "add FS_CHMOD_FILE 0660 / FS_CHMOD_DIR 02770 to it manually" >&2
    fi
fi

echo "Resulting ACL on $SITE:"
getfacl -p --omit-header "$SITE"
echo "Note: the NFS client caches ACLs for up to a minute; test the access after that."
echo Done
