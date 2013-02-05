#!/bin/sh
#Copyright 2007-2012 Leidentech All rights reserved.
#license http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

sites ()
{
	echo "en fr"
}
adminsites ()
{
	echo "admin admin2"
}
dbinfo ()
{
cat <<-EOF
<database> <user> <password>
<database2> <user2> <password2>
EOF
}
newtype ()
{
echo "Converting all tables to InnoDB"
dbinfo|while read db user password
do
	php bin/php/ezconvertmysqltabletype.php --host=localhost  --user=$user --database=$db --password=$password --newtype=InnoDB 2>/dev/null
done
}
upto352 ()
{
echo "Starting 3.5.2 upgrade"
dbinfo|while read db user password
do
        mysql -u $user --password=$password $db < update/database/mysql/3.5/dbupdate-3.5.1-to-3.5.2.sql|egrep -v "Warning|Notice"
done
newtype
}
upto36 ()
{
echo "Starting 3.6 upgrade"
dbinfo|while read db user password
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
dbinfo|while read db user password
do
	echo "Updating crc"
	php update/common/scripts/updatecrc32.php $user:$password:$db:mysql
done
}
upto38 ()
{
echo "Starting 3.8 upgrade"
dbinfo|while read db user password
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
dbinfo|while read db user password
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
dbinfo|while read db user password
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
dbinfo|while read db user password
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
dbinfo|while read db user password
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
	echo "Done with DB conversions."
done
newtype
echo "Starting scripts"
for siteaccess in `adminsites`
do
	echo "Fixing object remote id"
	/usr/bin/php5 update/common/scripts/4.0/fixobjectremoteid.php -s $siteaccess
	echo "Updating binary files"
	/usr/bin/php5 update/common/scripts/4.0/updatebinaryfile.php -s $siteaccess
#php5 extension/ezurlaliasmigration/scripts/migrate.php --create-migration-table
#php5 extension/ezurlaliasmigration/scripts/migrate.php --migrate
#mysql -u $user --password=$password $db -e "UPDATE ezurlalias SET is_imported=0; TRUNCATE ezurlalias_ml;"
	echo "Updating nice urls"
        /usr/bin/php5 bin/php/updateniceurls.php --import --fetch-limit=100 -s $siteaccess
        php extension/ezurlaliasmigration/scripts/migrate.php --restore
	echo "Updating tipafriend"
	/usr/bin/php5 update/common/scripts/4.0/updatetipafriendpolicy.php -s $siteaccess -l admin -p $password
	#echo "Updating vatcountries" Doesn't exist, but documented ?!?
	#/usr/bin/php5 update/common/scripts/4.0/updatevatcountries.php -s $siteaccess
done
}
upto403 ()
{
echo "Starting 4.0.3 upgrade"
dbinfo|while read db user password
do
	#mysql -f -u $user --password=$password $db < update/database/mysql/4.0/dbupdate-4.0.1-to-4.0.2.sql
	#mysql -f -u $user --password=$password $db < update/database/mysql/4.0/dbupdate-4.0.2-to-4.0.3.sql
        continue
done
for siteaccess in `adminsites`
do
	php5 extension/ezurlaliasmigration/scripts/migrate.php --create-migration-table -s $siteaccess
	php5 extension/ezurlaliasmigration/scripts/migrate.php --migrate -s $siteaccess
done
dbinfo|while read db user password
do
	mysql -u $user --password=$password $db -e "UPDATE ezurlalias SET is_imported=0; TRUNCATE ezurlalias_ml;"
done
newtype
echo "Starting scripts"
for siteaccess in `adminsites`
do
	#php5 update/common/scripts/4.0/initurlaliasmlid.php -s $siteaccess
	echo "Updating nice urls"
        /usr/bin/php5 bin/php/updateniceurls.php --import --fetch-limit=100 -s $siteaccess
        php extension/ezurlaliasmigration/scripts/migrate.php --restore -s $siteaccess
done
}
########
#      #
# MAIN #
#      #
########
case $1 in
	1) upto352;;
	2) upto36;;
	3) upto38;;
	4) upto39;;
	5) upto310;;
	6) upto400;;
	7) upto401;;
	8) upto403;;
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
EOF
	   ;;
esac
