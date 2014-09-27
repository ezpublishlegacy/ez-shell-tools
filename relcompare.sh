# compares directories using diff - ignores .svn dirs and white space changes

#cmd=`basename $0`

printerr ()
{
echo $1
cat <<EOF
USAGE $cmd: [-v] <dir1> <dir2>
	$cmd compares files in directories using diff
	ignores .svn/.git dirs, white space and comments
	-v is for verbose - everything is listed
	-m shows all the missing files
	-m1 only shows the missing files in dir1
	-m2 only shows the missing files in dir2
	-l  only lists the file names.  
EOF
exit 1
}

########
# MAIN #
########

if [ $# -lt 2 ]
then 
     printerr
else     
     eval secondlast='$'\{$((${#}-1))\}
     eval last='$'${#}
     #ensures dir will have one trailing slash
     dir1=${secondlast%/}/
     dir2=${last%/}/
     for opt
     do
     case $opt in
          "-v")    allflag="TRUE";;
          "-m")    missingflag="TRUE";;
          "-m1")   missoneflag="TRUE";;
          "-m2")   misstwoflag="TRUE";;
          "-l")    listflag="TRUE";;
          "$last"|"$secondlast")   dirs=$(($dirs+1));;
          *)        echo "$opt not an option - ignoring";;
     esac
     done
fi
if [ "$dirs" -ne 2 -o ! -d "$last" -o ! -d "$secondlast" ]
then
	printerr "ERROR: bad dir"
fi
#compare 1 2
find "$dir1" ! -wholename "*/\.svn/*" ! -wholename "*/\.git/*" -type f|egrep -v "\.md5$|~$"|
while read dir1file
do
        dir2file=${dir2}${dir1file##$dir1}
        if [ ! -f "$dir2file" ]
        then
		if [ "$allflag" = "TRUE" -o "$misstwoflag" = "TRUE" -o "$missingflag" = "TRUE" ]
		then
                	echo "$dir1file DOES NOT EXIST IN SECOND DIRECTORY"
		fi
        else
                if [ `diff -w -b -q  --ignore-matching-lines="^[ 	]\{0,\}//" --ignore-matching-lines="^[ 	]\{0,\}\* @" --ignore-matching-lines="^[ 	]\{0,\}/\*\*" "$dir1file" "$dir2file"|grep -c differ` -eq 1 ]
                then
                        echo $dir1file $dir2file ARE NOT THE SAME.
if [ "$listflag" != "TRUE" ]
then
                        #diff --suppress-common-lines -b --ignore-matching-lines="^//" "$dir1file" "$dir2file"
                        diff --suppress-common-lines -b --ignore-matching-lines="^[ 	]\{0,\}//" --ignore-matching-lines="^[ 	]\{0,\}\* @" --ignore-matching-lines="^[ 	]\{0,\}/\*\*" "$dir1file" "$dir2file"
fi
		else
			if [ "$allflag" = "TRUE" ]
			then
                        	echo $dir1file $dir2file ARE THE SAME.
			fi
                fi
        fi
done
#compare 2 1
#Handled above
#if [ "$allflag" = "TRUE" -o "$misstwoflag" = "TRUE" -o "$missingflag" = "TRUE" ]
#then
#find "$dir1" ! -wholename "*/\.svn/*" ! -wholename "*/\.git/*" -type f|while read dir1file
#do
        #dir2file=${dir2}${dir1file##$dir1}
	##diff was done above just have to check if it exists
        #if [ ! -f "$dir2file" ]
        #then
		##if [ "$allflag" = "TRUE" ]
		##then
                	#echo "$dir1file DOES NOT EXIST IN SECOND DIRECTORY"
		##fi
        #fi
#done
#fi
if [ "$allflag" = "TRUE" -o "$missoneflag" = "TRUE" -o "$missingflag" = "TRUE" ]
then
find "$dir2" ! -wholename "*/\.svn/*" ! -wholename "*/\.git/*" -type f|while read dir2file
do
        dir1file=${dir1}${dir2file##$dir2}
	#diff was done above just have to check if it exists
        if [ ! -f "$dir1file" ]
        then
		#if [ "$allflag" = "TRUE" ]
		#then
                	echo "$dir2file DOES NOT EXIST IN FIRST DIRECTORY"
		#fi
        fi
done
fi
