# Solar Designer implementation.
CRYPT_BLOWFISH_DIR = crypt_blowfish
CRYPT_BLOWFISH_LIB = $(CRYPT_BLOWFISH_DIR)/crypt_blowfish.a

# Compiler.
CC = $(shell grep '^CC = ' $(CRYPT_BLOWFISH_DIR)/Makefile | cut -d= -f2-)

# Compiler flags.
EXTRA_CFLAGS = -fPIC -fvisibility=hidden
CFLAGS = $(shell grep '^CFLAGS = ' $(CRYPT_BLOWFISH_DIR)/Makefile | cut -d= -f2-) $(EXTRA_CFLAGS)

# Library variables.
BCRYPT_MAJOR = 1
BCRYPT_MINOR = 0
BCRYPT_PATCH = 0

BCRYPT_PRNAME = bcrypt
BCRYPT_LDNAME = lib$(BCRYPT_PRNAME).so
BCRYPT_SONAME = $(BCRYPT_LDNAME).$(BCRYPT_MAJOR)
BCRYPT_SOFILE = $(BCRYPT_SONAME).$(BCRYPT_MINOR).$(BCRYPT_PATCH)

BCRYPT_MANPAGE = bcrypt.3
BCRYPT_MANPAGE_SOURCE = $(BCRYPT_MANPAGE).txt
BCRYPT_MANPAGE_LINKS = bcrypt_gensalt.3 bcrypt_hashpw.3 bcrypt_checkpw.3

BCRYPT_PCFILE = bcrypt.pc

# Installation variables.

# This is the most common convention. It is used for LIBDIR, which can be
# overridden completely below.
MACHINE = $(shell uname -m)
ifeq ($(MACHINE),x86_64)
    LIBDIRNAME = lib64
else
    LIBDIRNAME = lib
endif

DESTDIR ?=
PREFIX ?= /usr/local
MANDIR ?= $(PREFIX)/share/man
INCLUDEDIR ?= $(PREFIX)/include
LIBDIR ?= $(PREFIX)/$(LIBDIRNAME)

INCLUDESUBDIR = $(INCLUDEDIR)/$(BCRYPT_PRNAME)
MAN3DIR = $(MANDIR)/man3
PKGCONFIGDIR = $(LIBDIR)/pkgconfig

#
# Macros and rules.
#

define make_lib_links
set -e ; \
    ln -sf $(BCRYPT_SOFILE) $(1)/$(BCRYPT_SONAME) ; \
    ln -sf $(BCRYPT_SONAME) $(1)/$(BCRYPT_LDNAME)
endef

define make_man_links
set -e ; \
    for f in $(BCRYPT_MANPAGE_LINKS); do \
        ln -sf $(BCRYPT_MANPAGE) $(1)/$$f ; \
    done
endef

.PHONY: all
all: $(BCRYPT_SOFILE) $(BCRYPT_MANPAGE) $(BCRYPT_PCFILE) bcrypt.h

.PHONY: test
test: bcrypt_test
	@set -e ; \
	    for prog in $^; do \
	        LD_LIBRARY_PATH=.:$$LD_LIBRARY_PATH ./$$prog ; \
	    done

bcrypt_test: bcrypt_test.o $(BCRYPT_LDNAME)
	$(CC) -o $@ $< -L. -l$(BCRYPT_PRNAME)

$(BCRYPT_LDNAME) $(BCRYPT_SONAME): $(BCRYPT_SOFILE)
	$(call make_lib_links,.)

$(BCRYPT_SOFILE): bcrypt.o $(CRYPT_BLOWFISH_LIB)
	$(CC) $(EXTRA_CFLAGS) -shared -Wl,-soname,$(BCRYPT_SONAME) -o $(BCRYPT_SOFILE) bcrypt.o $(CRYPT_BLOWFISH_LIB)

FORCE:

$(CRYPT_BLOWFISH_LIB): FORCE
	@set -e ; \
	    $(MAKE) -q CFLAGS="$(CFLAGS)" -C $(CRYPT_BLOWFISH_DIR) || \
	    ( $(MAKE) CFLAGS="$(CFLAGS)" -C $(CRYPT_BLOWFISH_DIR) && \
	      ar Dr $@ $(CRYPT_BLOWFISH_DIR)/*.o && ranlib -D $@ )

%.o: %.c bcrypt.h
	$(CC) $(CFLAGS) -c $<

$(BCRYPT_MANPAGE): $(BCRYPT_MANPAGE_SOURCE)
	a2x --doctype manpage --format manpage $<

$(BCRYPT_PCFILE):
	@set -e ; \
	    >$@ ; \
	    echo "Name: $(BCRYPT_PRNAME)" >>$@ ; \
	    echo "Description: bcrypt password hash C library" >>$@ ; \
	    echo "Version: $(BCRYPT_MAJOR).$(BCRYPT_MINOR).$(BCRYPT_PATCH)" >>$@ ; \
	    echo "Cflags: -I$(INCLUDESUBDIR)" >>$@ ; \
	    echo "Libs: -L$(LIBDIR) -l$(BCRYPT_PRNAME)" >>$@ ; \
	    :

.PHONY: clean
clean:
	rm -f *.o bcrypt_test $(BCRYPT_SOFILE) $(BCRYPT_SONAME) $(BCRYPT_LDNAME) $(BCRYPT_MANPAGE) $(BCRYPT_PCFILE) *~ core
	$(MAKE) -C $(CRYPT_BLOWFISH_DIR) clean

.PHONY: install
install: all
	install -d $(DESTDIR)$(MAN3DIR)
	install -d $(DESTDIR)$(INCLUDESUBDIR)
	install -d $(DESTDIR)$(LIBDIR)
	install -d $(DESTDIR)$(PKGCONFIGDIR)
	install -m 755 $(BCRYPT_SOFILE) $(DESTDIR)$(LIBDIR)
	install -m 644 bcrypt.h $(DESTDIR)$(INCLUDESUBDIR)
	install -m 644 $(BCRYPT_MANPAGE) $(DESTDIR)$(MAN3DIR)
	install -m 644 $(BCRYPT_PCFILE) $(DESTDIR)$(PKGCONFIGDIR)
	$(call make_lib_links,$(DESTDIR)$(LIBDIR))
	$(call make_man_links,$(DESTDIR)$(MAN3DIR))
