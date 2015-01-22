-- External files extension for PostgreSQL
-- Author Dominique Legendre
-- Copyright (c) 2012-2015 Brgm - All rights reserved.

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION external_file" to load this file. \quit


CREATE TABLE directories (
	directory_name name NOT NULL PRIMARY KEY,
	directory_path text NOT NULL
);

REVOKE ALL ON directories FROM PUBLIC;
GRANT SELECT ON directories TO PUBLIC;

CREATE TABLE directory_roles (
	directory_name name REFERENCES directories(directory_name) ON DELETE CASCADE ON UPDATE CASCADE,
	directory_role name,
	directory_read boolean NOT NULL,
	directory_write boolean NOT NULL,
	PRIMARY KEY (directory_name,directory_role)
);

REVOKE ALL ON directory_roles FROM PUBLIC;
GRANT SELECT ON directory_roles TO PUBLIC;

-- Include tables into pg_dump
SELECT pg_catalog.pg_extension_config_dump('directories', '');
SELECT pg_catalog.pg_extension_config_dump('directory_roles', '');


CREATE TYPE efile AS (
	directory name,
	filename varchar(256)
);

REVOKE ALL ON TYPE efile FROM PUBLIC;
GRANT USAGE ON TYPE efile TO PUBLIC;


CREATE OR REPLACE FUNCTION getEfilePath(e_file efile, need_read boolean, need_write boolean)
  RETURNS text
AS $$
DECLARE
  p_path text;
  r record;
  read_enable boolean := false;
  write_enable boolean := false;
BEGIN
  IF coalesce(e_file.filename,'')='' THEN
    RAISE EXCEPTION 'Filename is empty.';
  END IF;
  IF e_file.filename ~ '(\\|/)' THEN
	RAISE EXCEPTION '/ or \ are forbiden inside filename';
  END IF;
  SELECT directory_path INTO p_path FROM directories WHERE directory_name= e_file.directory;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Directory % don''t exist.',e_file.directory;
  END IF;
  FOR r IN 
    (SELECT directory_role,directory_read,directory_write FROM directory_roles WHERE directory_name= e_file.directory) LOOP
	IF pg_has_role(session_user,r.directory_role,'USAGE') THEN
		IF r.directory_read THEN
			read_enable := true;
		END IF;
		IF r.directory_write THEN
			write_enable := true;
		END IF;
	END IF;
  END LOOP;
  IF (need_read AND NOT read_enable) OR (need_write AND NOT write_enable) THEN
    RAISE EXCEPTION 'Missing right for this directory: %' ,e_file.directory;
  END IF;  
  p_path := p_path|| e_file.filename;
  RETURN p_path;
END;
$$
LANGUAGE PLPGSQL STABLE SECURITY DEFINER SET search_path = @extschema@, pg_temp;


CREATE OR REPLACE FUNCTION writeEfile(buffer bytea, e_file efile)
  RETURNS void
AS $$
DECLARE
  l_oid oid;
  lfd integer;
  lsize integer;
BEGIN
  l_oid := lo_create(0);
  lfd := lo_open(l_oid,131072); --0x00020000 write mode
  lsize := lowrite(lfd,buffer);
  PERFORM lo_close(lfd);
  PERFORM lo_export(l_oid,getEfilePath(e_file,false,true));
  PERFORM lo_unlink(l_oid);
END;
$$ LANGUAGE PLPGSQL SECURITY DEFINER SET search_path = @extschema@, pg_temp;


CREATE OR REPLACE FUNCTION readEfile(e_file efile, p_result OUT bytea)
AS $$
DECLARE
  l_oid oid;
  r record;
BEGIN
  p_result := '';
  SELECT lo_import(getEfilePath(e_file,true,false)) INTO l_oid;
  FOR r IN ( SELECT data 
             FROM pg_largeobject 
             WHERE loid = l_oid 
             ORDER BY pageno ) LOOP
    p_result = p_result || r.data;
  END LOOP;
  PERFORM lo_unlink(l_oid);
END;
$$
LANGUAGE PLPGSQL SECURITY DEFINER SET search_path = @extschema@, pg_temp;


CREATE OR REPLACE FUNCTION copyEfile(src efile, dest efile)
  RETURNS void
AS $$
DECLARE
  l_oid oid;
BEGIN
  SELECT lo_import(getEfilePath(src,true,false)) INTO l_oid;
  PERFORM lo_export(l_oid,getEfilePath(dest,false,true));
  PERFORM lo_unlink(l_oid);
END;
$$
LANGUAGE PLPGSQL SECURITY DEFINER SET search_path = @extschema@, pg_temp;

CREATE OR REPLACE FUNCTION efile_check_role()
  RETURNS trigger
AS $$
BEGIN
  PERFORM *  from pg_roles where rolname = NEW.directory_role;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'role % must exists', NEW.directory_role;
    RETURN NULL;
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE PLPGSQL;

CREATE TRIGGER trg_efile_check_role
    BEFORE UPDATE OR INSERT ON directory_roles
    FOR EACH ROW
    EXECUTE PROCEDURE efile_check_role();


