PREFIX ?= /usr/local

hme: hme.m
	clang -fobjc-arc -fmodules -O2 -Wall -Wextra -Wno-unused-parameter -Werror \
		-arch arm64 -arch x86_64 -mmacosx-version-min=12.0 $< -o $@
	codesign --force --sign - $@

install: hme
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 hme $(DESTDIR)$(PREFIX)/bin/hme

clean:
	rm -f hme

.PHONY: install clean
