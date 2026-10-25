#!/bin/sh
#
# AdGuardHome core updater (hardened).
#
#  - The update source is an enum (official|github) stored in UCI as
#    adguardhome.config.update_source. It is mapped to a fixed URL in this
#    script; no URL read from UCI or from the network is ever expanded or eval'd.
#  - TLS certificate verification is always on.
#  - The archive's SHA-256 is verified against the checksums.txt published with
#    the matching GitHub release. If it cannot be fetched or does not match,
#    the update is refused (fail closed).
#  - Work happens in a private mktemp directory, only the one expected tar
#    member is extracted, the new binary is test-run before it is installed,
#    and it is installed with an atomic rename.

PATH="/usr/sbin:/usr/bin:/sbin:/bin"

SELF="/usr/share/AdGuardHome/update_core.sh"
binpath="/usr/bin/AdGuardHome"
initscript="/etc/init.d/adguardhome"

LOG="/tmp/AdGuardHome_update.log"          # read by the LuCI view for progress
FLAG="/var/run/update_core"
FLAG_DONE="/var/run/update_core_done"
FLAG_ERR="/var/run/update_core_error"
LOCKDIR="/var/run/update_core.lock"

REPO_API="https://api.github.com/repos/AdguardTeam/AdGuardHome"
REPO_DL="https://github.com/AdguardTeam/AdGuardHome/releases/download"
OFFICIAL_BASE="https://static.adtidy.org/adguardhome/release"

# True if $1 is the PID of a running instance of this script.
updater_alive() {
	[ -n "$1" ] && kill -0 "$1" 2>/dev/null &&
		tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null | grep -q 'update_core\.sh'
}

# ===========================================================================
# Stage 1: validate the argument, handle a running instance, then re-run this
# script in the background so the LuCI call returns immediately.
# ===========================================================================
if [ "$1" != "bg_run" ]; then
	# Usage: update_core.sh [force|""] [latest|beta|""] [official|github|""]
	# The 2nd/3rd arguments override the UCI settings for this run only, so the
	# LuCI page does not have to stage (and leave behind) unsaved UCI changes.
	case "$1" in
	force|"") mode="$1" ;;
	*) echo "Invalid argument." >&2; exit 1 ;;
	esac
	case "$2" in
	latest|beta|"") arg_channel="$2" ;;
	*) echo "Invalid channel." >&2; exit 1 ;;
	esac
	case "$3" in
	official|github|"") arg_source="$3" ;;
	*) echo "Invalid source." >&2; exit 1 ;;
	esac

	oldpid="$(cat "$LOCKDIR/pid" 2>/dev/null)"
	if updater_alive "$oldpid"; then
		if [ "$mode" != "force" ]; then
			echo "An update task is already running."
			exit 0
		fi
		kill "$oldpid" 2>/dev/null
		i=0
		while updater_alive "$oldpid" && [ "$i" -lt 5 ]; do
			sleep 1
			i=$((i + 1))
		done
		updater_alive "$oldpid" && kill -9 "$oldpid" 2>/dev/null
		sleep 1
	fi

	rm -rf "$LOCKDIR" "$FLAG" "$FLAG_DONE" "$FLAG_ERR" "$LOG"
	# noclobber: refuse to follow/replace anything that appeared at the log path
	( umask 077; set -C; : > "$LOG" ) 2>/dev/null || {
		echo "Cannot create log file." >&2
		exit 1
	}
	touch "$FLAG"
	"$SELF" bg_run "$mode" "$arg_channel" "$arg_source" </dev/null >>"$LOG" 2>&1 &
	exit 0
fi

# ===========================================================================
# Stage 2: the actual update (runs in the background, output goes to $LOG)
# ===========================================================================
shift
update_mode="$1"
arg_channel="$2"
arg_source="$3"

WORKDIR=""

finish() {
	_code="${1:-0}"
	[ -n "$WORKDIR" ] && rm -rf "$WORKDIR"
	rm -rf "$LOCKDIR" "$FLAG"
	[ "$_code" != "0" ] && touch "$FLAG_ERR"
	exit "$_code"
}

case "$update_mode" in
force|"") ;;
*) echo "Invalid mode." >&2; exit 1 ;;
esac

mkdir "$LOCKDIR" 2>/dev/null || { echo "Another update task is running."; exit 2; }
echo $$ > "$LOCKDIR/pid"
trap 'finish 1' TERM INT HUP

# ---- settings ---------------------------------------------------------------
core_version="$(uci -q get adguardhome.config.core_version 2>/dev/null)"
update_source="$(uci -q get adguardhome.config.update_source 2>/dev/null)"
legacy_url="$(uci -q get adguardhome.config.update_url 2>/dev/null)"

