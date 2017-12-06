N= LuaLDAP
T= lualdap
V= 1.2.3
CONFIG= ./config

include $(CONFIG)

ifneq ($(filter check,$(MAKECMDGOALS)),)
include tests/test.env
LDAP_VARS=LDAP_URI LDAP_BASE_DN LDAP_BIND_DN LDAP_BIND_PASSWORD LDAP_TEST_DN LDAP_TEST_PASSWORD
$(foreach var,$(LDAP_VARS),$(if $(value $(var)),$(info $(var): $(value $(var))),$(error $(var) required when running tests)))
LDAP_HOST= $(shell echo "$(LDAP_URI)" | sed -r 's,^.*://([^:/]+).*$$,\1,')
endif

ifdef BUILD_VARIANT
REPORT_DIR := test-reports/$(BUILD_VARIANT)
else
REPORT_DIR := test-reports
endif

ifdef COVERAGE
override CFLAGS := $(CFLAGS) -O0 -g --coverage
override BUSTEDFLAGS := $(BUSTEDFLAGS) --coverage
endif

ifdef JUNITXML
override BUSTEDFLAGS := $(BUSTEDFLAGS) --output=junit -Xoutput $(REPORT_DIR)/report.xml
endif

override CPPFLAGS := -D_XOPEN_SOURCE=600 -DPACKAGE_STRING="\"$(N) $(V)\"" -DLUA_C89_NUMBERS -I$(LUA_INCDIR) -I$(LDAP_INCDIR) -I$(LBER_INCDIR) -I$(COMPAT_DIR) $(CPPFLAGS)

ifeq ($(LUA_VERSION),5.0)
COMPAT_O= $(COMPAT_DIR)/compat-5.1.o
endif

OBJS= src/lualdap.o $(COMPAT_O)

LIBNAME=$(T).so

src/$(LIBNAME): $(OBJS)
	$(CC) $(CFLAGS) $(LIBFLAG) -o src/$(LIBNAME) $(OBJS) -L$(LDAP_LIBDIR) $(LDAP_LIB) -L$(LBER_LIBDIR) $(LBER_LIB) -lm

install: src/$(LIBNAME)
	$(INSTALL) src/$(LIBNAME) $(DESTDIR)$(INST_LIBDIR)

clean:
	$(RM) -r $(OBJS) src/$(LIBNAME) src/*.gcda src/*.gcno src/*.gcov luacov.*.out $(REPORT_DIR)

check: $(REPORT_DIR)
	env $(foreach var,$(LDAP_VARS) LDAP_HOST,$(var)=$($(var))) busted $(BUSTEDFLAGS) tests/test.lua
ifdef COVERAGE
	luacov
	mv luacov.*.out $(REPORT_DIR)
endif

$(REPORT_DIR):
	mkdir -p $@
