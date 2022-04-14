use Test::Simple tests => 17;

if ($ENV{USER} ne 'postgres') {
	die "\nFATAL: Test must be run as postgres user\n";
}

# Cleanup garbage from previous regression test runs
`rm -rf /tmp/external_files 2>/dev/null`;

# First drop the test database and create the users
`psql -c "DROP DATABASE IF EXISTS regress_efile" 1>/dev/null`;
`psql -c "DROP ROLE regress_efile_user" 2>/dev/null`;
`psql -c "DROP ROLE regress_efile_dba" 2>/dev/null`;
`psql -c "CREATE ROLE regress_efile_user LOGIN" 2>/dev/null`;
# PostgreSQL >= 11
`psql -c "CREATE ROLE regress_efile_dba LOGIN" 2>/dev/null`;
`psql -c "GRANT pg_read_server_files,pg_write_server_files TO regress_efile_dba" 2>/dev/null`;
# else
# `psql -c "CREATE ROLE regress_efile_dba LOGIN SUPERUSER" 2>/dev/null`;

# Create the test database
$ret = `psql -c "CREATE DATABASE regress_efile OWNER regress_efile_dba"`;
ok( $? == 0, "Create test regression database: regress_efile");

# Create the schema and objects of the extension
my $ver = `grep default_version external_file.control | sed -E "s/.*'(.*)'/\\1/"`;
chomp($ver);
$ret = `grep -v "\\\\echo" external_file--$ver.sql | sed 's/\@extschema\@/public/' | psql -d regress_efile > /dev/null 2>&1`;
ok( $? == 0, "Import external_file schema");

# Initialize the database
$ret = `psql -d regress_efile -f test/init_test.sql > /dev/null 2>&1`;
ok( $? == 0, "Import external_file schema");

# Create the temporary directory where external files will be stored
`mkdir /tmp/external_files`;
# Copy a file into this directory
`cp -f test/image.png /tmp/external_files/`;

# Regisgter an external file
$ret = `psql -d regress_efile -U regress_efile_user -c "INSERT INTO efile_table VALUES (1, EFILENAME('test_dir', 'image1.png'))"`;
ok( $? == 0, "Insert an efile");
# Update an efile
$ret = `psql -d regress_efile -U regress_efile_user -c "UPDATE efile_table SET f_lob = ('test_dir', 'image.png')::efile WHERE id = 1"`;
ok( $? == 0, "Update an efile");

# Make a physical copy of the external file.
# It must fail, the user has right to read but not to write
$ret = `psql -d regress_efile -U regress_efile_user -c "SELECT copyefile(('test_dir','image.png')::efile,('test_dir','copy_image.png')::efile)" 2>/dev/null`;
ok( $? != 0, "physical copy failure");

# It must succeed, the user has right to read AND to write
$ret = `psql -d regress_efile -U regress_efile_dba -c "SELECT copyefile(('test_dir','image.png')::efile,('test_dir','copy_image.png')::efile)"`;
ok( $? == 0, "physical copy success");

$ret = `ls /tmp/external_files/*image.png | wc -l`;
chomp($ret);
ok( $ret == 2, "count physical copy");

# Regisgter the copy
$ret = `psql -d regress_efile -U regress_efile_user -c "INSERT INTO efile_table VALUES (2, EFILENAME('test_dir', 'copy_image.png'))"`;
ok( $? == 0, "Insert the efile copy");

# Read content of the external file
my @ret = `psql -d regress_efile -U regress_efile_dba -c "SELECT id, readefile(f_lob) FROM efile_table ORDER BY id"`;
ok( $? == 0, "read content of the external file");

# Get full path to an efile
$ret = `psql -d regress_efile -U regress_efile_user -c "SELECT id, getEfilePath(f_lob, true, true) FROM efile_table WHERE id=2" 2>/dev/null`;
ok( $? != 0, "Full path for the external file, failure");

$ret = `psql -d regress_efile -U regress_efile_dba -Atc "SELECT getEfilePath(f_lob, true, true) FROM efile_table WHERE id=2"`;
chomp($ret);
ok( $? == 0 && $ret eq '/tmp/external_files/copy_image.png', "Full path for the external file, success");

$ret = `psql -d regress_efile -U regress_efile_user -Atc "SELECT getEfilePath(f_lob, true, false) FROM efile_table WHERE id=2"`;
chomp($ret);
ok( $? == 0 && $ret eq '/tmp/external_files/copy_image.png' , "Full path for the external file, no write success");

# Copy content of an external file using read/write functions
$ret = `psql -d regress_efile -U regress_efile_dba -c "SELECT writeEfile(readefile(f_lob), ('test_dir', 'image2.png')) FROM efile_table WHERE id=2;"`;
ok( $? == 0, "Copy external file using read/write functions");

# Verify that the file exists
$ret = `ls /tmp/external_files/image2.png | wc -l`;
chomp($ret);
ok( $ret == 1, "Copied external file exists");

# Regisgter the copy
$ret = `psql -d regress_efile -U regress_efile_user -c "INSERT INTO efile_table VALUES (3, EFILENAME('test_dir', 'image2.png'))"`;
ok( $? == 0, "Register the efile copied using read/write functions");

# Verify that the external files data are the same
$ret = `ls -la /tmp/external_files/*.png | grep -v " 8408 " | wc -l`;
chomp($ret);
ok( $ret == 0, "All external files have 8408 size");
