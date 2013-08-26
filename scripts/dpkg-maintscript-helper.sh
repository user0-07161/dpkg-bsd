#!/bin/sh
#
# Copyright © 2007,2011-2012 Guillem Jover <guillem@debian.org>
# Copyright © 2010 Raphaël Hertzog <hertzog@debian.org>
# Copyright © 2008 Joey Hess <joeyh@debian.org>
# Copyright © 2005 Scott James Remnant (original implementation on www.dpkg.org)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# The conffile related functions are inspired by
# http://wiki.debian.org/DpkgConffileHandling

# This script is documented in dpkg-maintscript-helper(1)

##
## Functions to remove an obsolete conffile during upgrade
##
rm_conffile() {
	local CONFFILE="$1"
	local LASTVERSION="$2"
	local PACKAGE="$3"
	if [ "$LASTVERSION" = "--" ]; then
		LASTVERSION=""
		PACKAGE="$DPKG_MAINTSCRIPT_PACKAGE${DPKG_MAINTSCRIPT_ARCH:+:$DPKG_MAINTSCRIPT_ARCH}"
	fi
	if [ "$PACKAGE" = "--" -o -z "$PACKAGE" ]; then
		PACKAGE="$DPKG_MAINTSCRIPT_PACKAGE${DPKG_MAINTSCRIPT_ARCH:+:$DPKG_MAINTSCRIPT_ARCH}"
	fi
	# Skip remaining parameters up to --
	while [ "$1" != "--" -a $# -gt 0 ]; do shift; done
	[ $# -gt 0 ] || badusage "missing arguments after --"
	shift

	[ -n "$PACKAGE" ] || error "couldn't identify the package"
	[ -n "$1" ] || error "maintainer script parameters are missing"
	[ -n "$DPKG_MAINTSCRIPT_NAME" ] || \
		error "environment variable DPKG_MAINTSCRIPT_NAME is required"

	debug "Executing $0 rm_conffile in $DPKG_MAINTSCRIPT_NAME" \
	      "of $DPKG_MAINTSCRIPT_PACKAGE"
	debug "CONFFILE=$CONFFILE PACKAGE=$PACKAGE" \
	      "LASTVERSION=$LASTVERSION ACTION=$1 PARAM=$2"
	case "$DPKG_MAINTSCRIPT_NAME" in
	preinst)
		if [ "$1" = "install" -o "$1" = "upgrade" ] && [ -n "$2" ] &&
		   dpkg --compare-versions "$2" le-nl "$LASTVERSION"; then
			prepare_rm_conffile "$CONFFILE" "$PACKAGE"
		fi
		;;
	postinst)
		if [ "$1" = "configure" ] && [ -n "$2" ] &&
		   dpkg --compare-versions "$2" le-nl "$LASTVERSION"; then
			finish_rm_conffile "$CONFFILE"
		fi
		;;
	postrm)
		if [ "$1" = "purge" ]; then
			rm -f "$CONFFILE.dpkg-bak" "$CONFFILE.dpkg-remove" \
			      "$CONFFILE.dpkg-backup"
		fi
		if [ "$1" = "abort-install" -o "$1" = "abort-upgrade" ] &&
		   [ -n "$2" ] &&
		   dpkg --compare-versions "$2" le-nl "$LASTVERSION"; then
			abort_rm_conffile "$CONFFILE" "$PACKAGE"
		fi
		;;
	*)
		debug "$0 rm_conffile not required in $DPKG_MAINTSCRIPT_NAME"
		;;
	esac
}

