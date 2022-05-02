EXTENSION = external_file
EXTVERSION = $(shell grep default_version $(EXTENSION).control | \
                sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")

PGFILEDESC = "external_file - Propose Oracle BFILE compatibility for PostgreSQL"

PG_CONFIG = pg_config
PG91 = $(shell $(PG_CONFIG) --version | egrep " 8\.| 9\.0" > /dev/null && echo no || echo yes)

ifeq ($(PG91),yes)
DATA = $(wildcard updates/*--*.sql) $(EXTENSION)--$(EXTVERSION).sql
DOCS = README.external_file
SCRIPTS =
MODULES =
else
$(error Minimum version of PostgreSQL required is 9.1.0)
endif

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

all: prepare_readme

prepare_readme: README.md
	@echo "Prepare README.external_file"
	cp README.md README.external_file

clean:
	rm -f README.external_file
