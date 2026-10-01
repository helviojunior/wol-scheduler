# WOL Scheduler for pfSense

A pfSense package that schedules **Wake-on-LAN** packets and keeps machines awake with a
**Keep-Alive** mode: pfSense pings the machine continuously and, if it stops answering,
sends WOL every 30 seconds (configurable) until it comes back.

- C daemon (`wolscheduler`), a static FreeBSD binary cross-compiled with Docker.
- Web GUI integrated into pfSense under **Services > WOL Scheduler**.
- Written against the **pfSense CE 2.7.0** sources (FreeBSD 14.0, PHP 8.2).

## Features

| Feature | Description |
|---|---|
| **Schedule** | Sends the magic packet to each host every *N* minutes (0 = off). |
| **Keep-Alive** | Pings every *X* s; after *N* consecutive failures the host is marked `down` and receives WOL every 30 s until it answers. |
| **Status** | Default tab: each host's state (up/down), lost pings, last ping reply, last WOL and WOL counter. Refreshes every 10 s. |
| **Wake now** | Button on the Status tab to send a WOL immediately. |
| **Service control** | Restart / stop (or start) buttons and a log shortcut in the page title bar, like the built-in services. |
| **Logs** | Events go to syslog: **Status > System Logs > General**. |

## Layout

```
daemon/              Daemon C source + Makefile
docker/Dockerfile    Cross-compilation (clang + FreeBSD 14.0 sysroot) and packaging
pkg/files/           Package files, mirroring the pfSense filesystem
  usr/local/pkg/wolscheduler.xml          GUI definition (fields, menu, service)
  usr/local/pkg/wolscheduler.inc          Validation, config generation, service control
  usr/local/pkg/shortcuts/wolscheduler.inc  Title-bar shortcuts (service buttons, log link)
  usr/local/www/wolscheduler_status.php   Status page
  usr/local/share/pfSense-pkg-wolscheduler/info.xml   Package registration
  etc/inc/priv/wolscheduler.priv.inc      GUI access privilege
scripts/             install.sh / uninstall.sh (run on pfSense), version.sh
.github/workflows/   release.yml: builds and attaches the package to each GitHub Release
```

## 1. Build

Requirements: **Docker** and **make** (Linux or macOS, Apple Silicon included).

```sh
make                  # amd64 (default – most x86 pfSense boxes)
make ARCH=arm64       # Netgate 1100 / 2100 (ARM)
make package-all      # both
```

Find your pfSense architecture by running `uname -m` in its shell
(`amd64` → `ARCH=amd64`; `arm64` → `ARCH=arm64`).

Build output goes to `dist/`:

```
dist/pfSense-pkg-wolscheduler-dev-v1.2.3-amd64.tar.gz   package to install
dist/wolscheduler-amd64                                  standalone binary (debugging)
```

On the first run Docker downloads the FreeBSD 14.0 `base.txz` (~180 MB) to build the
sysroot; later runs use the cache.

### Versioning

The version is **not stored in the repository**: GitHub Releases own it.
`scripts/version.sh` reads the tag of the latest Release through the GitHub API
(`/repos/helviojunior/wol-scheduler/releases/latest`), cached in `.cache/latest-release`
for 24 h (1 h while there is no Release yet; `0.0.0` until the first one).

| Channel | Where | Number | `wolscheduler -V` | Package |
|---|---|---|---|---|
| `release` | CI, when a Release is published | the tag | `1.2.3` | `pfSense-pkg-wolscheduler-1.2.3-<arch>.tar.gz` |
| `dev` | local builds (default) | latest Release | `1.2.3-dev+<commit>` | `pfSense-pkg-wolscheduler-dev-v1.2.3-<arch>.tar.gz` |

```sh
make version                       # show the version a build would get
WOL_REFRESH_VERSION=1 make version # ignore the cache
make CHANNEL=release WOL_VERSION=1.2.3   # what the CI does
```

Set `GITHUB_TOKEN` to avoid the API's anonymous rate limit.

### Release pipeline

Publishing a GitHub Release with a tag `vX.Y.Z` (or `X.Y.Z`) runs
[`.github/workflows/release.yml`](.github/workflows/release.yml), which builds the
amd64 and arm64 packages for that tag and attaches them (plus `.sha256` files) to
the Release. To rebuild the assets of an existing Release, use
**Actions > Release package > Run workflow** and enter the tag.

The binary is **statically** linked, so it does not depend on pfSense's libraries.

### Native build (local testing only)

```sh
make native
./daemon/wolscheduler -w 00:11:22:33:44:55 -b 192.168.1.255   # send one WOL
```

## 2. Install on pfSense

Prerequisite: SSH access enabled (**System > Advanced > Admin Access > Enable Secure Shell**).

Download the package for your architecture from the
[Releases page](https://github.com/helviojunior/wol-scheduler/releases) (or build it,
see above). Straight from the pfSense shell (ssh admin@192.168.1.1, option 8 "Shell"):