prepare_rm_conffile() {
	local CONFFILE="$1"
	local PACKAGE="$2"

	[ -e "$CONFFILE" ] || return 0
	ensure_package_owns_file "$PACKAGE" "$CONFFILE" || return 0

	local md5sum="$(md5sum $CONFFILE | sed -e 's/ .*//')"
	local old_md5sum="$(dpkg-query -W -f='${Conffiles}' $PACKAGE | \
		sed -n -e "\' $CONFFILE ' { s/ obsolete$//; s/.* //; p }")"
	if [ "$md5sum" != "$old_md5sum" ]; then
		echo "Obsolete conffile $CONFFILE has been modified by you."
		echo "Saving as $CONFFILE.dpkg-bak ..."
		mv -f "$CONFFILE" "$CONFFILE.dpkg-backup"
	else
		echo "Moving obsolete conffile $CONFFILE out of the way..."
		mv -f "$CONFFILE" "$CONFFILE.dpkg-remove"
	fi
}

finish_rm_conffile() {
	local CONFFILE="$1"

	if [ -e "$CONFFILE.dpkg-backup" ]; then
		mv -f "$CONFFILE.dpkg-backup" "$CONFFILE.dpkg-bak"
	fi
	if [ -e "$CONFFILE.dpkg-remove" ]; then
		echo "Removing obsolete conffile $CONFFILE ..."
		rm -f "$CONFFILE.dpkg-remove"
	fi
}

abort_rm_conffile() {
	local CONFFILE="$1"
	local PACKAGE="$2"

	ensure_package_owns_file "$PACKAGE" "$CONFFILE" || return 0

	if [ -e "$CONFFILE.dpkg-remove" ]; then
		echo "Reinstalling $CONFFILE that was moved away"
		mv "$CONFFILE.dpkg-remove" "$CONFFILE"
	fi
	if [ -e "$CONFFILE.dpkg-backup" ]; then
		echo "Reinstalling $CONFFILE that was backupped"
		mv "$CONFFILE.dpkg-backup" "$CONFFILE"
	fi
}

##
## Functions to rename a conffile during upgrade
##
mv_conffile() {
	local OLDCONFFILE="$1"
	local NEWCONFFILE="$2"
	local LASTVERSION="$3"
	local PACKAGE="$4"
	if [ "$LASTVERSION" = "--" ]; then
		LASTVERSION=""
		PACKAGE="$DPKG_MAINTSCRIPT_PACKAGE${DPKG_MAINTSCRIPT_ARCH:+:$DPKG_MAINTSCRIPT_ARCH}"
	fi
	if [ "$PACKAGE" = "--" -o -z "$PACKAGE" ]; then
		PACKAGE="$DPKG_MAINTSCRIPT_PACKAGE${DPKG_MAINTSCRIPT_ARCH:+:$DPKG_MAINTSCRIPT_ARCH}"
	fi
	# Skip remaining parameters up to --
	while [ "$1" != "--" -a $# -gt 0 ]; do shift; done
	[ $# -gt 0 ] || badusage "missing arguments after --"
	shift

	[ -n "$PACKAGE" ] || error "couldn't identify the package"
	[ -n "$1" ] || error "maintainer script parameters are missing"
	[ -n "$DPKG_MAINTSCRIPT_NAME" ] || \
		error "environment variable DPKG_MAINTSCRIPT_NAME is required"

	debug "Executing $0 mv_conffile in $DPKG_MAINTSCRIPT_NAME" \
	      "of $DPKG_MAINTSCRIPT_PACKAGE"
	debug "CONFFILE=$OLDCONFFILE -> $NEWCONFFILE PACKAGE=$PACKAGE" \
	      "LASTVERSION=$LASTVERSION ACTION=$1 PARAM=$2"
	case "$DPKG_MAINTSCRIPT_NAME" in
	preinst)
		if [ "$1" = "install" -o "$1" = "upgrade" ] && [ -n "$2" ] &&
		   dpkg --compare-versions "$2" le-nl "$LASTVERSION"; then
			prepare_mv_conffile "$OLDCONFFILE" "$PACKAGE"
		fi
		;;
	postinst)
		if [ "$1" = "configure" ] && [ -n "$2" ] &&
		   dpkg --compare-versions "$2" le-nl "$LASTVERSION"; then
			finish_mv_conffile "$OLDCONFFILE" "$NEWCONFFILE" "$PACKAGE"
		fi
		;;
	postrm)
		if [ "$1" = "abort-install" -o "$1" = "abort-upgrade" ] &&
		   [ -n "$2" ] &&
		   dpkg --compare-versions "$2" le-nl "$LASTVERSION"; then
			abort_mv_conffile "$OLDCONFFILE" "$PACKAGE"
		fi
		;;
	*)
		debug "$0 mv_conffile not required in $DPKG_MAINTSCRIPT_NAME"
		;;
	esac
}

