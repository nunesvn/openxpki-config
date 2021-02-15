# This makefile is for the WRS OpenXPKI Config package
#
#

############################################################
# Generic Vars
############################################################

# Use bash to support sourcing the local conf file
SHELL = /bin/bash

# This is a local 'shell source' file that may contain local overrides like PKGNAME
LOCAL_CONF_FILE := .customerinfo

# These are the directories and files that will get installed into %{buildroot}/etc/openxpki/
ETC_OXI_SUBDIRS := ca certep config.d contrib est log.conf notification rpc scep soap webui

# TODO: deprecate following to use vergen
VERSION := $(shell head -n 1 VERSION)
ifeq "$(shell test -d .git && echo true)" "true"
GIT_COMMIT_HASH = $(shell git rev-parse HEAD)
GIT_TAGS = $(patsubst refs/tags/%,%,$(shell \
	git show-ref --tags -d|grep ^$(shell git rev-parse HEAD)|awk '{print $$2}'))
else
GIT_COMMIT_HASH = $(shell grep GIT_COMMIT_HASH VERSION.META 2>/dev/null|awk -F= '{print $$2}')
GIT_TAGS = $(shell grep GIT_TAGS VERSION.META 2>/dev/null|awk -F= '{print $$2}')
endif
ifdef BUILD_NUMBER
	RELEASE = $(BUILD_NUMBER)
else
	RELEASE ?= 1
endif

export RELEASE

# Set the PKGNAME and PKGDESC from the local override file, if it exists
# and they are set. Otherwise, default to 'openxpki-config' and
# "OpenXPKI Configuration"
PKGNAME = $(shell test -f $(LOCAL_CONF_FILE) && source $(LOCAL_CONF_FILE); echo $$PKGNAME)
ifeq "$(PKGNAME)" ""
	PKGNAME := openxpki-config
endif
PKGDESC = $(shell test -f $(LOCAL_CONF_FILE) && source $(LOCAL_CONF_FILE); echo $$PKGDESC)
ifeq "$(PKGDESC)" ""
	PKGDESC := OpenXPKI configuration
endif

############################################################
# Debian Variables
############################################################

DEB_PKG			= $(PKGNAME)_$(VERSION)-$(RELEASE)_amd64.deb
DEB_TARBALL  = $(PKGNAME)_$(VERSION).orig.tar.gz
DEB_SRCDIR	= $(PKGNAME)-$(VERSION)


# currently checked-out branch
GIT_BRANCH = $(shell (git symbolic-ref HEAD 2>/dev/null||echo '(unnamed branch)') \
	|perl -pe 's{refs/heads/}{}xms')


.PHONY: all install version

# This 'all' target doesn't do anything because the config shouldn't need
# any processing. Instead, the 'install' target just copies it 
# directly to the destination. Also, it is defined before the '-include's
# so extra targets may be included without effecting the default make target.
all:
	@echo "Nothing to do for 'all'"

-include Makefile.cust
-include Makefile.local

ifndef PRODNAME
	PRODNAME := openxpki
endif


ifndef PACKAGER
	ifndef GIT_AUTHOR_NAME
		GIT_AUTHOR_NAME = $(shell git config --get user.name)
	endif
	ifndef GIT_AUTHOR_EMAIL
		GIT_AUTHOR_EMAIL = $(shell git config --get user.email)
	endif
	PACKAGER := $(GIT_AUTHOR_NAME) <$(GIT_AUTHOR_EMAIL)>
endif

# If the packager hasn't been added to the symbols already,
# go ahead and add it.
ifeq "" "$(filter PACKAGER=%,$(TT_VERSION_SYMBOLS))"
	TT_VERSION_SYMBOLS += --define PACKAGER="$(PACKAGER)"
endif

############################################################
# RULES - Sanity Checks / Assertions
############################################################

# sanity checks for this repository
# 1. check that the code repo is available (via symlink)
# 2. check for required command line tools

check:
	for cmd in tpage ; do \
		if ! $$cmd </dev/null >/dev/null 2>&1 ; then \
			echo "ERROR: executable '$$cmd' does not work properly." ;\
			exit 1 ;\
		fi ;\
	 done

