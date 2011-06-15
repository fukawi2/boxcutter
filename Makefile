### The project name
PROJECT=boxcutter

### Dependencies
DEP_PMODS=Mac::iTunes::Library Mac::iTunes::Library::XML URI::Escape Number::Bytes::Human

### Destination Paths
D_BIN=/usr/local/sbin
D_DOC=/usr/local/share/doc/$(PROJECT)
D_DOC=/usr/local/share/man

### Lists of files to be installed
F_CONF=boxcutter.pl
F_DOCS=COPYING

###############################################################################

all: install

install: test bin docs

test:
	@echo "==> Checking for required perl modules"
	for pmod in $(DEP_PMODS) ; do \
		perl -M$$pmod -e 1 || exit 1 ; \
	done
	@echo "==> It all looks good Captain!"

bin: test $(PROJECT).pl
	install -D -m 0755 $(PROJECT).pl $(DESTDIR)$(D_BIN)/$(PROJECT)

docs: $(F_DOCS)
	pod2man --name=boxcutter boxcutter.pl boxcutter.1.man
	install -Dm0644 boxcutter.1.man $(DESTDIR)$(D_MAN)/man1/boxcutter.1.man

uninstall:
	rm -f $(DESTDIR)$(D_MAN)/man1/boxcutter.1.man
	rm -f $(DESTDIR)$(D_BIN)/$(PROJECT)