prepare_mv_conffile() {
	local CONFFILE="$1"
	local PACKAGE="$2"

	[ -e "$CONFFILE" ] || return 0

	ensure_package_owns_file "$PACKAGE" "$CONFFILE" || return 0

	local md5sum="$(md5sum $CONFFILE | sed -e 's/ .*//')"
	local old_md5sum="$(dpkg-query -W -f='${Conffiles}' $PACKAGE | \
		sed -n -e "\' $CONFFILE ' { s/ obsolete$//; s/.* //; p }")"
	if [ "$md5sum" = "$old_md5sum" ]; then
		mv -f "$CONFFILE" "$CONFFILE.dpkg-remove"
	fi
}

finish_mv_conffile() {
	local OLDCONFFILE="$1"
	local NEWCONFFILE="$2"
	local PACKAGE="$3"

	rm -f $OLDCONFFILE.dpkg-remove

	[ -e "$OLDCONFFILE" ] || return 0
	ensure_package_owns_file "$PACKAGE" "$OLDCONFFILE" || return 0

	echo "Preserving user changes to $NEWCONFFILE (renamed from $OLDCONFFILE)..."
	mv -f "$NEWCONFFILE" "$NEWCONFFILE.dpkg-new"
	mv -f "$OLDCONFFILE" "$NEWCONFFILE"
}

abort_mv_conffile() {
	local CONFFILE="$1"
	local PACKAGE="$2"

	ensure_package_owns_file "$PACKAGE" "$CONFFILE" || return 0

	if [ -e "$CONFFILE.dpkg-remove" ]; then
		echo "Reinstalling $CONFFILE that was moved away"
		mv "$CONFFILE.dpkg-remove" "$CONFFILE"
	fi
}

##
## Functions to replace a symlink with a directory
##
symlink_to_dir() {
	local SYMLINK="$1"
	local SYMLINK_TARGET="$2"
	local LASTVERSION="$3"
	local PACKAGE="$4"

	if [ "$LASTVERSION" = "--" ]; then
		LASTVERSION=""
		PACKAGE="$DPKG_MAINTSCRIPT_PACKAGE${DPKG_MAINTSCRIPT_ARCH:+:$DPKG_MAINTSCRIPT_ARCH}"
	fi
	if [ "$PACKAGE" = "--" -o -z "$PACKAGE" ]; then
		PACKAGE="$DPKG_MAINTSCRIPT_PACKAGE${DPKG_MAINTSCRIPT_ARCH:+:$DPKG_MAINTSCRIPT_ARCH}"
	fi

	# Skip remaining parameters up to --
	while [ "$1" != "--" -a $# -gt 0 ]; do shift; done
	[ $# -gt 0 ] || badusage "missing arguments after --"
	shift

	[ -n "$DPKG_MAINTSCRIPT_NAME" ] || \
		error "environment variable DPKG_MAINTSCRIPT_NAME is required"
	[ -n "$PACKAGE" ] || error "cannot identify the package"
	[ -n "$SYMLINK" ] || error "symlink parameter is missing"
	[ -n "$SYMLINK_TARGET" ] || error "original symlink target is missing"
	[ -n "$LASTVERSION" ] || error "last version is missing"
	[ -n "$1" ] || error "maintainer script parameters are missing"

	debug "Executing $0 symlink_to_dir in $DPKG_MAINTSCRIPT_NAME" \
	      "of $DPKG_MAINTSCRIPT_PACKAGE"
	debug "SYMLINK=$SYMLINK -> $SYMLINK_TARGET PACKAGE=$PACKAGE" \
	      "LASTVERSION=$LASTVERSION ACTION=$1 PARAM=$2"

	case "$DPKG_MAINTSCRIPT_NAME" in
	preinst)
		if [ "$1" = "install" -o "$1" = "upgrade" ] &&
		   [ -n "$2" ] && [ -h "$SYMLINK" ] &&
		   [ "$(readlink -f $SYMLINK)" = "$SYMLINK_TARGET" ] &&
		   dpkg --compare-versions "$2" le-nl "$LASTVERSION"; then
			mv -f "$SYMLINK" "${SYMLINK}.dpkg-backup"
		fi
		;;
	postinst)
		if [ "$1" = "configure" ] && [ -h "${SYMLINK}.dpkg-backup" ] &&
		    dpkg --compare-versions "$2" le-nl "$LASTVERSION"; then
			rm -f "${SYMLINK}.dpkg-backup"
		fi
		;;
	postrm)
		if [ "$1" = "purge" ] && [ -h "${SYMLINK}.dpkg-backup" ]; then
		    rm -f "${SYMLINK}.dpkg-backup"
		fi
		if [ "$1" = "abort-install" -o "$1" = "abort-upgrade" ] &&
		   [ -n "$2" ] &&
		   [ -h "${SYMLINK}.dpkg-backup" ] && [ ! -e "$SYMLINK" ] &&
		   dpkg --compare-versions "$2" le-nl "$LASTVERSION"; then
			echo "Restoring backup of $SYMLINK ..."
			mv "${SYMLINK}.dpkg-backup" "$SYMLINK"
		fi
		;;
	*)
		debug "$0 symlink_to_dir not required in $DPKG_MAINTSCRIPT_NAME"
		;;
	esac
}