# Values chosen on the LuCI page (already whitelisted in stage 1) win over UCI.
[ -n "${arg_channel}" ] && core_version="${arg_channel}"
[ -n "${arg_source}" ] && update_source="${arg_source}"

case "${core_version}" in
beta) ;;
*) core_version="latest" ;;
esac

case "${update_source}" in
official|github) ;;
*)
	# Migrate old configs that stored a full URL: only classify it, never use it.
	case "${legacy_url}" in
	https://github.com/*) update_source="github" ;;
	*) update_source="official" ;;
	esac
	;;
esac

# The official mirror only carries the stable channel.
if [ "${core_version}" = "beta" ] && [ "${update_source}" = "official" ]; then
	echo "Beta channel is only available from GitHub; using GitHub."
	update_source="github"
fi

if [ "${core_version}" = "beta" ]; then
	core_api_url="${REPO_API}/releases"
else
	core_api_url="${REPO_API}/releases/latest"
fi

# ---- helpers ----------------------------------------------------------------
Check_Downloader() {
	if command -v curl >/dev/null 2>&1; then
		PKG="curl"
	elif command -v wget >/dev/null 2>&1; then
		PKG="wget"
	else
		echo "Neither curl nor wget is installed, cannot check updates!" >&2
		finish 1
	fi
	if ! command -v sha256sum >/dev/null 2>&1; then
		echo "sha256sum is not installed, cannot verify downloads!" >&2
		finish 1
	fi
}

# fetch_file DEST URL  (HTTPS only, certificate verification on, 3 attempts)
fetch_file() {
	_n=1
	while [ "$_n" -le 3 ]; do
		case "${PKG}" in
		curl)
			curl -fL --proto '=https' --proto-redir '=https' \
				--connect-timeout 10 -m 300 --progress-bar \
				-o "$1" "$2" && return 0
			;;
		wget)
			wget -T 10 -q -O "$1" "$2" && return 0
			;;
		esac
		_n=$((_n + 1))
		sleep 2
	done
	return 1
}

# fetch_text URL  -> stdout
fetch_text() {
	case "${PKG}" in
	curl)
		curl -fsSL --proto '=https' --proto-redir '=https' \
			--connect-timeout 10 -m 60 "$1"
		;;
	wget)
		wget -T 10 -q -O - "$1"
		;;
	esac
}

GET_Arch() {
	Archt="$(uname -m)"
	case "${Archt}" in
	i386|i686)
		Arch="386"
		;;
	x86_64|amd64)
		Arch="amd64"
		;;
	mips64el*)
		Arch="mips64le_softfloat"
		;;
	mips64*)
		Arch="mips64_softfloat"
		;;
	mipsel*)
		Arch="mipsle_softfloat"
		;;
	mips*)
		Arch="mips_softfloat"
		;;
	armv5*)
		Arch="armv5"
		;;
	armv6*)
		Arch="armv6"
		;;
	armv7*|arm|armhf)
		Arch="armv7"
		;;
	aarch64)
		Arch="arm64"
		;;
	riscv64)
		Arch="riscv64"
		;;
	ppc64le)
		Arch="ppc64le"
		;;
	*)
		echo "Unsupported architecture: [${Archt}]" >&2
		finish 1
		;;
	esac
	echo "Detected architecture: ${Arch}"
}

# ---- main -------------------------------------------------------------------
Check_Downloader
echo "[${PKG}] Checking for updates (channel: ${core_version}, source: ${update_source}) ..."

Cloud_Version="$(fetch_text "${core_api_url}" 2>/dev/null |
	grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' |
	head -n 1 |
	sed 's/.*:[[:space:]]*"\(.*\)"/\1/')"

if [ -z "${Cloud_Version}" ]; then
	echo "Failed to check updates, please check network, CA certificates and TLS support (ca-bundle, libustream-*)." >&2
	finish 1
fi
if ! printf '%s' "${Cloud_Version}" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$'; then
	echo "Unexpected version string from the release API, refusing to continue." >&2
	finish 1
fi

Current_Version="unknown"
if [ -x "${binpath}" ]; then
	_cv="$("${binpath}" --version 2>/dev/null | grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+[-A-Za-z0-9.]*' | head -n 1)"
	[ -n "${_cv}" ] && Current_Version="${_cv}"
fi

echo "Binary path: ${binpath%/*}"
echo "Current version: ${Current_Version}"
echo "Latest version: ${Cloud_Version}"

if [ "${Cloud_Version}" = "${Current_Version}" ] && [ "${update_mode}" != "force" ]; then
	echo "Already up to date."
	touch "$FLAG_DONE"
	finish 0
fi

GET_Arch

