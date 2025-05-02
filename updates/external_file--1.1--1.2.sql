-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTER EXTENSION external_file UPDATE TO \"1.2\";" to load this file. \quit

CREATE OR REPLACE FUNCTION readEfile(e_file efile, p_result OUT bytea)
AS $$
DECLARE
  l_oid oid;
BEGIN
  SELECT lo_import(getEfilePath(e_file,true,false)) INTO l_oid;
  SELECT string_agg (data, NULL::bytea ORDER BY pageno) INTO p_result FROM pg_largeobject WHERE loid = l_oid;
  PERFORM lo_unlink(l_oid);
END;
$$
LANGUAGE PLPGSQL SECURITY DEFINER SET search_path = @extschema@, pg_temp;

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
  IF e_file.filename ~ '\.\.' THEN
        RAISE EXCEPTION 'double point (..) are forbidden inside filename';
  END IF;
  SELECT directory_path INTO p_path FROM directories WHERE directory_name= e_file.directory;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Directory % don''t exist.',e_file.directory;
  END IF;
  FOR r IN
    (SELECT directory_role,directory_read,directory_write FROM directory_roles WHERE directory_name= e_file.directory)
  LOOP
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
  p_path := p_path || e_file.filename;
  RETURN p_path;
END;
$$
LANGUAGE PLPGSQL STABLE SECURITY DEFINER SET search_path = @extschema@, pg_temp;
