#!/bin/sh
#
# Removes the wolscheduler package from pfSense.
# Host entries in config.xml are removed as well.
#
set -e

PKG=pfSense-pkg-wolscheduler
SHARE=/usr/local/share/${PKG}

if [ "$(id -u)" != "0" ]; then
	echo "error: run as root" >&2
	exit 1
fi

echo "==> Unregistering package"
/usr/local/bin/php -f /etc/rc.packages ${PKG} DEINSTALL || true
/usr/local/bin/php -f /etc/rc.packages ${PKG} POST-DEINSTALL || true

echo "==> Removing files"
if [ -f "$SHARE/files.list" ]; then
	while read -r f; do
		[ -n "$f" ] && rm -f "$f"
	done < "$SHARE/files.list"
fi
rm -rf "$SHARE"
rm -f /usr/local/etc/rc.d/wolscheduler.sh /usr/local/etc/wolscheduler.conf \
	/var/run/wolscheduler.pid /var/run/wolscheduler.status

echo "Done."
