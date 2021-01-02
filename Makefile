CFLAGS += -O2 -Wall
HIDAPI = hidraw
LDFLAGS += -lhidapi-$(HIDAPI)
PYTHON_INCLUDE=$(shell python3-config --includes)

PREFIX=/usr

#Default 32 bit x86, raspberry pi, etc..
LIBDIR = $(PREFIX)/lib

#Catch x86_64 machines that use /usr/lib64 (RedHat)
ifneq ($(wildcard $(PREFIX)/lib64/.),)
    LIBDIR = $(PREFIX)/lib64
endif

#Catch debian machines with Multiarch (x64)
ifneq ($(wildcard $(PREFIX)/lib/x86_64-linux-gnu/.),)
    LIBDIR = $(PREFIX)/lib/x86_64-linux-gnu
endif

#Catch debian machines with Multiarch (aarch64)
ifneq ($(wildcard $(PREFIX)/lib/aarch64-linux-gnu/.),)
    LIBDIR = $(PREFIX)/lib/aarch64-linux-gnu
endif

#Catch debian machines with Multiarch (arm-linux-gnueabihf)
ifneq ($(wildcard $(PREFIX)/lib/arm-linux-gnueabihf/.),)
    LIBDIR = $(PREFIX)/lib/arm-linux-gnueabihf
endif

all: usbrelay libusbrelay.so 
python: usbrelay libusbrelay.so libusbrelay_py.so

libusbrelay.so: libusbrelay.c libusbrelay.h 
	$(CC) -shared -fPIC $(CPPFLAGS) $(CFLAGS)  $< $(LDFLAGS) -o $@ 

usbrelay: usbrelay.c libusbrelay.h libusbrelay.so
	$(CC) $(CPPFLAGS) $(CFLAGS)  $< -lusbrelay -L./ $(LDFLAGS) -o $@

# Command to generate version number if running from git repo
DIR_VERSION = $(shell basename `pwd`)
GIT_VERSION = $(shell git describe --tags --match '[0-9].[0-9]*' --abbrev=10 --dirty)

# If .git/HEAD and/or .git/index exist, we generate git version with
# the command above and regenerate it whenever any of these files
# changes. If these files don't exist, we use ??? as the version.
gitversion.h: $(wildcard .git/HEAD .git/index)
	echo "#define GITVERSION \"$(if $(word 1,$^),$(GIT_VERSION),$(DIR_VERSION))\"" > $@

usbrelay.c libusbrelay.c: gitversion.h

#We build this once directly for error checking purposes, then let python do the real build

libusbrelay_py.so: libusbrelay_py.c libusbrelay.so
	$(CC) -shared -fPIC $(PYTHON_INCLUDE) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -L./ -lusbrelay -o $@ $<
	python3 setup.py build

clean:
	rm -f usbrelay
	rm -f libusbrelay.so
	rm -f libusbrelay_py.so
	rm -rf build
	rm -f gitversion.h


install: usbrelay libusbrelay.so
	install -d $(DESTDIR)$(LIBDIR)
	install -m 0755 libusbrelay.so $(DESTDIR)$(LIBDIR)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 0755 usbrelay $(DESTDIR)$(PREFIX)/bin

install_py: install libusbrelay.so libusbrelay_py.so
	python3 setup.py install

release: usbrelay-$(GIT_VERSION).tar.gz usbrelay-$(GIT_VERSION).zip

# Create release tarball. Make sure that the same commit produces the
# same binary (hence --mtime and -n).
usbrelay-$(GIT_VERSION).tar.gz: gitversion.h
	git archive --format=tar --prefix=usbrelay-$(GIT_VERSION)/ HEAD > usbrelay.tar.tmp
	tar --append --file usbrelay.tar.tmp --transform="s|^|usbrelay-$(GIT_VERSION)/|" --mtime="$(shell git log -1 --format=%aI)" gitversion.h
	gzip --to-stdout -n usbrelay.tar.tmp > $@
	rm -f usbrelay.tar.tmp

# Create release zip. Attempt to make sure that the same commit
# produces the same binary (hence touch --date).
usbrelay-$(GIT_VERSION).zip: gitversion.h
	git archive --format=zip --prefix=usbrelay-$(GIT_VERSION)/ HEAD > usbrelay.zip.tmp
	mkdir -p usbrelay-$(GIT_VERSION)/
	cp gitversion.h usbrelay-$(GIT_VERSION)/
	-touch --date="$(shell git log -1 --format=%aI)" usbrelay-$(GIT_VERSION)/gitversion.h
	zip --grow usbrelay.zip.tmp usbrelay-$(GIT_VERSION)/gitversion.h
	rm usbrelay-$(GIT_VERSION)/gitversion.h
	-rmdir usbrelay-$(GIT_VERSION)
	mv usbrelay.zip.tmp $@

.PHONY: all clean install release
