CREATE TABLE efile_table (
   id integer not null,
   f_lob efile
);
GRANT ALL ON efile_table TO regress_efile_user;
GRANT ALL ON efile_table TO regress_efile_dba;

-- Oracle: CREATE DIRECTORY test_dir AS '/tmp/external_files/';
INSERT INTO directories(directory_name,directory_path)
	VALUES ('test_dir','/tmp/external_files/');
INSERT INTO directory_roles(directory_name,directory_role,directory_read,directory_write)
	VALUES ('test_dir','regress_efile_user',true,false);
INSERT INTO directory_roles(directory_name,directory_role,directory_read,directory_write)
	VALUES ('test_dir','regress_efile_dba',true,true);

GRANT SELECT ON directories TO regress_efile_dba;
GRANT SELECT ON directories TO regress_efile_user;
