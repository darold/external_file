#MODULES = external_file
EXTENSION = external_file
DATA = external_file--1.0.sql
DOCS = README.external_file

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
