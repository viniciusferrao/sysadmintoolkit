# sysadmintoolkit
Just storing quality questionable tools for sysAdmin work

## Install a site

* `installSiteWordpress.sh <fqdn> [mysql_root_password]` — Creates the database and installs WordPress. Writes wp-config.php and the nginx configuration. Gets the TLS certificate. Sets the SELinux labels.
* `enableSite*.sh <fqdn>` — Gets the TLS certificate and writes the nginx configuration for the given stack.
* `dumpWordpress.sh` / `dumpJoomla.sh` — Makes a dump of the site.

## Set permissions

* `fixWordpressSec.sh <wordpress_root_directory>` — Sets the standard permissions on one site. Root owns the code. The php-fpm user (`wrdprs_<site>`) can only read the code. The php-fpm user owns `wp-content/uploads`. nginx can read all files, but not `wp-config.php`. You can run this script more than one time. It keeps the webmaster ACL entries.
* `grantSiteAccess.sh <fqdn> <uid|username> [--revoke]` — Gives one webmaster read and write access to one site through POSIX ACLs. New files get the same access from the default ACLs. For users on the NFS mount, get the numeric UID on the login server with `id -u <user>`. On WordPress sites, the script also sets `FS_CHMOD_FILE` and `FS_CHMOD_DIR` in wp-config.php. Use `--revoke` to remove the access.
