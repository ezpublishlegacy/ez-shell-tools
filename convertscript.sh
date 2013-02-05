#!/bin/sh
#Copyright 2007-2012 Leidentech All rights reserved.
#license http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

dbversion ()
{
dbversion=`php -r "require 'autoload.php';
echo eZPublishSDK::databaseVersion(false);"`
echo $dbversion
}
version ()
{
version=`php -r "require 'autoload.php';
echo eZPublishSDK::version();"`
echo $version
}

sites ()
{
sites=`php -r "require 'autoload.php';
\\$ini = eZINI::instance();
\\$sitelist=\\$ini->variable( 'SiteSettings', 'SiteList' );
foreach(\\$sitelist as \\$site) echo \\$site.' ';"`
echo $sites
}

adminsites ()
{
for siteaccess in `sites`
do
if [ `echo $siteaccess|grep -ic "admin"` -ne 0 ]
then
        echo $siteaccess
fi
done
}

dbinfo ()
{
dbinfo=`php -r "require 'autoload.php';
\\$script = eZScript::instance( array( 'debug-message' => '', 'use-session' => true, 'use-modules' => true, 'use-extensions' => true ) );
\\$script->startup();
\\$script->setUseSiteAccess( '${1}' );
\\$script->initialize();
\\$ini = eZINI::instance();
\\$database=\\$ini->variable( 'DatabaseSettings', 'Database' );
\\$user=\\$ini->variable( 'DatabaseSettings', 'User' );
\\$password=\\$ini->variable( 'DatabaseSettings', 'Password' );
\\$script->shutdown();
echo \\$database.' '.\\$user.' '.\\$password;"`
echo $dbinfo;
}
newtype ()
{
echo "Converting all tables to InnoDB"
dbinfo `adminsites`|while read db user password
do
	php bin/php/ezconvertmysqltabletype.php --host=localhost  --user=$user --database=$db --password=$password --newtype=InnoDB 2>/dev/null
done
}
upto352 ()
{
echo "Starting 3.5.2 upgrade"
dbinfo `adminsites`|while read db user password
do
        mysql -u $user --password=$password $db < update/database/mysql/3.5/dbupdate-3.5.1-to-3.5.2.sql|egrep -v "Warning|Notice"
done
newtype
}
upto36 ()
{
echo "Starting 3.6 upgrade"
dbinfo `adminsites`|while read db user password
do
        mysql -f -u $user --password=$password $db < update/database/mysql/3.6/dbupdate-3.5.2-to-3.6.0.sql
done
newtype
echo "Starting scripts"
for siteaccess in `adminsites`
do
	echo "Updating Top level"
	php update/common/scripts/updatetoplevel.php -s $siteaccess
	echo "Updating eztimetype"
	php update/common/scripts/updateeztimetype.php -s $siteaccess
	echo "Updating xmllinks"
	php update/common/scripts/convertxmllinks.php -s $siteaccess
done
for siteaccess in `sites`
do #this has to be run on ALL site accesses
	echo "Updating eztimetype"
	php update/common/scripts/updateeztimetype.php -s $siteaccess
done
dbinfo `adminsites`|while read db user password
do
	echo "Updating crc"
	php update/common/scripts/updatecrc32.php $user:$password:$db:mysql
done
}
upto38 ()
{
echo "Starting 3.8 upgrade"
dbinfo `adminsites`|while read db user password
do
        mysql -f -u $user --password=$password $db < update/database/mysql/3.8/dbupdate-3.6.0-to-3.8.0.sql
done
newtype
echo "Starting scripts"
for siteaccess in `adminsites`
do
	echo "Updating multilingual"
        php update/common/scripts/updatemultilingual.php -s $siteaccess
	echo "Updating rss import"
	php update/common/scripts/updaterssimport.php -s $siteaccess
done
}
upto39 ()
{
echo "Starting 3.9 upgrade"
dbinfo `adminsites`|while read db user password
do
	for sql in update/database/mysql/3.9/*.sql
	do
		echo "running $sql"
        	mysql -f -u $user --password=$password $db < $sql
		if [ $? -ne 0 ]
		then
			echo $sql failed!!!
			#sqlfail=true
			exit
		fi
	done
done
if [ -n "$sqlfail" ]
then
	echo "FIX THE DB ERROR FIRST"
	exit
fi
echo "Done with DB conversions."
newtype
echo "Starting scripts"
for siteaccess in `adminsites`
do
	#This should be the main language for each site
	echo "Updating class translations"
	php update/common/scripts/3.9/updateclasstranslations.php -s $siteaccess --language=eng-GB
	if [ $? -ne 0 ]
	then
		echo translation failed!!!
		exit
	fi
	echo "Updating xmltext"
	php update/common/scripts/3.9/correctxmltext.php -s $siteaccess
	echo "Updating typerelation"
	php update/common/scripts/3.9/updatetypedrelation.php -s $siteaccess	

done
}
upto310 ()
{
echo "Starting 3.10 upgrade"
dbinfo `adminsites`|while read db user password
do
	for sql in update/database/mysql/3.10/*.sql
	do
		echo "running $sql"
        	mysql -u $user --password=$password $db < $sql
		if [ $? -ne 0 ]
		then
			echo $sql failed!!!
			sqlfail=true
			exit
		fi
	done
done
if [ -n "$sqlfail" ]
then
        echo "FIX THE DB ERROR FIRST"
	exit
fi
echo "Done with DB conversions."
newtype
echo "Starting scripts"
for siteaccess in `adminsites`
do
	echo "Updating nice urls"
	php bin/php/updateniceurls.php -s $siteaccess
	echo "Importing dba file"
	php bin/php/ezimportdbafile.php --datatype=ezisbn -s $siteaccess
	echo "Converting isbn13 file"
	php bin/php/ezconvert2isbn13.php -s $siteaccess
	echo "Updating multioption datatype"
	php update/common/scripts/3.10/updatemultioption.php -s $siteaccess
	echo "Updating tipafriend"
	php update/common/scripts/3.10/updatetipafriendpolicy.php -s $siteaccess -l admin -p password
	echo "Updating vatcountries"
	php4 update/common/scripts/3.10/updatevatcountries.php -s $siteaccess
done
}
upto400 ()
{
echo "Starting 4.0 upgrade"
dbinfo `adminsites`|while read db user password
do
	for sql in update/database/mysql/4.0/*.sql
	do
		echo "running $sql"
        	mysql -f -u $user --password=$password $db < $sql
		if [ $? -ne 0 ]
		then
			echo $sql failed!!!
			sqlfail=true
			exit
		fi
		if [ -n "$sqlfail" ]
		then
        		echo "FIX THE DB ERROR FIRST"
			exit
		fi
	done
	echo "Removing 3.10 nicely updated urls"
	mysql -u $user --password=$password $db -e "UPDATE ezurlalias SET is_imported=0; TRUNCATE ezurlalias_ml;"
	echo "Done with DB conversions."
done
newtype
echo "Starting scripts"
for siteaccess in `adminsites`
do
	echo "Updating binary files"
	/usr/bin/php5 update/common/scripts/4.0/updatebinaryfile.php -s $siteaccess
done
}
upto401 ()
{
echo "Starting 4.0.1 upgrade"
dbinfo `adminsites`|while read db user password
do
#DOING URL ALIASES LATER
	#echo "Adding ezurlalias_migration schema"
	#mysql -u $user --password=$password $db < extension/ezurlaliasmigration/sql/mysql/schema.sql
	for sql in update/database/mysql/4.0/*.sql
	do
		echo "running $sql"
        	mysql -f -u $user --password=$password $db < $sql
		if [ $? -ne 0 ]
		then
			echo $sql failed!!!
			sqlfail=true
			exit
		fi
		if [ -n "$sqlfail" ]
		then
        		echo "FIX THE DB ERROR FIRST"
			exit
		fi
	done
	echo "Done with DB conversions."
done
newtype
echo "Starting scripts"
for siteaccess in `adminsites`
do
	echo "Updating binary files"
	/usr/bin/php5 update/common/scripts/4.0/updatebinaryfile.php -s $siteaccess
	echo "Fixing object remote id"
	/usr/bin/php5 update/common/scripts/4.0/fixobjectremoteid.php -s $siteaccess
	echo "Updating binary files"
	/usr/bin/php5 update/common/scripts/4.0/updatebinaryfile.php -s $siteaccess
	#echo "Creating migration table"
	#php5 extension/ezurlaliasmigration/scripts/migrate.php --create-migration-table
	#echo "migrating url aliases"
	#php5 extension/ezurlaliasmigration/scripts/migrate.php --migrate
	#mysql -u $user --password=$password $db -e "UPDATE ezurlalias SET is_imported=0; TRUNCATE ezurlalias_ml;"
	#echo "Updating nice urls"
        #/usr/bin/php5 bin/php/updateniceurls.php --import --fetch-limit=100 -s $siteaccess
        #php extension/ezurlaliasmigration/scripts/migrate.php --restore
	echo "Updating tipafriend"
	/usr/bin/php5 update/common/scripts/4.0/updatetipafriendpolicy.php -s $siteaccess -l admin -p $password
	#echo "Updating vatcountries" Doesn't exist, but documented ?!?
	/usr/bin/php5 update/common/scripts/4.0/updatevatcountries.php -s $siteaccess
done
}
upto403 ()
{
echo "Starting 4.0.3 upgrade"
dbinfo `adminsites`|while read db user password
do
	#mysql -f -u $user --password=$password $db < update/database/mysql/4.0/dbupdate-4.0.1-to-4.0.2.sql
	#mysql -f -u $user --password=$password $db < update/database/mysql/4.0/dbupdate-4.0.2-to-4.0.3.sql
        continue
done

#THIS WILL BE DONE BELOW
#for siteaccess in `adminsites`
#do
	#php5 extension/ezurlaliasmigration/scripts/migrate.php --create-migration-table -s $siteaccess
	#php5 extension/ezurlaliasmigration/scripts/migrate.php --migrate -s $siteaccess
#done
#dbinfo|while read db user password
#do
	#mysql -u $user --password=$password $db -e "UPDATE ezurlalias SET is_imported=0; TRUNCATE ezurlalias_ml;"
#done
newtype
#echo "Starting scripts"
#for siteaccess in `adminsites`
#do
	#php5 update/common/scripts/4.0/initurlaliasmlid.php -s $siteaccess
	#echo "Updating nice urls"
        #/usr/bin/php5 bin/php/updateniceurls.php --import --fetch-limit=100 -s $siteaccess
        #php extension/ezurlaliasmigration/scripts/migrate.php --restore -s $siteaccess
#done
}
upto410 ()
{
echo "Starting 4.1.0 upgrade"
dbinfo `adminsites`|while read db user password
do
	for sql in update/database/mysql/4.1/*.sql
	do
		echo "running $sql"
        	mysql -f -u $user --password=$password $db < $sql
		if [ $? -ne 0 ]
		then
			echo $sql failed!!!
			sqlfail=true
			exit
		fi
		if [ -n "$sqlfail" ]
		then
        		echo "FIX THE DB ERROR FIRST"
			exit
		fi
	done
done
echo "Starting scripts"
for siteaccess in `adminsites`
do
	# addlockstategroup.php (used for creating locked states, part of the object states functionality)
	# fixclassremoteid.php (fixing remote ids of classes)
	# fixezurlobjectlinks.php (to fix older occurrences of link items not being present in the ezurl_object_table for all versions/translations)
	# fixobjectremoteid.php (to fix non-unique usage of content object remote ID's)
	# initurlaliasmlid.php (Initialize the ezurlalias_ml_incr table, part of the fixed issue #14077: eZURLAliasML database table lock and unlock code causes implicit commit of database transaction)
	# updateimagesystem.php (optional: update all attributes with datatype ezimage to use the new image system introduced in eZ Publish 3.3 as older items may still exist)

	echo "Doing addlockstategroup.php"
	php5 update/common/scripts/4.1/addlockstategroup.php -s $siteaccess
	echo "Doing fixclassremoteid.php"
	php5 update/common/scripts/4.1/fixclassremoteid.php -s $siteaccess
	echo "Doing fixezurlobjectlinks.php"
	php5 update/common/scripts/4.1/fixezurlobjectlinks.php -s $siteaccess
	echo "Doing fixobjectremoteid.php"
	php5 update/common/scripts/4.1/fixobjectremoteid.php -s $siteaccess
	echo "Doing initurlaliasmlid.php"
	php5 update/common/scripts/4.1/initurlaliasmlid.php -s $siteaccess
	#echo "Doing updateimagesystem.php"
	#Undocumented!!
	#correctxmlalign.php
	php5 update/common/scripts/4.1/correctxmlalign.php -s $siteaccess
	#fixnoderemoteid.php
	php5 update/common/scripts/4.1/fixnoderemoteid.php -s $siteaccess
done
}
upto420 ()
{
echo "Starting 4.2.0 upgrade"
#If you are upgrading to the 4.2 series of eZ Publish for the first time, and the installation at hand has been running since prior to eZ Publish 3.3 then you need to run the updateimagesystem.php script before running any of the dbupdate scripts for version 4.2.
#php5 update/common/scripts/4.1/updateimagesystem.php -s $siteaccess

echo "Adding ezurlalias_migration schema"
dbinfo `adminsites`|while read db user password
do
	mysql -u $user --password=$password $db < extension/ezurlaliasmigration/sql/mysql/schema.sql
	for sql in update/database/mysql/4.2/*.sql
	do
		echo "running $sql"
        	mysql -f -u $user --password=$password $db < $sql
		if [ $? -ne 0 ]
		then
			echo $sql failed!!!
			sqlfail=true
			exit
		fi
		if [ -n "$sqlfail" ]
		then
        		echo "FIX THE DB ERROR FIRST"
			exit
		fi
	done
done
echo "Starting scripts"
for siteaccess in `adminsites`
do
	php5 update/common/scripts/4.2/fixorphanimages.php -s $siteaccess
	echo "migrating url aliases"
	php5 extension/ezurlaliasmigration/scripts/migrate.php --migrate
	#Shouldn't need this mysql -u $user --password=$password $db -e "UPDATE ezurlalias SET is_imported=0; TRUNCATE ezurlalias_ml;"
	echo "Updating nice urls"
        /usr/bin/php5 bin/php/updateniceurls.php --import --fetch-limit=100 -s $siteaccess
        php extension/ezurlaliasmigration/scripts/migrate.php --restore
done
}
upto430 ()
{
echo "Starting 4.3.0 upgrade"

dbinfo `adminsites`|while read db user password
do
	for sql in update/database/mysql/4.3/dbupdate-4.2.0-to-4.3.0.sql
	do
		echo "running $sql"
        	mysql -f -u $user --password=$password $db < $sql
		if [ $? -ne 0 ]
		then
			echo $sql failed!!!
			sqlfail=true
			exit
		fi
		if [ -n "$sqlfail" ]
		then
        		echo "FIX THE DB ERROR FIRST"
			exit
		fi
	done
done
echo "Starting scripts"
for siteaccess in `adminsites`
do
	echo "Updating Node Assignments"
	php5 update/common/scripts/4.3/updatenodeassignment.php  --allow-root-user
done
}
upto440 ()
{
echo "Starting 4.4.0 upgrade"

dbinfo `adminsites`|while read db user password
do
	for sql in update/database/mysql/4.4/*.sql
	do
		echo "running $sql"
        	mysql -f -u $user --password=$password $db < $sql
		if [ $? -ne 0 ]
		then
			echo $sql failed!!!
			sqlfail=true
			exit
		fi
		if [ -n "$sqlfail" ]
		then
        		echo "FIX THE DB ERROR FIRST"
			exit
		fi
	done
done
echo "Starting scripts"
for siteaccess in `adminsites`
do
	echo "Updating Node Assignments"
	php5 update/common/scripts/4.4/updatesectionidentifier.php --allow-root-user
done
}

########
#      #
# MAIN #
#      #
########
dbinfo `adminsites`
echo Database Version: `dbversion`
echo File System Version: `version`
case $1 in
	1) upto352;;
	2) upto36;;
	3) upto38;;
	4) upto39;;
	5) upto310;;
	6) upto400;;
	7) upto401;;
	8) upto403;;
	9) upto410;;
	10) upto420;;
	11) upto430;;
	12) upto440;;
	*) cat <<EOF
input needed:
	1 upto352 you should be in the 3.6 directory
	2 upto36 you should be in the 3.6 directory
	3 upto38 you should be in the 3.8 directory
	4 upto39 you should be in the 3.9 directory
	5 upto310 you should be in the 3.10 directory
	6 upto400 you should be in the 4.0 directory
	7 upto401 you should be in the 4.0 directory
	8 upto403 you should be in the 4.0 directory
	9 upto410 you should be in the 4.0 directory
	10 upto420 you should be in the 4.0 directory
	11 upto430 you should be in the 4.3 directory
	12 upto440 you should be in the 4.4 directory
EOF
	   ;;
esac
