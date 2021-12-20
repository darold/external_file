#MODULES = external_file
EXTENSION = external_file
DATA = external_file--1.0.sql
DOCS = README.external_file

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)


all: prepare_readme

prepare_readme: README.md
	@echo "Prepare README.external_file"
	cp README.md README.external_file

clean:
	rm -f README.external_file
