#!/bin/sh
#
# Installs (or upgrades) the wolscheduler package on pfSense.
# Run as root on the pfSense box from inside the extracted package directory.
#
set -e

PKG=pfSense-pkg-wolscheduler
SHARE=/usr/local/share/${PKG}
RC=/usr/local/etc/rc.d/wolscheduler.sh

cd "$(dirname "$0")"

if [ "$(id -u)" != "0" ]; then
	echo "error: run as root" >&2
	exit 1
fi
if [ ! -f /etc/rc.packages ] || [ ! -x /usr/local/bin/php ]; then
	echo "error: this does not look like a pfSense system" >&2
	exit 1
fi
if [ ! -d files ]; then
	echo "error: 'files' directory not found next to install.sh" >&2
	exit 1
fi

# Sanity check: the binary must run on this system/architecture.
if ! ./files/usr/local/bin/wolscheduler -V >/dev/null 2>&1; then
	echo "error: wolscheduler binary does not run here (wrong ARCH? this box is $(uname -m))" >&2
	exit 1
fi

# Stop a running instance before replacing the binary (upgrade).
[ -x "$RC" ] && "$RC" stop >/dev/null 2>&1 || true

echo "==> Copying files"
(cd files && find . -type f | sed 's|^\.||') > /tmp/${PKG}.files
# Only regular files are archived so existing system directories keep their modes.
(cd files && find . -type f | tar -cf - -T -) | tar -C / -xpf -
mkdir -p "$SHARE"
mv /tmp/${PKG}.files "$SHARE/files.list"
chmod 0755 /usr/local/bin/wolscheduler

echo "==> Registering package (menu, service, config)"
/usr/local/bin/php -f /etc/rc.packages ${PKG} POST-INSTALL

echo
echo "Done. Open Services > WOL Scheduler in the web GUI."