##
## Functions to replace a directory with a symlink
##
dir_to_symlink() {
	local PATHNAME="$1"
	local SYMLINK_TARGET="$2"
	local LASTVERSION="$3"
	local PACKAGE="$4"

	if [ "$LASTVERSION" = "--" ]; then
		LASTVERSION=""
		PACKAGE="$DPKG_MAINTSCRIPT_PACKAGE${DPKG_MAINTSCRIPT_ARCH:+:$DPKG_MAINTSCRIPT_ARCH}"
	fi
	if [ "$PACKAGE" = "--" -o -z "$PACKAGE" ]; then
		PACKAGE="$DPKG_MAINTSCRIPT_PACKAGE${DPKG_MAINTSCRIPT_ARCH:+:$DPKG_MAINTSCRIPT_ARCH}"
	fi

	# Skip remaining parameters up to --
	while [ "$1" != "--" -a $# -gt 0 ]; do shift; done
	[ $# -gt 0 ] || badusage "missing arguments after --"
	shift

	[ -n "$DPKG_MAINTSCRIPT_NAME" ] || \
		error "environment variable DPKG_MAINTSCRIPT_NAME is required"
	[ -n "$PACKAGE" ] || error "cannot identify the package"
	[ -n "$PATHNAME" ] || error "directory parameter is missing"
	[ -n "$SYMLINK_TARGET" ] || error "new symlink target is missing"
	[ -n "$LASTVERSION" ] || error "last version is missing"
	[ -n "$1" ] || error "maintainer script parameters are missing"

	debug "Executing $0 dir_to_symlink in $DPKG_MAINTSCRIPT_NAME" \
	      "of $DPKG_MAINTSCRIPT_PACKAGE"
	debug "PATHNAME=$PATHNAME SYMLINK_TARGET=$SYMLINK_TARGET" \
	      "PACKAGE=$PACKAGE LASTVERSION=$LASTVERSION ACTION=$1 PARAM=$2"

	case "$DPKG_MAINTSCRIPT_NAME" in
	preinst)
		if [ "$1" = "install" -o "$1" = "upgrade" ] &&
		   [ -n "$2" ] && [ -d "$PATHNAME" ] &&
		   dpkg --compare-versions "$2" le-nl "$LASTVERSION"; then
			prepare_dir_to_symlink "$PACKAGE" "$PATHNAME"
		fi
		;;
	postinst)
		if [ "$1" = "configure" ] &&
		   [ -d "${PATHNAME}.dpkg-backup" ] && [ -h "$PATHNAME" ] &&
		   [ "$(readlink -f $PATHNAME)" = "$SYMLINK_TARGET" ] &&
		    dpkg --compare-versions "$2" le-nl "$LASTVERSION"; then
			# By now, dpkg will have updated the symlink to point
			# to the new location, but we are left behind the old
			# files owned by this package in the backup directory,
			# just remove it.
			rm -rf "${PATHNAME}.dpkg-backup"
		fi
		;;
	postrm)
		if [ "$1" = "purge" ] && [ -d "${PATHNAME}.dpkg-backup" ]; then
		    rm -rf "${PATHNAME}.dpkg-backup"
		fi
		if [ "$1" = "abort-install" -o "$1" = "abort-upgrade" ] &&
		   [ -n "$2" ] &&
		   [ -d "${PATHNAME}.dpkg-backup" ] && [ -h "$PATHNAME" ] &&
		   [ "$(readlink -f $PATHNAME)" = "$SYMLINK_TARGET" ] &&
		   dpkg --compare-versions "$2" le-nl "$LASTVERSION"; then
			echo "Restoring backup of $PATHNAME ..."
			rm -f "$PATHNAME"
			mv "${PATHNAME}.dpkg-backup" "$PATHNAME"
		fi
		;;
	*)
		debug "$0 dir_to_symlink not required in $DPKG_MAINTSCRIPT_NAME"
		;;
	esac
}

