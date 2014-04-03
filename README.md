GNU General Public License v2.0
NOTICE:
These programs are free software; you can redistribute and/or modify under the
terms of version 2.0  of the GNU General Public License as published by the
Free Software Foundation.

These programs are distributed in the hope that they will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

Created by: Leiden Tech
info@leidentech.com, http://www.leidentech.com
===============================================================================

ABOUT

This is a collection of shell tools (which other people might also find useful)
that we end up using a lot while working on the linux command line on
development machines.

bashrc_add:  This is what I add to my bashrc so it's easier to navigate around
multiple eZPublish sites on one machine.  It allows changing of environments,
cd'ing to the eZPublish root and allows for using $EZ on the command line for
long commands.

BOMfind.sh:
Use this to find files that have been infected with the Byte Order Mark by
windows text editors.

See http://ez.no/developer/forum/setup_design/strange_characters_generated_by_ezpublish
for a longer explanation.

mydbdump.sh:

This shell script will split a mysql database dumping each
table into a seperate file.  used in conjunction with dbsplit
- which will split each database entry to a seperate line,
it is possible to see exactly what has changed in the database
by running:

diff --recursive --suppress-common-lines --side-by-side <dir1> <dir2>

The only argument is a filename which should be a dbdump file with a
.sql extension.  The files will be written to a directory named the
same as the file with the .sql stripped off.  If the file does not have
a .sql extension, then the file will be appended with the process id
of this shell script.

dbsplit.c:
This will split each database entry into a seperate line.  If you've ever
tried finding something in an ezpublish mysql dump you'll have noticed that
you get some million character lines that make it nearly impossible to find
things.

ezsetchk.sh:
This outputs a settings files sorted alphabetically by the [head] line.  By
doing this on two different files, they can be diffed to see any differences.
Which is especially useful for comparing settings of different site accesses
such as override.ini.append.php settings.

WARNING: Not a good idea to REPLACE the settings file with the output however,
because sometimes order matters - on the match nodes for example.

search.sh:
This is a shell wrapper for grep that makes it easier to do recursive searches
on directories.  Use -d to define the directory root(s) or it will default to
$PWD if none is given.  Long options for grep fall through.

I end up using this all of the time - e.g.:

	search.sh -H -d $EZ/lib $EZ/kernel fetchListByClassID|grep function
	Finds the functions called fetchListByClassID in the eZPublish
	directories lib and kernel.

	search.sh -d $EZ/lib $EZ/kernel "[[:blank:]]function [A-z]"
	lists all functions in all files in lib kernel

	search.sh -f -d $EZ/design line.tpl
	Finds files named line.tpl underneath the design directory.

	search.sh --after=10 -d $EZ/settings $EZ/extension/*/settings DatabaseSettings
	quickly find the database settings.

tagout.sh:
Sometimes debugging html problems can be difficult, especially on files that are 1000s of lines long and where tags are all over the place.  This shell will fix the indentation - of an html of template file - to make it easier to read.  Most of the time I run this to find a missing div tag (which is the default).

tplchk.sh: 
This does a check for common tags in template files to find mismatched 
code blocks.  Could return false positives if a tag is closed in a different
template.  Can be run on one file or recursively on a directory.

Generally speaking I run this at the end of developing a site to find template
errors that are not always obvious from the html output but can cause ugly
problems (such as cache-blocks that aren't closed).

INSTALL
=======
Linux

Add this to a directory in your $PATH and make sure that the files are
executable.

Windows
Install cygwin on your machine http://www.cygwin.com and follow the
instructions for Linux.
