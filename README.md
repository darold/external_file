External file access extension
==============================

Allow access to "external files" from PostgreSQL server file systems.

This extension adds the same functionalities given by the Oracle's BFILE data
type that stores unstructured binary data in flat files outside the database.
A BFILE column stores a file locator that points to an external file containing
the data: (DIRECTORY, FILENAME). Here the data type is called EFILE.

The extension access to external files using secure call to the server side `lo_*`
functions and not by directly reading/writing to files.

Installation requirements
-------------------------

PostgreSQL 9.1 or better are required.
User with PostgreSQL superuser role for creating extension.

Installation
------------

external_file has been written as a PostgreSQL extension and uses the Extension
Building Infrastructure "PGXS".

You will need PostgreSQL headers and PGXS installed (if your PostgreSQL was
installed with packages, install the development package).

Get/Unpack the source code in a fresh directory Then the software installation
should be as simple as

	$ make (In these version do nothing)
	$ make install

To install the extension in a database, connect as superuser and

	CREATE EXTENSION external_file;

By default all objects of the extension are created in the `external_file` schema.
If you want to change the schema name you must edit the `external_file.control`
file. Note that this schema must not be writable by normal user to not allow
bypassing of the search path set with the security definer.


When using schema with extension, it's better to include this schema in the
default search path. For example:

	ALTER DATABASE <mydb> SET search_path="$user",public,external_file;

Also you can restrict USAGE grant on `external_file` schema to specific user and
change the default search path at user level too.

	GRANT USAGE ON SCHEMA external_file TO <username>;

Please refer to the PostgreSQL documentation for more information.


Usage
-----

External file are accessed using two values, an alias for the path of the
directory where the file is, and the file name.

So, first, alias must be defined for the path. This definition is performed
using the "directories" table. For security reason, only superuser can insert,
update, delete directory definition. It's possible, with GRANT command, to
change this but it's NOT recommended.

Example:

	INSERT INTO directories(directory_name,directory_path) VALUES ('temporary','/tmp/');

ATTENTION:
 * the directory path must use the terminal file system separator!
 * the system user running PostgreSQL server (generally postgres) must have the
   system rights to read and/or write files. See `pg_read_server_files` and
   `pg_write_server_files` privileges introduced in PostgreSQL 11.
 * the filename don't include any / or \ character for security reason

Second, rights for user and/or role are defined using the "directory_access"
table.

Example:

	INSERT INTO directory_roles(directory_name,directory_role,directory_read,directory_write) VALUES ('temporary','a_role',true,false);

Now standard user can use external files.

Example:

	-- Store a new external file blahblah.txt into the directory
	SELECT writeEfile('\x48656c6c6f2c0a0a596f75206172652072656164696e67206120746578742066696c652e0a0a526567617264732c0a', ('temporary', 'blahblah.txt'));

	ls -la /tmp/blahblah.txt 
	-rw-r--r-- 1 postgres postgres 47 janv. 22 19:16 /tmp/blahblah.txt

	-- Create a table that will use external files
	CREATE TABLE efile_test ( id smallint primary key, the_file efile);
	-- Insert a row to access the external file called blahblah.txt
	INSERT INTO efile_test VALUES (1,('temporary','blahblah.txt'));
	-- Assuming user has right to read, and the file exists
	SELECT id, readefile(the_file) FROM efile_test;
	-- Make a physical copy of the external file assuming user has right to read AND write
	SELECT copyefile(('temporary','blahblah.txt'),('temporary','copy_blahblah.txt'));
	INSERT INTO efile_test VALUES (2, ('temporary','copy_blahblah.txt'):::efile);
	-- or the equivalent using efilename()
	INSERT INTO efile_test VALUES (3, efilename('temporary','copy_blahblah.txt'));

	ls /tmp/*blahblah.txt
	-rw-r--r-- 1 postgres postgres 47 janv. 22 19:16 /tmp/blahblah.txt
	-rw-r--r-- 1 postgres postgres 47 janv. 22 19:24 /tmp/copy_blahblah.txt

	file=# SELECT id, readefile(the_file) FROM efile_test;
	 id |                                            readefile                                             
	----+--------------------------------------------------------------------------------------------------
	  1 | \x48656c6c6f2c0a0a596f75206172652072656164696e67206120746578742066696c652e0a0a526567617264732c0a
	  2 | \x48656c6c6f2c0a0a596f75206172652072656164696e67206120746578742066696c652e0a0a526567617264732c0a
	(2 lines)


Function reference
------------------

* **efilename(directory in name, filename in varchar(256)) returns efile**

  Returns an EFILE data type that is referencing the external file on the server filesystem.
  Returns NULL on null imput.


* **readEfile(e_file in efile) returns bytea**

  copy the external file into a bytea.
  Error will be generated if something wrong.

* **writeEfile(buffer in bytea, e_file in efile) returns void**

  copy a bytea into a external file.
  Error will be generated if something wrong.

* **copyEfile(src in efile, dest in efile) returns void**

  duplicate file defined by src into file dest
  Error will be generated if something wrong.

* **getEfilePath(e_file efile, need_read in boolean, need_write in boolean) returns text**

  giving an efile and booleans, one for read and one for write need, return the
  full path for the file, otherwise an error is generated 
  useful to check if session user has access to this external file

Authors
-------

* Dominique Legendre
* Gilles Darold

License
-------

external_file is free software distributed under the PostgreSQL Licence.

* Copyright (c) 2012-2018 Brgm - All rights reserved.
* Copyright (c) 2022 MigOps Inc - All rights reserved.

Se1e LICENSE file.
