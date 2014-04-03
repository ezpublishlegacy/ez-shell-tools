#!/bin/sh
#Copyright 2007-2014 Leidentech All rights reserved.
#license http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

dbversion ()
{
dbversion=`php -r "require 'autoload.php';
\\$script = eZScript::instance( array( 'debug-message' => '', 'use-session' => true, 'use-modules' => true, 'use-extensions' => true ) );
\\$script->startup();
\\$script->setUseSiteAccess( '${1}' );
\\$script->initialize();
//echo eZPublishSDK::databaseVersion(false);
\\$dbversionArray=eZSetupFunctionCollection::fetchFullVersionString();
echo \\$dbversionArray['result'];
\\$script->shutdown();"`
echo $dbversion
}
version ()
{
version=`php -r "require 'autoload.php';
\\$script = eZScript::instance( array( 'debug-message' => '', 'use-session' => true, 'use-modules' => true, 'use-extensions' => true ) );
\\$script->startup();
\\$script->setUseSiteAccess( '${1}' );
\\$script->initialize();
echo eZPublishSDK::version();
\\$script->shutdown();"`
echo $version
}

sites ()
{
sites=`php -r "require 'autoload.php';
\\$script = eZScript::instance( array( 'debug-message' => '', 'use-session' => true, 'use-modules' => true, 'use-extensions' => true ) );
\\$script->startup();
\\$script->setUseSiteAccess( '${1}' );
\\$script->initialize();
\\$ini = eZINI::instance();
\\$sitelist=\\$ini->variable( 'SiteSettings', 'SiteList' );
\\$script->shutdown();
foreach(\\$sitelist as \\$site) echo \\$site.' ';"`
echo $sites
}