WORKDIR="$(mktemp -d /tmp/AdGuardHome_Update.XXXXXX)" || {
	echo "Unable to create a temporary directory" >&2
	finish 1
}
chmod 700 "${WORKDIR}"

archive="AdGuardHome_linux_${Arch}.tar.gz"
gh_base="${REPO_DL}/${Cloud_Version}"

case "${update_source}" in
official) link="${OFFICIAL_BASE}/${archive}" ;;
*) link="${gh_base}/${archive}" ;;
esac
sums_url="${gh_base}/checksums.txt"

echo "Download link: ${link}"
echo "Downloading AdGuardHome core ..."
if ! fetch_file "${WORKDIR}/${archive}" "${link}"; then
	echo "Download failed." >&2
	finish 1
fi

# ---- integrity check (fail closed) -------------------------------------------
echo "Verifying SHA-256 against ${sums_url} ..."
if ! fetch_file "${WORKDIR}/checksums.txt" "${sums_url}" >/dev/null 2>&1; then
	echo "Cannot download checksums.txt; refusing to install an unverified binary." >&2
	finish 1
fi

expected="$(awk -v n="${archive}" '{
	f = $2; sub(/^\*/, "", f); sub(/^\.\//, "", f)
	if (f == n) { print tolower($1); exit }
}' "${WORKDIR}/checksums.txt")"

if ! printf '%s' "${expected}" | grep -Eq '^[0-9a-f]{64}$'; then
	echo "No valid checksum entry for ${archive} in checksums.txt; refusing to install." >&2
	finish 1
fi

actual="$(sha256sum "${WORKDIR}/${archive}" | awk '{print $1}')"
if [ "${actual}" != "${expected}" ]; then
	echo "SHA-256 mismatch! expected ${expected}, got ${actual}." >&2
	if [ "${update_source}" = "official" ]; then
		echo "The mirror may be out of sync with the latest release; try the GitHub source." >&2
	fi
	finish 1
fi
echo "SHA-256 OK: ${actual}"

# ---- extract only the expected member ---------------------------------------
echo "Extracting AdGuardHome ..."
# Release tarballs may store members as "./AdGuardHome/AdGuardHome" or without
# the "./"; tar matches names literally, so look up the real name first and
# extract exactly that one member.
member="$(tar -tzf "${WORKDIR}/${archive}" 2>/dev/null | grep -E '^(\./)?AdGuardHome/AdGuardHome$' | head -n 1)"
if [ -z "${member}" ]; then
	echo "Extraction failed: AdGuardHome/AdGuardHome not found in the archive. Archive members:" >&2
	tar -tzf "${WORKDIR}/${archive}" 2>&1 | head -n 10 >&2
	finish 1
fi
if ! tar -zxf "${WORKDIR}/${archive}" -C "${WORKDIR}" "${member}"; then
	echo "Extraction failed!" >&2
	finish 1
fi

newbin="${WORKDIR}/AdGuardHome/AdGuardHome"
if [ ! -f "${newbin}" ] || [ -L "${newbin}" ]; then
	echo "Extraction failed: binary not found or not a regular file!" >&2
	finish 1
fi
chmod 755 "${newbin}"

# ---- test-run the new binary before touching the installed one ---------------
if ! "${newbin}" --version >/dev/null 2>&1; then
	echo "The downloaded binary does not run on this device; keeping the current one." >&2
	finish 1
fi
echo "Core size: $(wc -c < "${newbin}") bytes"

# ---- install: copy next to the target, verify, then atomic rename ------------
echo "Installing to ${binpath%/*} ..."
newcopy="${binpath}.new"
rm -f "${newcopy}"
if ! cp "${newbin}" "${newcopy}" ||
   [ "$(sha256sum "${newcopy}" | awk '{print $1}')" != "$(sha256sum "${newbin}" | awk '{print $1}')" ]; then
	echo "Copying the new core failed (insufficient space?). The current core was left untouched." >&2
	rm -f "${newcopy}"
	finish 1
fi
chmod 755 "${newcopy}"
if ! mv -f "${newcopy}" "${binpath}"; then
	echo "Replacing the core failed. The current core was left untouched." >&2
	rm -f "${newcopy}"
	finish 1
fi

# Only restart a service the user has enabled; restarting a disabled one starts
# nothing and only runs the init script's cleanup paths (control.sh, crontab).
service_enabled="$(uci -q get adguardhome.config.enabled 2>/dev/null)"
if [ "${service_enabled}" = "1" ] && [ -x "${initscript}" ]; then
	echo "Restarting AdGuardHome service ..."
	"${initscript}" restart 2>&1 || echo "Warning: the service restart reported an error."
else
	echo "Service is not enabled; skipping restart."
fi

echo "AdGuardHome core updated successfully!"
touch "$FLAG_DONE"
finish 0
