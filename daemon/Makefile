# Builds natively (FreeBSD/macOS/Linux) or cross-compiles when CC/CFLAGS/LDFLAGS
# are provided by the Docker build (see docker/Dockerfile).

CC      ?= cc
CFLAGS  ?= -O2
LDFLAGS ?=
VERSION ?=

# `override` so these are kept when CFLAGS is given on the command line.
override CFLAGS += -Wall -Wextra -std=c99 -D_DEFAULT_SOURCE -D__BSD_VISIBLE=1
ifneq ($(VERSION),)
override CFLAGS += -DVERSION='"$(VERSION)"'
endif

PROG = wolscheduler

all: $(PROG)

$(PROG): wolscheduler.c
	$(CC) $(CFLAGS) -o $@ wolscheduler.c $(LDFLAGS)

clean:
	rm -f $(PROG)

.PHONY: all clean
