# sysadmintoolkit
Just storing quality questionable tools for sysAdmin work

## Site provisioning

* `installSiteWordpress.sh <fqdn> [mysql_root_password]` — database, WordPress, wp-config.php, SELinux labels, TLS certificate and nginx vhost
* `enableSite*.sh <fqdn>` — TLS certificate and nginx vhost for the given stack
* `dumpWordpress.sh` / `dumpJoomla.sh` — site dumps

## Permissions

* `fixWordpressSec.sh <wordpress_root_directory>` — reapplies the canonical permission scheme: root-owned code read-only for the site's php-fpm user (`wrdprs_<site>`), uploads owned by that user, nginx read via setgid group plus a named ACL entry, `wp-config.php` unreadable by nginx. Re-runnable; preserves webmaster grants.
* `grantSiteAccess.sh <fqdn> <uid|username> [--revoke]` — gives a webmaster read/write on one site via POSIX ACLs, with default ACLs so new files inherit the grant. Made for users coming in over the NFSv3 mount on the login server: pass the numeric UID (`id -u <user>` there) since AD users may not resolve on the web server. On WordPress sites it also sets `FS_CHMOD_FILE`/`FS_CHMOD_DIR` so files WordPress writes keep the ACL effective.
