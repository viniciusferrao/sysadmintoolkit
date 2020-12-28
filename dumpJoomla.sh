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
JOOMLA_PATH=$1
JOOMLA_CONFIG_FILE=$1/configuration.php

# Check if configuration.php exists
if [ ! -f $JOOMLA_CONFIG_FILE ]; then
	echo "configuration.php is missing; is this a Joomla page?"
	exit
fi

# Genereate a name with the end of the JOOMLA_PATH
JOOMLA_NAME=`echo $1 | rev | cut -f 1 -d / | rev`

# Set dump files 
SQL_DUMP_FILE=$JOOMLA_NAME.sql
JOOMLA_DUMP_FILE=$JOOMLA_NAME-dump.tar.bz2

# Get required variables to dump the database
DB_NAME=`grep "db " $JOOMLA_CONFIG_FILE | cut -f 2 -d "'"`
DB_USER=`grep "user " $JOOMLA_CONFIG_FILE | cut -f 2 -d "'"`
DB_PASSWORD=`grep "password " $JOOMLA_CONFIG_FILE | cut -f 2 -d "'"`

echo Dumping SQL database to $SQL_DUMP_FILE
mysqldump -u$DB_USER -p$DB_PASSWORD $DB_NAME > $JOOMLA_PATH/$SQL_DUMP_FILE

echo Compacting files and the database
tar cjpf $JOOMLA_DUMP_FILE -C $JOOMLA_PATH .
mv $JOOMLA_DUMP_FILE $JOOMLA_PATH/$JOOMLA_DUMP_FILE

# Get the Wordpress table prefix
JOOMLA_TABLE_PREFIX=`grep "dbprefix " $JOOMLA_CONFIG_FILE | cut -f 2 -d "'"`

# Fetch the site URL from database
#cat > $JOOMLA_PATH/fetchSiteURLQuery.sql << EOF
#select option_name,option_value from ${JOOMLA_TABLE_PREFIX}options where option_name = 'home' OR option_name = 'siteurl';
#EOF
#
#SITE_URL=`mysql -u$DB_USER -p"$DB_PASSWORD" $DB_NAME <$JOOMLA_PATH/fetchSiteURLQuery.sql | grep http | cut -f 3 -d / | uniq`
#
#rm -rf $JOOMLA_PATH/fetchSiteURLQuery.sql

# Print the URL for downloading the dump
#echo Download the dumped files from: $SITE_URL/$JOOMLA_DUMP_FILE

echo Create the database with the following data:
echo Database Name: $DB_NAME
echo User: $DB_USER
echo Password: $DB_PASSWORD
echo
echo The commands are similar to:
echo mysql -u root -p -e \"create database $DB_NAME\"
echo mysql -u root -p -e \"GRANT ALL PRIVILEGES ON $DB_NAME.* TO \'$DB_USER\'@\'localhost\' IDENTIFIED BY \'$DB_PASSWORD\'\"
echo mysql -u root -p -e \"FLUSH PRIVILEGES\"
echo mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME \< $SQL_DUMP_FILE 
echo

PASSWORD=`cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-' | head -c 16`
echo "Generated suggested database password if needed: $PASSWORD"
echo

echo Done

