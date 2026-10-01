# Builds natively (FreeBSD/macOS/Linux) or cross-compiles when CC/CFLAGS/LDFLAGS
# are provided by the Docker build (see docker/Dockerfile).

CC      ?= cc
CFLAGS  ?= -O2
CFLAGS  += -Wall -Wextra -std=c99 -D_DEFAULT_SOURCE -D__BSD_VISIBLE=1
LDFLAGS ?=

PROG = wolscheduler

all: $(PROG)

$(PROG): wolscheduler.c
	$(CC) $(CFLAGS) -o $@ wolscheduler.c $(LDFLAGS)

clean:
	rm -f $(PROG)

.PHONY: all clean