assert-packager:
	@if test -z "$(GIT_AUTHOR_NAME)" || test -z "$(GIT_AUTHOR_EMAIL)"; then \
		echo "ERROR: You must set GIT_AUTHOR_NAME and GIT_AUTHOR_EMAIL" ;\
		exit 1; \
	fi

# auxiliary target, checks if we are currently on ASSERT_BRANCH
assert-branch:
	@if [ "$(GIT_BRANCH)" != "$(ASSERT_BRANCH)" ] ; then \
		echo "ERROR: You are not on the correct git branch to build this target." ;\
		echo "(Hint: git checkout $(ASSERT_BRANCH))" ;\
		exit 1 ;\
	fi


############################################################
# RULES - Install (used by rpmbuild)
############################################################

# The 'install' target is called by rpmbuild during package creation
# and does *not* have access to the Git information.
# Note the use of $(DESTDIR) for debian packaging compatibility
install: 
	@echo "DEBUG - running target $@"
	mkdir -p $(DESTDIR)/etc/openxpki
	tar cf - --exclude debian --exclude package $(ETC_OXI_SUBDIRS) | tar xf - -C $(DESTDIR)/etc/openxpki

############################################################
# RULES - Package Build Targets
############################################################

pkgname:
	@echo "$(PKGNAME)"

pkgdesc:
	@echo "$(PKGDESC)"

version: VERSION
	@echo "$(VERSION)"

git-commit-hash:
	@echo "$(GIT_COMMIT_HASH)"

git-branch:
	@echo "$(GIT_BRANCH)"

git-tags:
	@echo "$(GIT_TAGS)"

VERSION.META: VERSION
	echo "GIT_COMMIT_HASH=$(shell git rev-parse HEAD)" > $@
	echo "GIT_TAGS=$(patsubst refs/tags/%,%,$(shell \
	git show-ref --tags -d|grep ^$(shell git rev-parse HEAD)|awk '{print $$2}'))" >> $@

.INTERMEDIATE: $(PKGNAME)-$(VERSION).tar

$(PKGNAME)-$(VERSION).tar.gz:
	echo ".gitattributes export-ignore" > .gitattributes
	echo ".gitignore export-ignore" >> .gitattributes
	echo "package export-ignore" >> .gitattributes
	echo "debian export-ignore" >> .gitattributes
	echo "*.spec export-ignore" >> .gitattributes
	git archive \
		--prefix=$(PKGNAME)-$(VERSION)/ \
		--output=$@ \
		HEAD

dist: $(PKGNAME)-$(VERSION).tar.gz

package/suse/$(PKGNAME).spec: package/suse/system-config.spec.template check assert-specific-target
	tpage $(TT_VERSION_SYMBOLS) \
		--define PKGNAME="$(PKGNAME)" \
		--define PKGDESC="$(PKGDESC)" \
		--define version="$(VERSION)" \
		--define GIT_COMMIT_HASH="$(GIT_COMMIT_HASH)" \
		--define GIT_TAGS="$(GIT_TAGS)" \
		$< > $@.new
	mv $@.new $@

/usr/src/packages/SOURCES/$(PKGNAME)-$(VERSION).tar.gz: $(PKGNAME)-$(VERSION).tar.gz
	install $< $@

$(HOME)/rpmbuild/SOURCES/$(PKGNAME)-$(VERSION).tar.gz: $(PKGNAME)-$(VERSION).tar.gz
	install $< $@

.PHONY: package rpm

package: rpm

rpm: package/suse/$(PKGNAME).spec $(HOME)/rpmbuild/SOURCES/$(PKGNAME)-$(VERSION).tar.gz
	rpmbuild -bb $<

############################################################
# RULES - Helper Targets
############################################################

clean:
	rm -rf $(PKGNAME)-$(VERSION).tar.gz $(PKGNAME)-$(VERSION).tar \
		$(PKGNAME).spec

