#!/bin/sh
#
# Prints the base version (X.Y.Z) of the build. The version is not stored in
# the repository: GitHub Releases own it.
#
#   WOL_VERSION set   -> that value (the CI passes the release tag)
#   otherwise         -> tag of the latest published GitHub Release
#
# The API lookup is cached in .cache/latest-release for 24 h (1 h while there
# is no release yet). WOL_REFRESH_VERSION=1 bypasses the cache. Offline, the
# cached value is used; with no release at all, 0.0.0.
#
set -u

REPO=helviojunior/wol-scheduler
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CACHE="$ROOT/.cache/latest-release"
TTL=86400
NO_RELEASE_TTL=3600

parse() {
	echo "$1" | sed -nE 's/^v?([0-9]+)\.([0-9]+)\.([0-9]+)$/\1.\2.\3/p'
}

if [ -n "${WOL_VERSION:-}" ]; then
	v=$(parse "$WOL_VERSION")
	if [ -z "$v" ]; then
		echo "WOL_VERSION='$WOL_VERSION' is not X.Y.Z" >&2
		exit 1
	fi
	echo "$v"
	exit 0
fi

cached=""
if [ -f "$CACHE" ]; then
	cached=$(parse "$(cat "$CACHE")")
	ttl=$TTL
	[ "$cached" = "0.0.0" ] && ttl=$NO_RELEASE_TTL
	mtime=$(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE")
	age=$(( $(date +%s) - mtime ))
	if [ -n "$cached" ] && [ "${WOL_REFRESH_VERSION:-0}" != "1" ] && [ "$age" -lt "$ttl" ]; then
		echo "$cached"
		exit 0
	fi
fi

set -- -sS -m 10 -w '\n%{http_code}' -H "Accept: application/vnd.github+json"
[ -n "${GITHUB_TOKEN:-}" ] && set -- "$@" -H "Authorization: Bearer $GITHUB_TOKEN"
resp=$(curl "$@" "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null)
code=$(echo "$resp" | tail -n 1)

case "$code" in
	200)
		tag=$(echo "$resp" | sed -nE 's/^ *"tag_name": *"([^"]*)".*/\1/p' | head -n 1)
		found=$(parse "$tag")
		[ -z "$found" ] && found=0.0.0
		;;
	404)	# no release published yet
		found=0.0.0
		;;
	*)	# offline or API error: keep the last known value
		echo "${cached:-0.0.0}"
		exit 0
		;;
esac

mkdir -p "$(dirname "$CACHE")"
echo "$found" > "$CACHE"
echo "$found"
