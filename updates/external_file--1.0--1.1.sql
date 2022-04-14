-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTER EXTENSION external_file UPDATE TO \"1.1\";" to load this file. \quit


-- Function used to replace Oracle BFILENAME that returns efile
CREATE OR REPLACE FUNCTION efilename(directory name, filename varchar(256)) RETURNS efile
AS 'SELECT ($1, $2)::efile;'
LANGUAGE SQL STRICT;