prepare_dir_to_symlink()
{
	local PACKAGE="$1"
	local PATHNAME="$2"

	# If there are conffiles we should not perform the switch.
	if dpkg-query -W -f='${Conffiles}' "$PACKAGE" | \
	   grep -q "$PATHNAME/."; then
		error "directory '$PATHNAME' contains conffiles," \
		      "cannot switch to symlink"
	fi

	# If there are locally created files or files owned by another package
	# we should not perform the switch.
	find "$PATHNAME" -print0 | xargs -0 -n1 sh -c '
		package="$1"
		file="$2"
		if ! dpkg-query -L "$package" | grep -q -x "$file"; then
			return 1
		fi
		return 0
	' subcommand "$PACKAGE" || \
		error "directory '$PATHNAME' contains files not owned by" \
		      "package $PACKAGE, cannot switch to symlink"

	# Move the directory aside and make a temporary symlink to reduce the
	# time the contents are not available. dpkg will not be able to remove
	# the old files from the backup directory after unpack, because it
	# will have updated the symlink to point to the new location already,
	# we'll remove them ourselves later on.
	mv -f "$PATHNAME" "${PATHNAME}.dpkg-backup"
	ln -s "${PATHNAME}.dpkg-backup" "$PATHNAME"
}

# Common functions
ensure_package_owns_file() {
	local PACKAGE="$1"
	local FILE="$2"

	if ! dpkg-query -L "$PACKAGE" | grep -q -x "$FILE"; then
		debug "File '$FILE' not owned by package " \
		      "'$PACKAGE', skipping $command"
		return 1
	fi
	return 0
}

debug() {
	if [ -n "$DPKG_DEBUG" ]; then
		echo "DEBUG: $PROGNAME: $*" >&2
	fi
}

error() {
	echo "$PROGNAME: error: $*" >&2
	exit 1
}

warning() {
	echo "$PROGNAME: warning: $*" >&2
}

usage() {
	cat <<END
Usage: $PROGNAME <command> <parameter>... -- <maintainer-script-parameter>...

Commands:
  supports <command>
	Returns 0 (success) if the given command is supported, 1 otherwise.
  rm_conffile <conffile> [<last-version> [<package>]]
	Remove obsolete conffile. Must be called in preinst, postinst and
	postrm.
  mv_conffile <old-conf> <new-conf> [<last-version> [<package>]]
	Rename a conffile. Must be called in preinst, postinst and postrm.
  symlink_to_dir <pathname> <old-symlink-target> [<last-version> [<package>]]
	Replace a symlink with a directory. Must be called in preinst,
	postinst and postrm.
  dir_to_symlink <pathname> <new-symlink-target> [<last-version> [<package>]]
	Replace a directory with a symlink. Must be called in preinst,
	postinst and postrm.
  help
	Display this usage information.
END
}

badusage() {
	echo "$PROGNAME: error: $1" >&2
	echo >&2
	echo "Use '$PROGNAME help' for program usage information." >&2
	exit 1
}

# Main code
set -e

PROGNAME=$(basename $0)
version="unknown"
command="$1"
[ $# -gt 0 ] || badusage "missing command"
shift

case "$command" in
supports)
	case "$1" in
	rm_conffile|mv_conffile|symlink_to_dir|dir_to_symlink)
		code=0
		;;
	*)
		code=1
		;;
	esac
	if [ -z "$DPKG_MAINTSCRIPT_NAME" ]; then
		warning "environment variable DPKG_MAINTSCRIPT_NAME missing"
		code=1
	fi
	if [ -z "$DPKG_MAINTSCRIPT_PACKAGE" ]; then
		warning "environment variable DPKG_MAINTSCRIPT_PACKAGE missing"
		code=1
	fi
	exit $code
	;;
rm_conffile)
	rm_conffile "$@"
	;;
mv_conffile)
	mv_conffile "$@"
	;;
symlink_to_dir)
	symlink_to_dir "$@"
	;;
dir_to_symlink)
	dir_to_symlink "$@"
	;;
--help|help|-?)
	usage
	;;
--version)
	cat <<-END
	Debian $PROGNAME version $version.

	This is free software; see the GNU General Public License version 2 or
	later for copying conditions. There is NO warranty.
	END
	;;
*)
	badusage "command $command is unknown
Hint: upgrading dpkg to a newer version might help."
esac

exit 0