adminsites ()
{
for siteaccess in `sites $1`
do
if [ `echo $siteaccess|grep -ic "admin"` -ne 0 ]
then
	if [ "$siteaccess" = $1 ]
	then
        	echo $siteaccess
	fi
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
dbinfo `adminsites $1`|while read db user password
do
	php bin/php/ezconvertmysqltabletype.php --host=localhost  --user=$user --database=$db --password=$password --newtype=InnoDB 2>/dev/null
done
}
upto352 () #1
{
echo "Starting 3.5.2 upgrade"
dbinfo `adminsites $1`|while read db user password
do
        mysql -u $user --password=$password $db < update/database/mysql/3.5/dbupdate-3.5.1-to-3.5.2.sql|egrep -v "Warning|Notice"
done
newtype
}
upto36 () #2
{
echo "Starting 3.6 upgrade"
dbinfo `adminsites $1`|while read db user password
do
        mysql -f -u $user --password=$password $db < update/database/mysql/3.6/dbupdate-3.5.2-to-3.6.0.sql
done
newtype
echo "Starting scripts"
for siteaccess in `adminsites $1`
do
	echo "Updating Top level"
	php update/common/scripts/updatetoplevel.php -s $siteaccess
	echo "Updating eztimetype"
	php update/common/scripts/updateeztimetype.php -s $siteaccess
	echo "Updating xmllinks"
	php update/common/scripts/convertxmllinks.php -s $siteaccess
done
for siteaccess in `sites $1`
do #this has to be run on ALL site accesses
	echo "Updating eztimetype"
	php update/common/scripts/updateeztimetype.php -s $siteaccess
done
dbinfo `adminsites $1`|while read db user password
do
	echo "Updating crc"
	php update/common/scripts/updatecrc32.php $user:$password:$db:mysql
done
}
upto38 () #3
{
echo "Starting 3.8 upgrade"
dbinfo `adminsites $1`|while read db user password
do
        mysql -f -u $user --password=$password $db < update/database/mysql/3.8/dbupdate-3.6.0-to-3.8.0.sql
done
newtype
echo "Starting scripts"
for siteaccess in `adminsites $1`
do
	echo "Updating multilingual"
        php update/common/scripts/updatemultilingual.php -s $siteaccess
	echo "Updating rss import"
	php update/common/scripts/updaterssimport.php -s $siteaccess
done
}
upto39 () #4
{
echo "Starting 3.9 upgrade"
dbinfo `adminsites $1`|while read db user password
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
for siteaccess in `adminsites $1`
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
upto310 () #5
{
echo "Starting 3.10 upgrade"
dbinfo `adminsites $1`|while read db user password
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
for siteaccess in `adminsites $1`
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
upto400 () #6
{
echo "Starting 4.0 upgrade"
dbinfo `adminsites $1`|while read db user password
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
for siteaccess in `adminsites $1`
do
	echo "Updating binary files"
	/usr/bin/php5 update/common/scripts/4.0/updatebinaryfile.php -s $siteaccess
done
}
upto401 () #7
{
echo "Starting 4.0.1 upgrade"
dbinfo `adminsites $1`|while read db user password
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
for siteaccess in `adminsites $1`
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
upto403 () #8
{
echo "Starting 4.0.3 upgrade"
dbinfo `adminsites $1`|while read db user password
do
	#mysql -f -u $user --password=$password $db < update/database/mysql/4.0/dbupdate-4.0.1-to-4.0.2.sql
	#mysql -f -u $user --password=$password $db < update/database/mysql/4.0/dbupdate-4.0.2-to-4.0.3.sql
        continue
done

#THIS WILL BE DONE BELOW
#for siteaccess in `adminsites $1`
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
#for siteaccess in `adminsites $1`
#do
	#php5 update/common/scripts/4.0/initurlaliasmlid.php -s $siteaccess
	#echo "Updating nice urls"
        #/usr/bin/php5 bin/php/updateniceurls.php --import --fetch-limit=100 -s $siteaccess
        #php extension/ezurlaliasmigration/scripts/migrate.php --restore -s $siteaccess
#done
}
upto410 () #9
{
echo "Starting 4.1.0 upgrade"
dbinfo `adminsites $1`|while read db user password
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
for siteaccess in `adminsites $1`
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
	#echo "Doing initurlaliasmlid.php"
	#php5 update/common/scripts/4.1/initurlaliasmlid.php -s $siteaccess
	#echo "Doing updateimagesystem.php"
	#Undocumented!!
	#correctxmlalign.php
	php5 update/common/scripts/4.1/correctxmlalign.php -s $siteaccess
	#fixnoderemoteid.php
	php5 update/common/scripts/4.1/fixnoderemoteid.php -s $siteaccess
done
}
upto420 () #10
{
echo "Starting 4.2.0 upgrade"
#If you are upgrading to the 4.2 series of eZ Publish for the first time, and the installation at hand has been running since prior to eZ Publish 3.3 then you need to run the updateimagesystem.php script before running any of the dbupdate scripts for version 4.2.
#php5 update/common/scripts/4.1/updateimagesystem.php -s $siteaccess

echo "Adding ezurlalias_migration schema"
dbinfo `adminsites $1`|while read db user password
do
	#mysql -u $user --password=$password $db < extension/ezurlaliasmigration/sql/mysql/schema.sql
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
for siteaccess in `adminsites $1`
do
	php5 update/common/scripts/4.2/fixorphanimages.php -s $siteaccess
	#echo "migrating url aliases"
	#php5 extension/ezurlaliasmigration/scripts/migrate.php --migrate
	##Shouldn't need this mysql -u $user --password=$password $db -e "UPDATE ezurlalias SET is_imported=0; TRUNCATE ezurlalias_ml;"
	echo "Updating nice urls"
        #/usr/bin/php5 bin/php/updateniceurls.php --import --fetch-limit=100 -s $siteaccess
        /usr/bin/php5 bin/php/updateniceurls.php -s $siteaccess
        #php extension/ezurlaliasmigration/scripts/migrate.php --restore
done
}
upto430 () #11
{
echo "Starting 4.3.0 upgrade"

dbinfo `adminsites $1`|while read db user password
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
for siteaccess in `adminsites $1`
do
	echo "Updating Node Assignments"
	php5 update/common/scripts/4.3/updatenodeassignment.php  --allow-root-user -s $siteaccess
done
}
upto440 () #12
{
echo "Starting 4.4.0 upgrade"

dbinfo `adminsites $1`|while read db user password
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
}
upto450 () #13
{
echo "Starting 4.5.0 upgrade"

dbinfo `adminsites $1`|while read db user password
do
	for sql in update/database/mysql/4.5/*.sql
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
for siteaccess in `adminsites $1`
do
	echo "Updating Section Identifier"
	php update/common/scripts/4.5/updatesectionidentifier.php --allow-root-user -s $siteaccess
done
}
upto2011_5 () #14
{
echo "Starting 2011.5 upgrade"

dbinfo `adminsites $1`|while read db user password
do
	mysql -u $user --password=$password $db -e "CREATE TABLE ezorder_nr_incr ( id int(11) NOT NULL AUTO_INCREMENT, PRIMARY KEY  (id) ) ENGINE=InnoDB;"
done
echo "No scripts"

}
upto2011_9 () #15
{
echo "Starting 2011.9 upgrade"

dbinfo `adminsites $1`|while read db user password
do
	mysql -u $user --password=$password $db -e "UPDATE ezworkflow_event SET data_text5 = data_text3, data_text3 = '' WHERE workflow_type_string = 'event_ezmultiplexer';"
done
echo "Starting scripts"
for siteaccess in `adminsites $1`
do
	echo "Removing trashed images"
	php update/common/scripts/4.6/removetrashedimages.php --allow-root-user -s $siteaccess
	echo "Updating order number"
	php update/common/scripts/4.6/updateordernumber.php --allow-root-user -s $siteaccess
done
}
upto2012_2 () #16
{
echo "Starting 2012.2 upgrade"

dbinfo `adminsites $1`|while read db user password
do
	mysql -u $user --password=$password $db -e "ALTER TABLE ezpending_actions ADD COLUMN id int(11) AUTO_INCREMENT PRIMARY KEY;"
	mysql -u $user --password=$password $db -e "DELETE FROM ezuser_accountkey WHERE user_id IN ( SELECT user_id FROM ezuser_setting WHERE is_enabled = 1 );"
done
echo "No scripts"
}
upto2012_3 () #17
{
echo "Starting 2012.3 upgrade"

dbinfo `adminsites $1`|while read db user password
do
	mysql -u $user --password=$password $db -e "SET storage_engine=InnoDB;
UPDATE ezsite_data SET value='4.7.0beta1' WHERE name='ezpublish-version';
UPDATE ezsite_data SET value='1' WHERE name='ezpublish-release';
ALTER TABLE ezcontentobject_attribute MODIFY COLUMN data_float double DEFAULT NULL;
ALTER TABLE ezcontentclass_attribute MODIFY COLUMN data_float1 double DEFAULT NULL;
ALTER TABLE ezcontentclass_attribute MODIFY COLUMN data_float2 double DEFAULT NULL;
ALTER TABLE ezcontentclass_attribute MODIFY COLUMN data_float3 double DEFAULT NULL;
ALTER TABLE ezcontentclass_attribute MODIFY COLUMN data_float4 double DEFAULT NULL;"
done
echo "No scripts"
}
upto2012_4 () #18
{
echo "Starting 2012.4 upgrade"

dbinfo `adminsites $1`|while read db user password
do
	mysql -u $user --password=$password $db -e "SET storage_engine=InnoDB;
UPDATE ezsite_data SET value='4.7.0rc1' WHERE name='ezpublish-version';
UPDATE ezsite_data SET value='1' WHERE name='ezpublish-release';
UPDATE eztrigger SET name = 'pre_updatemainassignment', function_name = 'updatemainassignment' WHERE name = 'pre_UpdateMainAssignment' AND function_name = 'UpdateMainAssignment';"
#Only for cluster machines
#ALTER TABLE `ezdfsfile` CHANGE `datatype` `datatype` VARCHAR(255); ALTER TABLE `ezdbfile` CHANGE `datatype` `datatype` VARCHAR(255);"
done
echo "No scripts"
}
upto2012_6 () #19
{
echo "Starting 2012.6 upgrade"

dbinfo `adminsites $1`|while read db user password
do
	mysql -u $user --password=$password $db -e "SET storage_engine=InnoDB;
UPDATE ezsite_data SET value='5.0.0alpha1' WHERE name='ezpublish-version';
UPDATE ezsite_data SET value='1' WHERE name='ezpublish-release';
ALTER TABLE ezcobj_state_group_language ADD COLUMN real_language_id int(11) NOT NULL DEFAULT 0;
UPDATE ezcobj_state_group_language SET real_language_id = language_id & ~1;
-- ALTER TABLE ezcobj_state_group_language DROP PRIMARY KEY, ADD PRIMARY KEY(contentobject_state_group_id, real_language_id);"
done
echo "Starting scripts"
for siteaccess in `adminsites $1`
do
	echo "Removing duplicate content state group language"
	php update/common/scripts/5.0/deduplicatecontentstategrouplanguage.php --allow-root-user -s $siteaccess
done
}
upto2012_8 () #20
{
echo "Starting 2012.8 upgrade"
echo "Starting scripts"
for siteaccess in `adminsites $1`
do
	echo "Restoring xml relations"
	php update/common/scripts/5.0/restorexmlrelations.php -s $siteaccess
done
}
upto2012_9 () #21
{
echo "Starting 2012.9 upgrade"

dbinfo `adminsites $1`|while read db user password
do
	mysql -u $user --password=$password $db -e "ALTER TABLE ezuser ADD INDEX ezuser_login (login); DELETE FROM ezcontentobject_link WHERE relation_type = 8 AND contentclassattribute_id = 0; UPDATE ezcontentobject_link SET relation_type = 2 WHERE relation_type = 10 AND contentclassattribute_id = 0;"
done
echo "Starting scripts"
for siteaccess in `adminsites $1`
do
	echo "Removing duplicate content state group language"
	php update/common/scripts/5.0/disablesuspicioususers.php -s --allow-root-user -s $siteaccess
done
}

upto2012_11 () #22
{
echo "Starting 2012.11 upgrade"

dbinfo `adminsites $1`|while read db user password
do
	mysql -u $user --password=$password $db -e "SET storage_engine=InnoDB;ALTER TABLE eznode_assignment CHANGE remote_id remote_id VARCHAR(100);UPDATE ezsite_data SET value='5.1.0alpha1' WHERE name='ezpublish-version';UPDATE ezsite_data SET value='1' WHERE name='ezpublish-release';"
done
echo "No scripts"
}
upto2013_1 () #23
{
echo "Starting 2013.1 upgrade"
dbinfo `adminsites $1`|while read db user password
do
cat <<-EOF|mysql -u $user --password=$password $db
ALTER TABLE ezcontentclass ADD INDEX ezcontentclass_identifier (identifier, version);
ALTER TABLE ezcontentobject_tree ADD INDEX ezcontentobject_tree_remote_id (remote_id);
ALTER TABLE ezcontentobject_version ADD INDEX ezcontobj_version_obj_status (contentobject_id, STATUS);
ALTER TABLE ezpolicy ADD INDEX ezpolicy_role_id (role_id);
ALTER TABLE ezpolicy_limitation_value ADD INDEX ezpolicy_limit_value_limit_id (limitation_id);
ALTER TABLE ezcontentobject_attribute
    DROP INDEX ezcontentobject_attribute_contentobject_id,
    DROP INDEX ezcontentobject_attr_id;
ALTER TABLE ezcontentobject_name DROP INDEX ezcontentobject_name_co_id;
ALTER TABLE ezenumobjectvalue DROP INDEX ezenumobjectvalue_co_attr_id_co_attr_ver;
ALTER TABLE ezkeyword DROP INDEX ezkeyword_keyword_id;
ALTER TABLE ezkeyword_attribute_link DROP INDEX ezkeyword_attr_link_keyword_id;
ALTER TABLE eznode_assignment DROP INDEX eznode_assignment_co_id;
ALTER TABLE ezprest_clients DROP INDEX client_id;

ALTER TABLE ezurlalias_ml
    DROP INDEX ezurlalias_ml_actt,
-- Combining "ezurlalias_ml_par_txt" and "ezurlalias_ml_par_lnk_txt" by moving "link" after "text(32)" in the latter:
    DROP INDEX ezurlalias_ml_par_txt,
    DROP INDEX ezurlalias_ml_par_lnk_txt,
    ADD INDEX ezurlalias_ml_par_lnk_txt (parent, text(32), link),

-- Combining "ezurlalias_ml_action" and "ezurlalias_ml_par_act_id_lnk" by moving "parent" after "link" in the latter:
    DROP INDEX ezurlalias_ml_action,
    DROP INDEX ezurlalias_ml_par_act_id_lnk,
    ADD INDEX ezurlalias_ml_par_act_id_lnk (action(32), id, link, parent);

-- See https://jira.ez.no/browse/EZP-20239
DELETE FROM ezcontentobject_link WHERE op_code <> 0;
DELETE FROM ezcontentobject_link WHERE relation_type = 0;
ALTER TABLE ezcontentobject_link DROP COLUMN op_code;
EOF
done
echo "No scripts"
}
upto2013_4 () #24
{
echo "Starting 2013.4 upgrade"

dbinfo `adminsites $1`|while read db user password
do
	mysql -u $user --password=$password $db -e "UPDATE ezcobj_state_group_language SET real_language_id = language_id & ~1;"
done
echo "No scripts"
}
upto2013_5 () #25
{
echo "Starting 2013.5 upgrade"

dbinfo `adminsites $1`|while read db user password
do
	mysql -u $user --password=$password $db -e "ALTER TABLE eznode_assignment CHANGE COLUMN remote_id remote_id varchar(100) NOT NULL DEFAULT '0';"
done
echo "No scripts"
}
check ()
{
echo in check
echo `adminsites $1`
dbinfo `adminsites $1`|while read db user password
do
	echo $db $user $password
done
}
upto2013_5 () #25
{
echo "Starting 2013.5 upgrade"

dbinfo `adminsites $1`|while read db user password
do
	mysql -u $user --password=$password $db -e "ALTER TABLE eznode_assignment CHANGE COLUMN remote_id remote_id varchar(100) NOT NULL DEFAULT '0';"
done
echo "No scripts"
}
check ()
{
echo in check
echo `adminsites $1`
dbinfo `adminsites $1`|while read db user password
do
	echo $db $user $password
done
}
upto2013_9 () #26
{
echo "Starting 2013.9 upgrade"
dbinfo `adminsites $1`|while read db user password
do
cat <<-EOF|mysql -u $user --password=$password $db
ALTER TABLE ezcontent_language
    MODIFY id BIGINT NOT NULL DEFAULT '0';
 
ALTER TABLE ezcontentclass
    MODIFY initial_language_id BIGINT NOT NULL DEFAULT '0',
    MODIFY language_mask BIGINT NOT NULL DEFAULT '0';
 
ALTER TABLE ezcontentclass_name
    MODIFY language_id BIGINT NOT NULL DEFAULT '0';
 
ALTER TABLE ezcontentobject
    MODIFY initial_language_id BIGINT NOT NULL DEFAULT '0',
    MODIFY language_mask BIGINT NOT NULL DEFAULT '0';
 
ALTER TABLE ezcontentobject_name
    MODIFY language_id BIGINT NOT NULL DEFAULT '0';
 
ALTER TABLE ezcontentobject_attribute
    MODIFY language_id BIGINT NOT NULL DEFAULT '0';
 
ALTER TABLE ezcontentobject_version
    MODIFY initial_language_id BIGINT NOT NULL DEFAULT '0',
    MODIFY language_mask BIGINT NOT NULL DEFAULT '0';
 
ALTER TABLE ezcobj_state
    MODIFY default_language_id BIGINT NOT NULL DEFAULT '0',
    MODIFY language_mask BIGINT NOT NULL DEFAULT '0';
 
ALTER TABLE ezcobj_state_group
    MODIFY default_language_id BIGINT NOT NULL DEFAULT '0',
    MODIFY language_mask BIGINT NOT NULL DEFAULT '0';
 
ALTER TABLE ezcobj_state_group_language
    MODIFY language_id BIGINT NOT NULL DEFAULT '0',
    MODIFY real_language_id BIGINT NOT NULL DEFAULT '0';
 
ALTER TABLE ezcobj_state_language
    MODIFY language_id BIGINT NOT NULL DEFAULT '0';
 
ALTER TABLE ezurlalias_ml
    MODIFY lang_mask BIGINT NOT NULL DEFAULT '0';
 
-- Start ezp-21465 : Cleanup extra lines in the ezurl_object_link table
DROP TEMPORARY TABLE IF EXISTS ezurl_object_link_temp ;
 
-- create a temporary table containing stale links
CREATE TEMPORARY TABLE ezurl_object_link_temp
SELECT DISTINCT contentobject_attribute_id, contentobject_attribute_version, url_id
FROM ezurl_object_link AS T1 JOIN ezcontentobject_attribute ON T1.contentobject_attribute_id = ezcontentobject_attribute.id
WHERE ezcontentobject_attribute.data_type_string = "ezurl"
AND T1.url_id < ANY
  (SELECT DISTINCT T2.url_id
  FROM ezurl_object_link T2
  WHERE T1.url_id < T2.url_id
  AND T1.contentobject_attribute_id = T2.contentobject_attribute_id
  AND T1.contentobject_attribute_version = T2.contentobject_attribute_version);
 
SET @OLD_SQL_SAFE_UPDATES=@@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES=0;
 
DELETE ezurl_object_link.*
FROM ezurl_object_link JOIN ezurl_object_link_temp ON ezurl_object_link.url_id = ezurl_object_link_temp.url_id
AND ezurl_object_link.contentobject_attribute_id = ezurl_object_link_temp.contentobject_attribute_id
AND ezurl_object_link.contentobject_attribute_version = ezurl_object_link_temp.contentobject_attribute_version;
 
SET SQL_SAFE_UPDATES=@OLD_SQL_SAFE_UPDATES;
-- End ezp-21465
 
-- Start EZP-21469
-- While using the public API, ezcontentobject.language_mask was not updated correctly,
-- the UPDATE statement below fixes that based on the language_mask of the current version.
UPDATE
    ezcontentobject AS o
INNER JOIN
    ezcontentobject_version AS v ON o.id = v.contentobject_id AND o.current_version = v.version
SET
    o.language_mask = (o.language_mask & 1) | (v.language_mask & ~1);
-- End EZP-21469
 
-- Start EZP-21648:
-- Adding 'priority' and 'is_hidden' columns to the 'eznode_assignment' table
ALTER TABLE eznode_assignment ADD COLUMN priority int(11) NOT NULL DEFAULT '0';
ALTER TABLE eznode_assignment ADD COLUMN is_hidden int(11) NOT NULL DEFAULT '0';
-- End EZP-21648

-- IF DFS CLUSTER ADD THESE LINES TOO
-- CREATE TABLE ezdfsfile_cache (
--   name text NOT NULL,
--   name_trunk text NOT NULL,
--   name_hash varchar(34) NOT NULL DEFAULT '',
--   datatype varchar(255) NOT NULL DEFAULT 'application/octet-stream',
--   scope varchar(25) NOT NULL DEFAULT '',
--   size bigint(20) UNSIGNED NOT NULL DEFAULT '0',
--   mtime int(11) NOT NULL DEFAULT '0',
--   expired tinyint(1) NOT NULL DEFAULT '0',
--   PRIMARY KEY (name_hash),
--   KEY ezdfsfile_name (name(250)),
--   KEY ezdfsfile_name_trunk (name_trunk(250)),
--   KEY ezdfsfile_mtime (mtime),
--   KEY ezdfsfile_expired_name (expired,name(250))
-- ) ENGINE=InnoDB;
EOF
done
echo "No scripts"
}

upto2013_11 () #27
{
echo "Starting 2013.11 upgrade"
dbinfo `adminsites $1`|while read db user password
do
cat <<-EOF|mysql -u $user --password=$password $db
DROP INDEX ezimagefile_co_attr_id_filepath ON ezimagefile;
-- The following was already done in the previous upgrade
-- Start EZP-21648:
-- Adding 'priority' and 'is_hidden' columns to the 'eznode_assignment' table
-- ALTER TABLE eznode_assignment ADD COLUMN priority int(11) NOT NULL DEFAULT '0';
-- ALTER TABLE eznode_assignment ADD COLUMN is_hidden int(11) NOT NULL DEFAULT '0';
-- End EZP-21648
SET storage_engine=InnoDB;
UPDATE ezsite_data SET value='5.3.0alpha1' WHERE name='ezpublish-version';
 
ALTER TABLE ezcontentobject_attribute
    ADD KEY ezcontentobject_classattr_id (contentclassattribute_id);
EOF
done
echo "No scripts"
}

check ()
{
echo in check
echo `adminsites $1`
dbinfo `adminsites $1`|while read db user password
do
	echo $db $user $password
done
}

########
#      #
# MAIN #
#      #
########
siteAccess=$1
if [ $# -gt 1 ]
then
	shift
fi
dbinfo `adminsites $siteAccess`
echo Database Version: `dbversion $siteAccess`
echo File System Version: `version $siteAccess`
case $1 in
	0)  check   $siteAccess;;
	1)  upto352 $siteAccess;;
	2)  upto36  $siteAccess;;
	3)  upto38  $siteAccess;;
	4)  upto39  $siteAccess;;
	5)  upto310 $siteAccess;;
	6)  upto400 $siteAccess;;
	7)  upto401 $siteAccess;;
	8)  upto403 $siteAccess;;
	9)  upto410 $siteAccess;;
	10) upto420 $siteAccess;;
	11) upto430 $siteAccess;;
	12) upto440 $siteAccess;;
	13) upto450 $siteAccess;;
	14) upto2011_5 $siteAccess;;
	15) upto2011_9 $siteAccess;;
	16) upto2012_2 $siteAccess;;
	17) upto2012_3 $siteAccess;;
	18) upto2012_4 $siteAccess;;
	19) upto2012_6 $siteAccess;;
	20) upto2012_8 $siteAccess;;
	21) upto2012_9 $siteAccess;;
	22) upto2012_11 $siteAccess;;
	23) upto2013_1 $siteAccess;;
	24) upto2013_4 $siteAccess;;
	25) upto2013_5 $siteAccess;;
	26) upto2013_9 $siteAccess;;
	27) upto2013_11 $siteAccess;;
	*) cat <<EOF
input needed:
	0  check $siteAccess
	1  upto352 you should be in the 3.6 (or greater) directory
	2  upto36  you should be in the 3.6 (or greater) directory
	3  upto38  you should be in the 3.8 (or greater) directory
	4  upto39  you should be in the 3.9 (or greater) directory
	5  upto310 you should be in the 3.10 (or greater) directory
	6  upto400 you should be in the 4.0 (or greater) directory
	7  upto401 you should be in the 4.x (or greater) directory
	8  upto403 you should be in the 4.x (or greater) directory
	9  upto410 you should be in the 4.x (or greater) directory
	10 upto420 you should be in the 4.x (or greater) directory
	11 upto430 you should be in the 4.3 (or greater) directory
	12 upto440 you should be in the 4.4 (or greater) directory
	13 upto450 you should be in the 4.5 (or greater) directory
	14 upto2011.5 you should be in the 4.5 (or greater) directory
	15 upto2011.9 you should be in the 4.6 (or greater) directory
	16 upto2012.2 you should be in the 4.6 (or greater) directory
	17 upto2012.3 you should be in the 4.6 (or greater) directory
	18 upto2012.4 you should be in the 4.6 (or greater) directory
	19 upto2012.6 you should be in the 2012.6 (or greater) directory
	20 upto2012.8 you should be in the 2012.8 (or greater) directory
	21 upto2012.9 you should be in the 2012.9 (or greater) directory
	22 upto2012.11 you should be in the 2012.11 (or greater) directory
	23 upto2013.1 you should be in the 2013.1 (or greater) directory
	24 upto2013.4 you should be in the 2013.4 (or greater) directory
	25 upto2013.5 you should be in the 2013.5 (or greater) directory
	26 upto2013.9 you should be in the 2013.9 (or greater) directory
	27 upto2013.11 you should be in the 2013.11 (or greater) directory
Missing releases had no database/script changes
EOF
	   ;;
esac