config.d/system/version.yaml:
	touch config.d/system/version.yaml
	sed -r "/^commit:/d" -i config.d/system/version.yaml
	git log -n 1 --format=format:"commit: \"%h\"%n" HEAD > config.d/system/version.yaml

openxpki-config-ee.i18n: config.d template
	@grep -rhoEe 'I18N_OPENXPKI_UI_\w+' config.d template | sort | uniq > $@ 
	test -d ../openxpki/core/i18n/extra && cp $@ ../openxpki/core/i18n/extra

contrib/i18n/openxpki-cust.i18n:
	@grep -rhoEe 'I18N_OPENXPKI_UI_CUST\w+' config.d template | sort | uniq > $@ 
	
certgen: contrib/certgen.yaml
	docker run -u $(shell id -u ${USER}) -v $(shell pwd):/config  whiterabbitsecurity/openxpki3ee certgen /config/contrib/certgen.yaml /config/certgen/ca


# TODO: clean up this section
#
# To also show customer-specific help, add something like the
# following to Makefile.cust or Makefile.local:
#
# 	define CUST_HELP
# 		@echo "This is cust help text"
# 	endef
#
help:
	@echo "Usage"
	@echo
	@echo
	$(CUST_HELP)

############################################################
# Debian Targets
#
# For information on Debian packaging, see:
#
# 	https://wiki.debian.org/IntroDebianPackaging
#
############################################################

.PHONY: debian debian-clean debian-install debian-test

debian: $(DEB_PKG)

# This is "Step 1" in the debian packaging intro
$(DEB_TARBALL): $(PKGNAME)-$(VERSION).tar.gz
	cp -a $< $@

$(DEB_PKG): $(DEB_TARBALL) $(shell find debian -type f)
	@echo "INFO: begin make rule '$@'"
	# delete previous build, if exists
	rm -rf $(DEB_SRCDIR)
	# unpack Perl tarball ("Step 2" of the debian packaging intro)
	tar xzf $(DEB_TARBALL)
	# BEGIN "Step 3" of the debian packaging intro...
	#tar cf -  debian | tar xf - -C $(DEB_SRCDIR)
	$(MAKE) $(PKGNAME)-$(VERSION)/debian/control
	$(MAKE) $(PKGNAME)-$(VERSION)/debian/rules
	# update changelog
	cd $(DEB_SRCDIR) && debchange --create --package $(PKGNAME) --newversion $(VERSION)-$(RELEASE) autobuild
	# END "Step 3"
	# build the package
	cd $(DEB_SRCDIR) && DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage --build=binary -us -uc

debian-clean: clean
	rm -rf $(DEB_PKG) #\
#		debian/changelog 
#		$(DEB_TARBALL) \
#		$(PKGNAME)_$(VERSION)-$(RELEASE).debian.tar.gz \
#	    $(PKGNAME)_$(VERSION)-$(RELEASE).dsc \
#		perl-$(VERSION)

debian-install: #$(DEB_PKG)
	$(SUDO) dpkg -i $(DEB_PKG)

debian-test:
	$(MYPROVE)

# The following targets are used for local customization
$(PKGNAME)-$(VERSION)/debian/control: debian/control.template
	tpage $(TT_VERSION_SYMBOLS) \
		--define PKGNAME="$(PKGNAME)" \
		--define PKGDESC="$(PKGDESC)" \
		--define version="$(VERSION)" \
		--define GIT_COMMIT_HASH="$(GIT_COMMIT_HASH)" \
		--define GIT_TAGS="$(GIT_TAGS)" \
		$< > $@.new
	mv $@.new $@

$(PKGNAME)-$(VERSION)/debian/rules: debian/rules.template
	tpage $(TT_VERSION_SYMBOLS) \
		--define PKGNAME="$(PKGNAME)" \
		--define PKGDESC="$(PKGDESC)" \
		--define version="$(VERSION)" \
		--define GIT_COMMIT_HASH="$(GIT_COMMIT_HASH)" \
		--define GIT_TAGS="$(GIT_TAGS)" \
		$< > $@.new
	mv $@.new $@

		
