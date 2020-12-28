#!/bin/sh
set -e

if [ -z $1 ]; then
	echo "Usage: $0 <path to Wordpress directory>"
	exit
fi

# Set locales
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8

# Files and paths
WORDPRESS_PATH=$1
WP_CONFIG_FILE=$1/wp-config.php

# Check if wp-config.php exists
if [ ! -f $WP_CONFIG_FILE ]; then
	echo "wp-config.php is missing; is this a Wordpress page?"
	exit
fi

# Genereate a name with the end of the WORDPRESS_PATH
WORDPRESS_NAME=`echo $1 | rev | cut -f 1 -d / | rev`

# Set dump files 
SQL_DUMP_FILE=$WORDPRESS_NAME.sql
WORDPRESS_DUMP_FILE=$WORDPRESS_NAME-dump.tar.bz2

# Get required variables to dump the database
DB_NAME=`grep DB_NAME $WP_CONFIG_FILE | cut -f 4 -d "'"`
DB_USER=`grep DB_USER $WP_CONFIG_FILE | cut -f 4 -d "'"`
DB_PASSWORD=`grep DB_PASSWORD $WP_CONFIG_FILE | cut -f 4 -d "'"`

echo Dumping SQL database to $SQL_DUMP_FILE
mysqldump -u$DB_USER -p$DB_PASSWORD $DB_NAME > $WORDPRESS_PATH/$SQL_DUMP_FILE

echo Compacting files and the database
tar cjpf $WORDPRESS_DUMP_FILE -C $WORDPRESS_PATH .
mv $WORDPRESS_DUMP_FILE $WORDPRESS_PATH/$WORDPRESS_DUMP_FILE

# Get the Wordpress table prefix
WORDPRESS_TABLE_PREFIX=`grep table_prefix $WP_CONFIG_FILE | cut -f 2 -d "'"`

# Fetch the site URL from database
cat > $WORDPRESS_PATH/fetchSiteURLQuery.sql << EOF
select option_name,option_value from ${WORDPRESS_TABLE_PREFIX}options where option_name = 'home' OR option_name = 'siteurl';
EOF

SITE_URL=`mysql -u$DB_USER -p"$DB_PASSWORD" $DB_NAME <$WORDPRESS_PATH/fetchSiteURLQuery.sql | grep http | cut -f 3 -d / | uniq`

rm -rf $WORDPRESS_PATH/fetchSiteURLQuery.sql

# Print the URL for downloading the dump
echo Download the dumped files from: $SITE_URL/$WORDPRESS_DUMP_FILE

echo Create the database with the following data:
echo Database Name: $DB_NAME
echo User: $DB_USER
echo Password: $DB_PASSWORD
echo
echo The commands are similar to:
echo mysql -u root -p -e \"create database $DB_NAME\"
echo mysql -u root -p -e \"GRANT ALL PRIVILEGES ON $DB_NAME.* TO \'$DB_USER\'@\'localhost\' IDENTIFIED BY \'$DB_PASSWORD\'\"
echo mysql -u root -p -e \"FLUSH PRIVILEGES\"
echo mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME \< wordpress.sql
echo

PASSWORD=`cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-' | head -c 16`
echo "Generated suggested database password if needed: $PASSWORD"
echo

echo Done