```sh
cd /tmp
fetch https://github.com/helviojunior/wol-scheduler/releases/download/v1.2.3/pfSense-pkg-wolscheduler-1.2.3-amd64.tar.gz
tar -xzf pfSense-pkg-wolscheduler-1.2.3-amd64.tar.gz
cd pfSense-pkg-wolscheduler-1.2.3-amd64
sh install.sh
```

Or copy a local build: `scp dist/pfSense-pkg-wolscheduler-*-amd64.tar.gz admin@192.168.1.1:/tmp/`.

`install.sh`:

1. checks that the binary runs on this architecture;
2. copies the files to `/usr/local/...` and `/etc/inc/priv/`;
3. registers the package with `/etc/rc.packages pfSense-pkg-wolscheduler POST-INSTALL`,
   the same mechanism official packages use (creates the menu, service and `config.xml` entry).

To **upgrade**, repeat the steps with the new tarball. The previous registration is
replaced (so menu and tabs are updated) and configured hosts are kept.

## 3. Configure

Go to **Services > WOL Scheduler**. It opens on the **Status** tab; on the **Hosts** tab
click **Add**:

| Field | Example | Notes |
|---|---|---|
| Enable | ✔ | |
| Description | Office PC | |
| MAC address | `00:11:22:33:44:55` | |
| Interface | LAN | WOL is sent to this interface's subnet broadcast address. |
| Broadcast override | *(empty)* | Optional, e.g. `192.168.1.255`. |
| UDP port | 9 | |
| Send WOL every (minutes) | 60 | `0` disables the schedule. |
| Keep-Alive | ✔ | |
| Host IP address | `192.168.1.50` | Required for Keep-Alive. |
| Ping interval (s) | 10 | |
| Ping timeout (s) | 2 | |
| Failures before down | 3 | Consecutive lost pings before the host is considered *down*. |
| WOL retry (s) | 30 | WOL interval while the host is *down*. |

**DHCP lease auto-fill:** the edit page has a **DHCP lease** selector (above the MAC field)
listing the DHCP leases and static mappings, grouped by interface. Picking one fills the MAC
address, interface, host IP address and description (description only when empty). Typing or
pasting a MAC that has a lease also fills the interface and, when empty, the host IP. The
interface of a dynamic lease is the one whose subnet contains the lease IP.

**Manual entry** (no lease, or a host outside DHCP) works the same way: fill in the fields by
hand; typing the host IP selects the interface whose subnet contains it, and a MAC typed with
`-` is normalized to `xx:xx:xx:xx:xx:xx`. With no leases at all, the selector is disabled and
says so.

On save, the package writes `/usr/local/etc/wolscheduler.conf` and reloads the daemon
(SIGHUP) without losing host state. The service shows up in **Status > Services** as
`wolscheduler` and starts automatically at boot. It only runs when at least one enabled
host has a schedule or Keep-Alive.

The **Status** tab shows live state and has the **Wake now** button. The icons in the page
title bar restart / stop the service (or start it when stopped) and open the related
log entries.

> **Tip:** when using Keep-Alive, give the host a static IP (or a DHCP reservation under
> **Services > DHCP Server**) and allow ICMP Echo in the operating system's firewall
> (Windows blocks ping by default). Otherwise the host will always look *down* and
> receive WOL every 30 s.

## 4. Uninstall

```sh
cd /tmp/pfSense-pkg-wolscheduler-1.2.3-amd64
sh uninstall.sh
```

Removes the menu, service, `config.xml` entries and installed files.

## Troubleshooting

```sh
pgrep -l wolscheduler
cat /usr/local/etc/wolscheduler.conf
cat /var/run/wolscheduler.status
grep wolscheduler /var/log/system.log

# Validate the config file
wolscheduler -t -c /usr/local/etc/wolscheduler.conf

# Run in the foreground with debug logging (stop the service first)
/usr/local/etc/rc.d/wolscheduler.sh stop
wolscheduler -f -d

# Send a manual WOL
wolscheduler -w 00:11:22:33:44:55 -b 192.168.1.255 -P 9
```

### Daemon options

```
wolscheduler [-fd] [-c conf] [-p pidfile] [-s statusfile]
  -f  foreground (log to stderr)          -d  debug logging
  -c  config  (/usr/local/etc/wolscheduler.conf)
  -p  pidfile (/var/run/wolscheduler.pid)
  -s  status  (/var/run/wolscheduler.status)
wolscheduler -t [-c conf]                 validate the config
wolscheduler -w MAC [-b broadcast] [-P port]   send one WOL and exit
wolscheduler -V                           version
```

Signals: `SIGHUP` reloads the config; `SIGTERM` exits.

## Limitations

- The package is installed outside the official repository, so it **does not appear** under
  *System > Package Manager > Installed Packages* (the GUI and service work normally).
- After a **pfSense upgrade**, reinstall the package with `install.sh`. Host settings live
  in `config.xml` and are preserved.
- Keep-Alive supports IPv4 only.
- WOL only works on the same L2 network as the selected interface (it is a broadcast). The
  machine's NIC must have WOL enabled in the BIOS/UEFI and in the operating system.
