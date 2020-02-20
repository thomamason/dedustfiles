###
# Copyright (c) 2015-2019, Antoine "vv221/vv222" Le Gonidec
# Copyright (c) 2016-2019, Solène "Mopi" Huault
# Copyright (c) 2017-2019, Phil Morrell
# Copyright (c) 2017-2019, Jacek Szafarkiewicz
# Copyright (c) 2018-2019, VA
# Copyright (c) 2018-2019, Janeene "dawnmist" Beeforth
# Copyright (c) 2018-2019, BetaRays
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# This software is provided by the copyright holders and contributors "as is"
# and any express or implied warranties, including, but not limited to, the
# implied warranties of merchantability and fitness for a particular purpose
# are disclaimed. In no event shall the copyright holder or contributors be
# liable for any direct, indirect, incidental, special, exemplary, or
# consequential damages (including, but not limited to, procurement of
# substitute goods or services; loss of use, data, or profits; or business
# interruption) however caused and on any theory of liability, whether in
# contract, strict liability, or tort (including negligence or otherwise)
# arising in any way out of the use of this software, even if advised of the
# possibility of such damage.
###

###
# common functions for ./play.it scripts
# send your bug reports to vv221@dotslashplay.it
###

library_version=2.11.2
# shellcheck disable=SC2034
library_revision=20190424.2

# set package distribution-specific architecture
# USAGE: set_architecture $pkg
# CALLS: liberror set_architecture_arch set_architecture_deb set_architecture_gentoo
# NEEDED VARS: (ARCHIVE) (OPTION_PACKAGE) (PKG_ARCH)
# CALLED BY: set_temp_directories write_metadata
set_architecture() {
	use_archive_specific_value "${1}_ARCH"
	local architecture
	architecture="$(get_value "${1}_ARCH")"
	case $OPTION_PACKAGE in
		('arch')
			set_architecture_arch "$architecture"
		;;
		('deb')
			set_architecture_deb "$architecture"
		;;
		('gentoo')
			set_architecture_gentoo "$architecture"
		;;
		(*)
			liberror 'OPTION_PACKAGE' 'set_architecture'
		;;
	esac
}

# set package distribution-specific architectures
# USAGE: set_supported_architectures $pkg
# CALLS: liberror set_architecture set_architecture_gentoo
# NEEDED VARS: (ARCHIVE) (OPTION_PACKAGE) (PKG_ARCH)
# CALLED BY: write_bin write_bin_set_native_noprefix write_metadata_gentoo
set_supported_architectures() {
	case $OPTION_PACKAGE in
		('arch'|'deb')
			set_architecture "$1"
		;;
		('gentoo')
			use_archive_specific_value "${1}_ARCH"
			local architecture
			architecture="$(get_value "${1}_ARCH")"
			set_supported_architectures_gentoo "$architecture"
		;;
		(*)
			liberror 'OPTION_PACKAGE' 'set_supported_architectures'
		;;
	esac
}

# test the validity of the argument given to parent function
# USAGE: testvar $var_name $pattern
testvar() {
	test "${1%%_*}" = "$2"
}

# set defaults rights on files (755 for dirs & 644 for regular files)
# USAGE: set_standard_permissions $dir[…]
set_standard_permissions() {
	[ "$DRY_RUN" = '1' ] && return 0
	for dir in "$@"; do
		[  -d "$dir" ] || return 1
		find "$dir" -type d -exec chmod 755 '{}' +
		find "$dir" -type f -exec chmod 644 '{}' +
	done
}

# print OK
# USAGE: print_ok
print_ok() {
	printf '\t\033[1;32mOK\033[0m\n'
}

# print a localized error message
# USAGE: print_error
# NEEDED VARS: (LANG)
print_error() {
	local string
	case "${LANG%_*}" in
		('fr')
			string='Erreur :'
		;;
		('en'|*)
			string='Error:'
		;;
	esac
	printf '\n\033[1;31m%s\033[0m\n' "$string"
	exec 1>&2
}

# print a localized warning message
# USAGE: print_warning
# NEEDED VARS: (LANG)
print_warning() {
	local string
	case "${LANG%_*}" in
		('fr')
			string='Avertissement :'
		;;
		('en'|*)
			string='Warning:'
		;;
	esac
	printf '\n\033[1;33m%s\033[0m\n' "$string"
}

# convert files name to lower case
# USAGE: tolower $dir[…]
tolower() {
	[ "$DRY_RUN" = '1' ] && return 0
	for dir in "$@"; do
		[ -d "$dir" ] || return 1
		find "$dir" -depth -mindepth 1 | while read -r file; do
			newfile="${file%/*}/$(printf '%s' "${file##*/}" | tr '[:upper:]' '[:lower:]')"
			[ -e "$newfile" ] || mv "$file" "$newfile"
		done
	done
}

# display an error if a function has been called with invalid arguments
# USAGE: liberror $var_name $calling_function
# NEEDED VARS: (LANG)
liberror() {
	local var
	var="$1"
	local value
	value="$(get_value "$var")"
	local func
	func="$2"
	print_error
	case "${LANG%_*}" in
		('fr')
			string='Valeur incorrecte pour %s appelée par %s : %s\n'
		;;
		('en'|*)
			string='Invalid value for %s called by %s: %s\n'
		;;
	esac
	printf "$string" "$var" "$func" "$value"
	return 1
}

# get archive-specific value for a given variable name, or use default value
# USAGE: use_archive_specific_value $var_name
use_archive_specific_value() {
	[ -n "$ARCHIVE" ] || return 0
	testvar "$ARCHIVE" 'ARCHIVE' || liberror 'ARCHIVE' 'use_archive_specific_value'
	local name_real
	name_real="$1"
	local name
	name="${name_real}_${ARCHIVE#ARCHIVE_}"
	local value
	while [ "$name" != "$name_real" ]; do
		value="$(get_value "$name")"
		if [ -n "$value" ]; then
			export ${name_real?}="$value"
			return 0
		fi
		name="${name%_*}"
	done
}

# get package-specific value for a given variable name, or use default value
# USAGE: use_package_specific_value $var_name
use_package_specific_value() {
	[ -n "$PKG" ] || return 0
	testvar "$PKG" 'PKG' || liberror 'PKG' 'use_package_specific_value'
	local name_real
	name_real="$1"
	local name
	name="${name_real}_${PKG#PKG_}"
	local value
	while [ "$name" != "$name_real" ]; do
		value="$(get_value "$name")"
		if [ -n "$value" ]; then
			export ${name_real?}="$value"
			return 0
		fi
		name="${name%_*}"
	done
}

# display an error when PKG value seems invalid
# USAGE: missing_pkg_error $function_name $PKG
# NEEDED VARS: (LANG)
missing_pkg_error() {
	local string
	case "${LANG%_*}" in
		('fr')
			string='La valeur de PKG fournie à %s semble incorrecte : %s\n'
		;;
		('en'|*)
			string='The PKG value used by %s seems erroneous: %s\n'
		;;
	esac
	printf "$string" "$1" "$2"
	exit 1
}

# display a warning when PKG value is not included in PACKAGES_LIST
# USAGE: skipping_pkg_warning $function_name $PKG
# NEEDED VARS: (LANG)
skipping_pkg_warning() {
	local string
	print_warning
	case "${LANG%_*}" in
		('fr')
			string='La valeur de PKG fournie à %s ne fait pas partie de la liste de paquets à construire : %s\n'
		;;
		('en'|*)
			string='The PKG value used by %s is not part of the list of packages to build: %s\n'
		;;
	esac
	printf "$string" "$1" "$2"
}

# get the value of a variable and print it
# USAGE: get_value $variable_name
get_value() {
	local name
	local value
	name="$1"
	value="$(eval printf -- '%b' \"\$$name\")"
	printf '%s' "$value"
}
# set distribution-specific package architecture for Arch Linux target
# USAGE: set_architecture_arch $architecture
# CALLED BY: set_architecture
set_architecture_arch() {
	case "$1" in
		('32'|'64')
			pkg_architecture='x86_64'
		;;
		(*)
			pkg_architecture='any'
		;;
	esac
}

# set distribution-specific package architecture for Debian target
# USAGE: set_architecture_deb $architecture
# CALLED BY: set_architecture
set_architecture_deb() {
	case "$1" in
		('32')
			pkg_architecture='i386'
		;;
		('64')
			pkg_architecture='amd64'
		;;
		(*)
			pkg_architecture='all'
		;;
	esac
}

# set distribution-specific package architecture for Gentoo Linux target
# Usage set_architecture_gentoo $architecture
# CALLED BY: set_architecture
set_architecture_gentoo() {
	case "$1" in
		('32')
			pkg_architecture='x86'
		;;
		('64')
			pkg_architecture='amd64'
		;;
		(*)
			pkg_architecture='data' # We could put anything here, it shouldn't be used for package metadata
		;;
	esac
}
# set distribution-specific supported architectures for Gentoo Linux target
# Usage set_supported_architectures_gentoo $architecture
# CALLED BY: set_supported_architectures
set_supported_architectures_gentoo() {
	case "$1" in
		('32')
			pkg_architectures='-* x86 amd64'
		;;
		('64')
			pkg_architectures='-* amd64'
		;;
		(*)
			pkg_architectures='x86 amd64' #data packages
		;;
	esac
}
# set main archive for data extraction
# USAGE: archive_set_main $archive[…]
# CALLS: archive_set archive_set_error_not_found
archive_set_main() {
	archive_set 'SOURCE_ARCHIVE' "$@"
	[ -n "$SOURCE_ARCHIVE" ] || archive_set_error_not_found "$@"
}

# display an error message if a required archive is not found
# list all the archives that could fulfill the requirements, with their download URL if provided by the script
# USAGE: archive_set_error_not_found $archive[…]
# CALLED BY: archive_set_main
archive_set_error_not_found() {
	local archive
	local archive_name
	local archive_url
	local string
	local string_multiple
	local string_single
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string_multiple='Aucun des fichiers suivants n’est présent :'
			string_single='Le fichier suivant est introuvable :'
		;;
		('en'|*)
			string_multiple='None of the following files could be found:'
			string_single='The following file could not be found:'
		;;
	esac
	if [ "$#" = 1 ]; then
		string="$string_single"
	else
		string="$string_multiple"
	fi
	print_error
	printf '%s\n' "$string"
	for archive in "$@"; do
		archive_name="$(get_value "$archive")"
		archive_url="$(get_value "${archive}_URL")"
		printf '%s' "$archive_name"
		[ -n "$archive_url" ] && printf ' — %s' "$archive_url"
		printf '\n'
	done
	return 1
}

# set a single archive for data extraction
# USAGE: archive_set $name $archive[…]
# CALLS: archive_get_infos archive_check_for_extra_parts
archive_set() {
	local archive
	local current_value
	local file
	local name
	name=$1
	shift 1
	current_value="$(get_value "$name")"
	if [ -n "$current_value" ]; then
		for archive in "$@"; do
			file="$(get_value "$archive")"
			if [ "$(basename "$current_value")" = "$file" ]; then
				archive_get_infos "$archive" "$name" "$current_value"
				archive_check_for_extra_parts "$archive" "$name"
				ARCHIVE="$archive"
				export ARCHIVE
				return 0
			fi
		done
	else
		for archive in "$@"; do
			file="$(get_value "$archive")"
			if [ ! -f "$file" ] && [ -n "$SOURCE_ARCHIVE" ] && [ -f "${SOURCE_ARCHIVE%/*}/$file" ]; then
				file="${SOURCE_ARCHIVE%/*}/$file"
			fi
			if [ -f "$file" ]; then
				archive_get_infos "$archive" "$name" "$file"
				archive_check_for_extra_parts "$archive" "$name"
				ARCHIVE="$archive"
				export ARCHIVE
				return 0
			fi
		done
	fi
	unset $name
}

# automatically check for presence of archives using the name of the base archive with a _PART1 to _PART9 suffix appended
# returns an error if such an archive is set by the script but not found
# returns success on the first archive not set by the script
# USAGE: archive_check_for_extra_parts $archive $name
# NEEDED_VARS: (LANG) (SOURCE_ARCHIVE)
# CALLS: set_archive
archive_check_for_extra_parts() {
	local archive
	local file
	local name
	local part_archive
	local part_name
	archive="$1"
	name="$2"
	for i in $(seq 1 9); do
		part_archive="${archive}_PART${i}"
		part_name="${name}_PART${i}"
		file="$(get_value "$part_archive")"
		[ -n "$file" ] || return 0
		set_archive "$part_name" "$part_archive"
		if [ -z "$(get_value "$part_name")" ]; then
			set_archive_error_not_found "$part_archive"
		fi
	done
}

# get informations about a single archive and export them
# USAGE: archive_get_infos $archive $name $file
# CALLS: archive_guess_type archive_integrity_check archive_print_file_in_use check_deps
# CALLED BY: archive_set
archive_get_infos() {
	local file
	local md5
	local name
	local size
	local type
	ARCHIVE="$1"
	name="$2"
	file="$3"
	archive_print_file_in_use "$file"
	eval $name=\"$file\"
	md5="$(get_value "${ARCHIVE}_MD5")"
	type="$(get_value "${ARCHIVE}_TYPE")"
	size="$(get_value "${ARCHIVE}_SIZE")"
	[ -n "$md5" ] && archive_integrity_check "$ARCHIVE" "$file"
	if [ -z "$type" ]; then
		archive_guess_type "$ARCHIVE" "$file"
		type="$(get_value "${ARCHIVE}_TYPE")"
	fi
	eval ${name}_TYPE=\"$type\"
	export ${name?}_TYPE
	check_deps
	if [ -n "$size" ]; then
		[ -n "$ARCHIVE_SIZE" ] || ARCHIVE_SIZE='0'
		ARCHIVE_SIZE="$((ARCHIVE_SIZE + size))"
	fi
	export ARCHIVE_SIZE
	export PKG_VERSION
	export ${name?}
	export ARCHIVE
}

# try to guess archive type from file name
# USAGE: archive_guess_type $archive $file
# CALLS: archive_guess_type_error
# CALLED BY: archive_get_infos
archive_guess_type() {
	local archive
	local file
	local type
	archive="$1"
	file="$2"
	case "${file##*/}" in
		(*'.cab')
			type='cabinet'
		;;
		(*'.deb')
			type='debian'
		;;
		('setup_'*'.exe'|'patch_'*'.exe')
			type='innosetup'
		;;
		('gog_'*'.sh')
			type='mojosetup'
		;;
		(*'.iso')
			type='iso'
		;;
		(*'.msi')
			type='msi'
		;;
		(*'.rar')
			type='rar'
		;;
		(*'.tar')
			type='tar'
		;;
		(*'.tar.gz'|*'.tgz')
			type='tar.gz'
		;;
		(*'.zip')
			type='zip'
		;;
		(*'.7z')
			type='7z'
		;;
		(*)
			archive_guess_type_error "$archive"
		;;
	esac
	eval ${archive}_TYPE=\'$type\'
	export ${archive?}_TYPE
}

# display an error message if archive_guess_type failed to guess the type of an archive
# USAGE: archive_guess_type_error $archive
# CALLED BY: archive_guess_type
archive_guess_type_error() {
	local string
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='ARCHIVE_TYPE n’est pas défini pour %s et n’a pas pu être détecté automatiquement.'
		;;
		('en'|*)
			string='ARCHIVE_TYPE is not set for %s and could not be guessed.'
		;;
	esac
	print_error
	printf "$string\\n" "$archive"
	return 1
}

# print the name and path to the archive currently in use
# USAGE: archive_print_file_in_use $file
# CALLED BY: archive_get_infos
archive_print_file_in_use() {
	local file
	local string
	file="$1"
	case "${LANG%_*}" in
		('fr')
			string='Utilisation de %s'
		;;
		('en'|*)
			string='Using %s'
		;;
	esac
	printf "$string\\n" "$file"
}

# check integrity of target file
# USAGE: archive_integrity_check $archive $file
# CALLS: archive_integrity_check_md5 liberror
archive_integrity_check() {
	local archive
	local file
	archive="$1"
	file="$2"
	case "$OPTION_CHECKSUM" in
		('md5')
			archive_integrity_check_md5 "$archive" "$file"
			print_ok
		;;
		('none')
			return 0
		;;
		(*)
			liberror 'OPTION_CHECKSUM' 'archive_integrity_check'
		;;
	esac
}

# check integrity of target file against MD5 control sum
# USAGE: archive_integrity_check_md5 $archive $file
# CALLS: archive_integrity_check_print archive_integrity_check_error
# CALLED BY: archive_integrity_check
archive_integrity_check_md5() {
	local archive
	local file
	archive="$1"
	file="$2"
	archive_integrity_check_print "$file"
	archive_sum="$(get_value "${ARCHIVE}_MD5")"
	file_sum="$(md5sum "$file" | awk '{print $1}')"
	[ "$file_sum" = "$archive_sum" ] || archive_integrity_check_error "$file"
}

# print integrity check message
# USAGE: archive_integrity_check_print $file
# CALLED BY: archive_integrity_check_md5
archive_integrity_check_print() {
	local file
	local string
	file="$1"
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='Contrôle de l’intégrité de %s'
		;;
		('en'|*)
			string='Checking integrity of %s'
		;;
	esac
	printf "$string" "$(basename "$file")"
}

# print an error message if an integrity check fails
# USAGE: archive_integrity_check_error $file
# CALLED BY: archive_integrity_check_md5
archive_integrity_check_error() {
	local string1
	local string2
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string1='Somme de contrôle incohérente. %s n’est pas le fichier attendu.'
			string2='Utilisez --checksum=none pour forcer son utilisation.'
		;;
		('en'|*)
			string1='Hashsum mismatch. %s is not the expected file.'
			string2='Use --checksum=none to force its use.'
		;;
	esac
	print_error
	printf "$string1\\n" "$(basename "$1")"
	printf "$string2\\n"
	return 1
}

# get list of available archives, exported as ARCHIVES_LIST
# USAGE: archives_get_list
archives_get_list() {
	local script
	[ -n "$ARCHIVES_LIST" ] && return 0
	script="$0"
	while read -r archive; do
		if [ -z "$ARCHIVES_LIST" ]; then
			ARCHIVES_LIST="$archive"
		else
			ARCHIVES_LIST="$ARCHIVES_LIST $archive"
		fi
	done <<- EOL
	$(grep --regexp='^ARCHIVE_[^_]\+=' --regexp='^ARCHIVE_[^_]\+_OLD=' --regexp='^ARCHIVE_[^_]\+_OLD[^_]\+=' "$script" | sed 's/\([^=]\)=.\+/\1/')
	EOL
	export ARCHIVES_LIST
}

# check script dependencies
# USAGE: check_deps
# NEEDED VARS: (ARCHIVE) (ARCHIVE_TYPE) (OPTION_CHECKSUM) (OPTION_PACKAGE) (SCRIPT_DEPS)
# CALLS: check_deps_7z check_deps_error_not_found icons_list_dependencies
check_deps() {
	icons_list_dependencies
	if [ "$ARCHIVE" ]; then
		case "$(get_value "${ARCHIVE}_TYPE")" in
			('cabinet')
				SCRIPT_DEPS="$SCRIPT_DEPS cabextract"
			;;
			('debian')
				SCRIPT_DEPS="$SCRIPT_DEPS dpkg"
			;;
			('innosetup1.7'*)
				SCRIPT_DEPS="$SCRIPT_DEPS innoextract1.7"
			;;
			('innosetup'*)
				SCRIPT_DEPS="$SCRIPT_DEPS innoextract"
			;;
			('nixstaller')
				SCRIPT_DEPS="$SCRIPT_DEPS gzip tar unxz"
			;;
			('msi')
				SCRIPT_DEPS="$SCRIPT_DEPS msiextract"
			;;
			('mojosetup'|'iso')
				SCRIPT_DEPS="$SCRIPT_DEPS bsdtar"
			;;
			('rar'|'nullsoft-installer')
				SCRIPT_DEPS="$SCRIPT_DEPS unar"
			;;
			('tar')
				SCRIPT_DEPS="$SCRIPT_DEPS tar"
			;;
			('tar.gz')
				SCRIPT_DEPS="$SCRIPT_DEPS gzip tar"
			;;
			('zip'|'zip_unclean'|'mojosetup_unzip')
				SCRIPT_DEPS="$SCRIPT_DEPS unzip"
			;;
		esac
	fi
	if [ "$OPTION_CHECKSUM" = 'md5sum' ]; then
		SCRIPT_DEPS="$SCRIPT_DEPS md5sum"
	fi
	if [ "$OPTION_PACKAGE" = 'deb' ]; then
		SCRIPT_DEPS="$SCRIPT_DEPS fakeroot dpkg"
	fi
	if [ "$OPTION_PACKAGE" = 'gentoo' ]; then
		# fakeroot doesn't work for me, only fakeroot-ng does
		SCRIPT_DEPS="$SCRIPT_DEPS fakeroot-ng ebuild"
	fi
	for dep in $SCRIPT_DEPS; do
		case $dep in
			('7z')
				check_deps_7z
			;;
			('innoextract'*)
				check_deps_innoextract "$dep"
			;;
			(*)
				if ! command -v "$dep" >/dev/null 2>&1; then
					check_deps_error_not_found "$dep"
				fi
			;;
		esac
	done
}

# check presence of a software to handle .7z archives
# USAGE: check_deps_7z
# CALLS: check_deps_error_not_found
# CALLED BY: check_deps
check_deps_7z() {
	if command -v 7zr >/dev/null 2>&1; then
		extract_7z() { 7zr x -o"$2" -y "$1"; }
	elif command -v 7za >/dev/null 2>&1; then
		extract_7z() { 7za x -o"$2" -y "$1"; }
	elif command -v unar >/dev/null 2>&1; then
		extract_7z() { unar -output-directory "$2" -force-overwrite -no-directory "$1"; }
	else
		check_deps_error_not_found 'p7zip'
	fi
}

# check innoextract presence, optionally in a given minimum version
# USAGE: check_deps_innoextract $keyword
# CALLS: check_deps_error_not_found
# CALLED BYD: check_deps
check_deps_innoextract() {
	local keyword
	local name
	local version
	local version_major
	local version_minor
	keyword="$1"
	case "$keyword" in
		('innoextract1.7')
			name='innoextract (>= 1.7)'
		;;
		(*)
			name='innoextract'
		;;
	esac
	if ! command -v 'innoextract' >/dev/null 2>&1; then
		check_deps_error_not_found "$name"
	fi
	version="$(innoextract --version | head --lines=1 | cut --delimiter=' ' --fields=2)"
	version_minor="${version#*.}"
	version_major="${version%.*}"
	case "$keyword" in
		('innoextract1.7')
			if
				[ "$version_major" -lt 1 ] || \
				[ "$version_major" -lt 2 ] && [ "$version_minor" -lt 7 ]
			then
				check_deps_error_not_found "$name"
			fi
		;;
	esac
	return 0
}

# display a message if a required dependency is missing
# USAGE: check_deps_error_not_found $command_name
# CALLED BY: check_deps check_deps_7z
check_deps_error_not_found() {
	print_error
	case "${LANG%_*}" in
		('fr')
			string='%s est introuvable. Installez-le avant de lancer ce script.\n'
		;;
		('en'|*)
			string='%s not found. Install it before running this script.\n'
		;;
	esac
	printf "$string" "$1"
	return 1
}

# display script usage
# USAGE: help
# NEEDED VARS: (LANG)
# CALLS: help_checksum help_compression help_prefix help_package help_dryrun help_skipfreespacecheck
help() {
	local format
	local string
	local string_archive
	case "${LANG%_*}" in
		('fr')
			string='Utilisation :'
			# shellcheck disable=SC1112
			string_archive='Ce script reconnaît l’archive suivante :'
			string_archives='Ce script reconnaît les archives suivantes :'
		;;
		('en'|*)
			string='Usage:'
			string_archive='This script can work on the following archive:'
			string_archives='This script can work on the following archives:'
		;;
	esac
	printf '\n'
	if [ "${0##*/}" = 'play.it' ]; then
		format='%s %s ARCHIVE [OPTION]…\n\n'
	else
		format='%s %s [OPTION]… [ARCHIVE]\n\n'
	fi
	printf "$format" "$string" "${0##*/}"
	
	printf 'OPTIONS\n\n'
	help_architecture
	printf '\n'
	help_checksum
	printf '\n'
	help_compression
	printf '\n'
	help_prefix
	printf '\n'
	help_package
	printf '\n'
	help_dryrun
	printf '\n'
	help_skipfreespacecheck
	printf '\n'

	printf 'ARCHIVE\n\n'
	archives_get_list
	if [ -n "${ARCHIVES_LIST##* *}" ]; then
		printf '%s\n' "$string_archive"
	else
		printf '%s\n' "$string_archives"
	fi
	for archive in $ARCHIVES_LIST; do
		printf '%s\n' "$(get_value "$archive")"
	done
	printf '\n'
}

# display --architecture option usage
# USAGE: help_architecture
# NEEDED VARS: (LANG)
# CALLED BY: help
help_architecture() {
	local string
	local string_all
	local string_32
	local string_64
	local string_auto
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='Choix de l’architecture à construire'
			string_all='toutes les architectures disponibles (méthode par défaut)'
			string_32='paquets 32-bit seulement'
			string_64='paquets 64-bit seulement'
			# shellcheck disable=SC1112
			string_auto='paquets pour l’architecture du système courant uniquement'
		;;
		('en'|*)
			string='Target architecture choice'
			string_all='all available architectures (default method)'
			string_32='32-bit packages only'
			string_64='64-bit packages only'
			string_auto='packages for current system architecture only'
		;;
	esac
	printf -- '--architecture=all|32|64|auto\n'
	printf -- '--architecture all|32|64|auto\n\n'
	printf '\t%s\n\n' "$string"
	printf '\tall\t%s\n' "$string_all"
	printf '\t32\t%s\n' "$string_32"
	printf '\t64\t%s\n' "$string_64"
	printf '\tauto\t%s\n' "$string_auto"
}

# display --checksum option usage
# USAGE: help_checksum
# NEEDED VARS: (LANG)
# CALLED BY: help
help_checksum() {
	local string
	local string_md5
	local string_none
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='Choix de la méthode de vérification d’intégrité de l’archive'
			string_md5='vérification via md5sum (méthode par défaut)'
			string_none='pas de vérification'
		;;
		('en'|*)
			string='Archive integrity verification method choice'
			string_md5='md5sum verification (default method)'
			string_none='no verification'
		;;
	esac
	printf -- '--checksum=md5|none\n'
	printf -- '--checksum md5|none\n\n'
	printf '\t%s\n\n' "$string"
	printf '\tmd5\t%s\n' "$string_md5"
	printf '\tnone\t%s\n' "$string_none"
}

# display --compression option usage
# USAGE: help_compression
# NEEDED VARS: (LANG)
# CALLED BY: help
help_compression() {
	local string
	local string_none
	local string_gzip
	local string_xz
	case "${LANG%_*}" in
		('fr')
			string='Choix de la méthode de compression des paquets générés'
			string_none='pas de compression (méthode par défaut)'
			string_gzip='compression gzip (rapide)'
			string_xz='compression xz (plus lent mais plus efficace que gzip)'
			string_bzip2='compression bzip2'
		;;
		('en'|*)
			string='Generated packages compression method choice'
			string_none='no compression (default method)'
			string_gzip='gzip compression (fast)'
			string_xz='xz compression (slower but more efficient than gzip)'
			string_bzip2='bzip2 compression'
		;;
	esac
	printf -- '--compression=none|gzip|xz|bzip2\n'
	printf -- '--compression none|gzip|xz|bzip2\n\n'
	printf '\t%s\n\n' "$string"
	printf '\tnone\t%s\n' "$string_none"
	printf '\tgzip\t%s\n' "$string_gzip"
	printf '\txz\t%s\n' "$string_xz"
	printf '\tbzip2\t%s\n' "$string_bzip2"
}

# display --prefix option usage
# USAGE: help_prefix
# NEEDED VARS: (LANG)
# CALLED BY: help
help_prefix() {
	local string
	local string_absolute
	local string_default
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='Choix du chemin d’installation du jeu'
			string_absolute='Cette option accepte uniquement un chemin absolu.'
			string_default='chemin par défaut :'
		;;
		('en'|*)
			string='Game installation path choice'
			string_absolute='This option accepts an absolute path only.'
			string_default='default path:'
		;;
	esac
	printf -- '--prefix=$path\n'
	printf -- '--prefix $path\n\n'
	printf '\t%s\n\n' "$string"
	printf '\t%s\n' "$string_absolute"
	printf '\t%s /usr/local\n' "$string_default"
}

# display --package option usage
# USAGE: help_package
# NEEDED VARS: (LANG)
# CALLED BY: help
help_package() {
	local string
	local string_default
	local string_arch
	local string_deb
	local string_gentoo
	case "${LANG%_*}" in
		('fr')
			string='Choix du type de paquet à construire'
			string_default='(type par défaut)'
			string_arch='paquet .pkg.tar (Arch Linux)'
			string_deb='paquet .deb (Debian, Ubuntu)'
			string_gentoo='paquet .tbz2 (Gentoo)'
		;;
		('en'|*)
			string='Generated package Type choice'
			string_default='(default type)'
			string_arch='.pkg.tar package (Arch Linux)'
			string_deb='.deb package (Debian, Ubuntu)'
			string_gentoo='.tbz2 package (Gentoo)'
		;;
	esac
	printf -- '--package=arch|deb|gentoo\n'
	printf -- '--package arch|deb|gentoo\n\n'
	printf '\t%s\n\n' "$string"
	printf '\tarch\t%s' "$string_arch"
	[ "$DEFAULT_OPTION_PACKAGE" = 'arch' ] && printf ' %s\n' "$string_default" || printf '\n'
	printf '\tdeb\t%s' "$string_deb"
	[ "$DEFAULT_OPTION_PACKAGE" = 'deb' ] && printf ' %s\n' "$string_default" || printf '\n'
	printf '\tgentoo\t%s' "$string_gentoo"
	[ "$DEFAULT_OPTION_PACKAGE" = 'gentoo' ] && printf ' %s\n' "$string_default" || printf '\n'
}

# display --dry-run option usage
# USAGE: help_dryrun
# NEEDED VARS: (LANG)
# CALLED BY: help
help_dryrun() {
	local string
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='Effectue des tests de syntaxe mais n’extrait pas de données et ne construit pas de paquets.'
		;;
		('en'|*)
			string='Run syntax checks but do not extract data nor build packages.'
		;;
	esac
	printf -- '--dry-run\n\n'
	printf '\t%s\n\n' "$string"
}

# display --skip-free-space-check option usage
# USAGE: help_skipfreespacecheck
# NEEDED VARS: (LANG)
# CALLED BY: help
help_skipfreespacecheck() {
	local string
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='Ne teste pas l’espace libre disponible. Les répertoires temporaires seront créés sous $TMPDIR, ou /tmp par défaut.'
		;;
		('en'|*)
			string='Do not check for free space. Temporary directories are created under $TMPDIR, or /tmp by default.'
		;;
	esac
	printf -- '--skip-free-space-check\n\n'
	printf '\t%s\n\n' "$string"
}

# select package architecture to build
# USAGE: select_package_architecture
# NEEDED_VARS: OPTION_ARCHITECTURE PACKAGES_LIST
# CALLS: select_package_architecture_warning_unavailable select_package_architecture_error_unknown select_package_architecture_warning_unsupported
select_package_architecture() {
	[ "$OPTION_ARCHITECTURE" = 'all' ] && return 0
	local version_major_target
	local version_minor_target
	# shellcheck disable=SC2154
	version_major_target="${target_version%%.*}"
	# shellcheck disable=SC2154
	version_minor_target=$(printf '%s' "$target_version" | cut --delimiter='.' --fields=2)
	if [ $version_major_target -lt 2 ] || [ $version_minor_target -lt 6 ]; then
		select_package_architecture_warning_unsupported
		OPTION_ARCHITECTURE='all'
		export OPTION_ARCHITECTURE
		return 0
	fi
	if [ "$OPTION_ARCHITECTURE" = 'auto' ]; then
		case "$(uname --machine)" in
			('i686')
				OPTION_ARCHITECTURE='32'
			;;
			('x86_64')
				OPTION_ARCHITECTURE='64'
			;;
			(*)
				select_package_architecture_warning_unknown
				OPTION_ARCHITECTURE='all'
				export OPTION_ARCHITECTURE
				return 0
			;;
		esac
		export OPTION_ARCHITECTURE
		select_package_architecture
		return 0
	fi
	local package_arch
	local packages_list_32
	local packages_list_64
	local packages_list_all
	for package in $PACKAGES_LIST; do
		package_arch="$(get_value "${package}_ARCH")"
		case "$package_arch" in
			('32')
				packages_list_32="$packages_list_32 $package"
			;;
			('64')
				packages_list_64="$packages_list_64 $package"
			;;
			(*)
				packages_list_all="$packages_list_all $package"
			;;
		esac
	done
	case "$OPTION_ARCHITECTURE" in
		('32')
			if [ -z "$packages_list_32" ]; then
				select_package_architecture_warning_unavailable
				OPTION_ARCHITECTURE='all'
				return 0
			fi
			PACKAGES_LIST="$packages_list_32 $packages_list_all"
		;;
		('64')
			if [ -z "$packages_list_64" ]; then
				select_package_architecture_warning_unavailable
				OPTION_ARCHITECTURE='all'
				return 0
			fi
			PACKAGES_LIST="$packages_list_64 $packages_list_all"
		;;
		(*)
			select_package_architecture_error_unknown
		;;
	esac
	export PACKAGES_LIST
}

# display an error if selected architecture is not available
# USAGE: select_package_architecture_warning_unavailable
# NEEDED_VARS: (LANG) OPTION_ARCHITECTURE
# CALLED_BY: select_package_architecture
select_package_architecture_warning_unavailable() {
	local string
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='L’architecture demandée n’est pas disponible : %s\n'
		;;
		('en'|*)
			string='Selected architecture is not available: %s\n'
		;;
	esac
	print_warning
	printf "$string" "$OPTION_ARCHITECTURE"
}

# display an error if selected architecture is not supported
# USAGE: select_package_architecture_error_unknown
# NEEDED_VARS: (LANG) OPTION_ARCHITECTURE
# CALLED_BY: select_package_architecture
select_package_architecture_error_unknown() {
	local string
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='L’architecture demandée n’est pas supportée : %s\n'
		;;
		('en'|*)
			string='Selected architecture is not supported: %s\n'
		;;
	esac
	print_error
	printf "$string" "$OPTION_ARCHITECTURE"
	exit 1
}

# display a warning if using --architecture on a pre-2.6 script
# USAGE: select_package_architecture_warning_unsupported
# NEEDED_VARS: (LANG)
# CALLED_BY: select_package_architecture
select_package_architecture_warning_unsupported() {
	local string
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='L’option --architecture n’est pas gérée par ce script.'
		;;
		('en'|*)
			string='--architecture option is not supported by this script.'
		;;
	esac
	print_warning
	printf '%s\n\n' "$string"
}

# get version of current package, exported as PKG_VERSION
# USAGE: get_package_version
# NEEDED_VARS: PKG
get_package_version() {
	use_package_specific_value "${ARCHIVE}_VERSION"
	PKG_VERSION="$(get_value "${ARCHIVE}_VERSION")"
	if [ -z "$PKG_VERSION" ]; then
		PKG_VERSION='1.0-1'
	fi
	# shellcheck disable=SC2154
	PKG_VERSION="${PKG_VERSION}+$script_version"

	if [ "$OPTION_PACKAGE" = 'gentoo' ]; then
		PKG_VERSION="$(printf '%s' "$PKG_VERSION" | grep --extended-regexp --only-matching '^([0-9]{1,18})(\.[0-9]{1,18})*[a-z]?' || printf '%s' 1)" # Portage doesn't like some of our version names (See https://devmanual.gentoo.org/ebuild-writing/file-format/index.html)
	fi

	export PKG_VERSION
}

# get default temporary dir
# USAGE: get_tmp_dir
get_tmp_dir() {
	printf '%s' "${TMPDIR:-/tmp}"
	return 0
}

# set temporary directories
# USAGE: set_temp_directories $pkg[…]
# NEEDED VARS: (ARCHIVE_SIZE) GAME_ID (LANG) (PWD) (XDG_CACHE_HOME) (XDG_RUNTIME_DIR)
# CALLS: set_temp_directories_error_no_size set_temp_directories_error_not_enough_space set_temp_directories_pkg testvar get_tmp_dir
set_temp_directories() {
	local base_directory
	local free_space
	local needed_space
	local tmpdir

	# If $PLAYIT_WORKDIR is already set, delete it before setting a new one
	[ "$PLAYIT_WORKDIR" ] && rm --force --recursive "$PLAYIT_WORKDIR"

	# If there is only a single package, make it the default one for the current instance
	[ $# = 1 ] && PKG="$1"

	# Look for a directory with enough free space to work in
	tmpdir="$(get_tmp_dir)"
	unset base_directory
	if [ "$NO_FREE_SPACE_CHECK" = '1' ]; then
		base_directory="$tmpdir/play.it"
		mkdir --parents "$base_directory"
		chmod 777 "$base_directory"
	else
		if [ "$ARCHIVE_SIZE" ]; then
			needed_space=$((ARCHIVE_SIZE * 2))
		else
			set_temp_directories_error_no_size
		fi
		[ "$XDG_RUNTIME_DIR" ] || XDG_RUNTIME_DIR="/run/user/$(id -u)"
		[ "$XDG_CACHE_HOME" ]  || XDG_CACHE_HOME="$HOME/.cache"
		for directory in \
			"$XDG_RUNTIME_DIR" \
			"$tmpdir" \
			"$XDG_CACHE_HOME" \
			"$PWD"
		do
			free_space=$(df --output=avail "$directory" 2>/dev/null | tail --lines=1)
			if [ -w "$directory" ] && [ $free_space -ge $needed_space ]; then
				base_directory="$directory/play.it"
				if [ "$directory" = "$tmpdir" ]; then
					if [ ! -e "$base_directory" ]; then
						mkdir --parents "$base_directory"
						chmod 777 "$base_directory"
					fi
				fi
				break;
			fi
		done
		if [ -n "$base_directory" ]; then
			mkdir --parents "$base_directory"
		else
			set_temp_directories_error_not_enough_space
		fi
	fi

	# Generate a directory with a unique name for the current instance
	PLAYIT_WORKDIR="$(mktemp --directory --tmpdir="$base_directory" "${GAME_ID}.XXXXX")"
	export PLAYIT_WORKDIR

	# Set $postinst and $prerm
	mkdir --parents "$PLAYIT_WORKDIR/scripts"
	postinst="$PLAYIT_WORKDIR/scripts/postinst"
	export postinst
	prerm="$PLAYIT_WORKDIR/scripts/prerm"
	export prerm

	# Set temporary directories for each package to build
	for pkg in "$@"; do
		testvar "$pkg" 'PKG'
		set_temp_directories_pkg $pkg
	done
}

# set package-secific temporary directory
# USAGE: set_temp_directories_pkg $pkg
# NEEDED VARS: (ARCHIVE) (OPTION_PACKAGE) PLAYIT_WORKDIR (PKG_ARCH) PKG_ID|GAME_ID
# CALLED BY: set_temp_directories
set_temp_directories_pkg() {
	PKG="$1"

	# Get package ID
	use_archive_specific_value "${PKG}_ID"
	local pkg_id
	pkg_id="$(get_value "${PKG}_ID")"
	if [ -z "$pkg_id" ]; then
		eval ${PKG}_ID=\"$GAME_ID\"
		export ${PKG?}_ID
		pkg_id="$GAME_ID"
	fi

	# Get package architecture
	local pkg_architecture
	set_architecture "$PKG"

	# Set $PKG_PATH
	if [ "$OPTION_PACKAGE" = 'arch' ] && [ "$(get_value "${PKG}_ARCH")" = '32' ]; then
		pkg_id="lib32-$pkg_id"
	fi
	get_package_version
	eval ${PKG}_PATH=\"$PLAYIT_WORKDIR/${pkg_id}_${PKG_VERSION}_${pkg_architecture}\"
	export ${PKG?}_PATH
}

# display an error if set_temp_directories() is called before setting $ARCHIVE_SIZE
# USAGE: set_temp_directories_error_no_size
# NEEDED VARS: (LANG)
# CALLS: print_error
# CALLED BY: set_temp_directories
set_temp_directories_error_no_size() {
	print_error
	case "${LANG%_*}" in
		('fr')
			string='$ARCHIVE_SIZE doit être défini avant tout appel à set_temp_directories().\n'
		;;
		('en'|*)
			string='$ARCHIVE_SIZE must be set before any call to set_temp_directories().\n'
		;;
	esac
	printf "$string"
	return 1
}

# display an error if there is not enough free space to work in any of the tested directories
# USAGE: set_temp_directories_error_not_enough_space
# NEEDED VARS: (LANG)
# CALLS: print_error
# CALLED BY: set_temp_directories
set_temp_directories_error_not_enough_space() {
	print_error
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='Il n’y a pas assez d’espace libre dans les différents répertoires testés :\n'
		;;
		('en'|*)
			string='There is not enough free space in the tested directories:\n'
		;;
	esac
	printf "$string"
	for path in "$XDG_RUNTIME_DIR" "$(get_tmp_dir)" "$XDG_CACHE_HOME" "$PWD"; do
		printf '%s\n' "$path"
	done
	return 1
}

# extract data from given archive
# USAGE: extract_data_from $archive[…]
# NEEDED_VARS: (ARCHIVE) (ARCHIVE_PASSWD) (ARCHIVE_TYPE) (LANG) (PLAYIT_WORKDIR)
# CALLS: liberror extract_7z extract_data_from_print
extract_data_from() {
	[ "$PLAYIT_WORKDIR" ] || return 1
	[ "$ARCHIVE" ] || return 1
	local file
	for file in "$@"; do
		extract_data_from_print "$(basename "$file")"

		local destination
		destination="$PLAYIT_WORKDIR/gamedata"
		mkdir --parents "$destination"
		if [ "$DRY_RUN" = '1' ]; then
			printf '\n'
			return 0
		fi
		local archive_type
		archive_type="$(get_value "${ARCHIVE}_TYPE")"
		case "$archive_type" in
			('7z')
				extract_7z "$file" "$destination"
			;;
			('cabinet')
				cabextract -L -d "$destination" -q "$file"
			;;
			('debian')
				dpkg-deb --extract "$file" "$destination"
			;;
			('innosetup'*)
				archive_extraction_innosetup "$archive_type" "$file" "$destination"
			;;
			('msi')
				msiextract --directory "$destination" "$file" 1>/dev/null 2>&1
				tolower "$destination"
			;;
			('mojosetup'|'iso')
				bsdtar --directory "$destination" --extract --file "$file"
				set_standard_permissions "$destination"
			;;
			('nix_stage1')
				local header_length
				local input_blocksize
				header_length="$(grep --text 'offset=.*head.*wc' "$file" | awk '{print $3}' | head --lines=1)"
				input_blocksize=$(head --lines="$header_length" "$file" | wc --bytes | tr --delete ' ')
				dd if="$file" ibs=$input_blocksize skip=1 obs=1024 conv=sync 2>/dev/null | gunzip --stdout | tar --extract --file - --directory "$destination"
			;;
			('nix_stage2')
				tar --extract --xz --file "$file" --directory "$destination"
			;;
			('rar'|'nullsoft-installer')
				# compute archive password from GOG id
				if [ -z "$ARCHIVE_PASSWD" ] && [ -n "$(get_value "${ARCHIVE}_GOGID")" ]; then
					ARCHIVE_PASSWD="$(printf '%s' "$(get_value "${ARCHIVE}_GOGID")" | md5sum | cut -d' ' -f1)"
				fi
				if [ -n "$ARCHIVE_PASSWD" ]; then
					UNAR_OPTIONS="-password $ARCHIVE_PASSWD"
				fi
				unar -no-directory -output-directory "$destination" $UNAR_OPTIONS "$file" 1>/dev/null
			;;
			('tar'|'tar.gz')
				tar --extract --file "$file" --directory "$destination"
			;;
			('zip')
				unzip -d "$destination" "$file" 1>/dev/null
			;;
			('zip_unclean'|'mojosetup_unzip')
				set +o errexit
				unzip -d "$destination" "$file" 1>/dev/null 2>&1
				set -o errexit
				set_standard_permissions "$destination"
			;;
			(*)
				liberror 'ARCHIVE_TYPE' 'extract_data_from'
			;;
		esac

		if [ "${archive_type#innosetup}" = "$archive_type" ]; then
			print_ok
		fi
	done
}

# print data extraction message
# USAGE: extract_data_from_print $file
# NEEDED VARS: (LANG)
# CALLED BY: extract_data_from
extract_data_from_print() {
	case "${LANG%_*}" in
		('fr')
			string='Extraction des données de %s'
		;;
		('en'|*)
			string='Extracting data from %s'
		;;
	esac
	printf "$string" "$1"
}

# extract data from InnoSetup archive
# USAGE: archive_extraction_innosetup $archive_type $archive $destination
# CALLS: archive_extraction_innosetup_error_version
archive_extraction_innosetup() {
	local archive
	local archive_type
	local destination
	local options
	archive_type="$1"
	archive="$2"
	destination="$3"
	options='--progress=1 --silent'
	if [ -n "${archive_type%%*_nolowercase}" ]; then
		options="$options --lowercase"
	fi
	if ( innoextract --list --silent "$archive" 2>&1 1>/dev/null |\
		head --lines=1 |\
		grep --ignore-case 'unexpected setup data version' 1>/dev/null )
	then
		archive_extraction_innosetup_error_version "$archive"
	fi
	printf '\n'
	innoextract $options --extract --output-dir "$destination" "$file" 2>/dev/null
}

# print error if available version of innoextract is too low
# USAGE: archive_extraction_innosetup_error_version $archive
# CALLED BY: archive_extraction_innosetup
archive_extraction_innosetup_error_version() {
	local archive
	archive="$1"
	print_error
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='La version de innoextract disponible sur ce système est trop ancienne pour extraire les données de l’archive suivante :'
		;;
		('en'|*)
			string='Available innoextract version is too old to extract data from the following archive:'
		;;
	esac
	printf "$string %s\\n" "$archive"
	exit 1
}

# prepare package layout by putting files from archive in the right packages
# directories
# USAGE: prepare_package_layout [$pkg…]
# NEEDED VARS: (LANG) (PACKAGES_LIST) PLAYIT_WORKDIR (PKG_PATH)
prepare_package_layout() {
	if [ -z "$1" ]; then
		[ -n "$PACKAGES_LIST" ] || prepare_package_layout_error_no_list
		prepare_package_layout $PACKAGES_LIST
		return 0
	fi
	for package in "$@"; do
		PKG="$package"
		organize_data "GAME_${PKG#PKG_}" "$PATH_GAME"
		organize_data "DOC_${PKG#PKG_}"  "$PATH_DOC"
		for i in $(seq 0 9); do
			organize_data "GAME${i}_${PKG#PKG_}" "$PATH_GAME"
			organize_data "DOC${i}_${PKG#PKG_}"  "$PATH_DOC"
		done
	done
}

# display an error when calling prepare_package_layout() without argument while
# $PACKAGES_LIST is unset or empty
# USAGE: prepare_package_layout_error_no_list
# NEEDED VARS: (LANG)
prepare_package_layout_error_no_list() {
	print_error
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='prepare_package_layout ne peut pas être appelé sans argument si $PACKAGES_LIST n’est pas défini.'
		;;
		('en'|*)
			string='prepare_package_layout can not be called without argument if $PACKAGES_LIST is not set.'
		;;
	esac
	printf '%s\n' "$string"
	return 1
}

# put files from archive in the right package directories
# USAGE: organize_data $id $path
# NEEDED VARS: (LANG) PLAYIT_WORKDIR (PKG) (PKG_PATH)
organize_data() {
	[ -n "$PKG" ] || organize_data_error_missing_pkg
	if [ "$OPTION_ARCHITECTURE" != all ] && [ -n "${PACKAGES_LIST##*$PKG*}" ]; then
		skipping_pkg_warning 'organize_data' "$PKG"
		return 0
	fi
	local pkg_path
	if [ "$DRY_RUN" = '1' ]; then
		pkg_path="$(get_value "${PKG}_PATH")"
		[ -n "$pkg_path" ] || missing_pkg_error 'organize_data' "$PKG"
		return 0
	fi
	use_archive_specific_value "ARCHIVE_${1}_PATH"
	use_archive_specific_value "ARCHIVE_${1}_FILES"
	local archive_path
	archive_path="$(get_value "ARCHIVE_${1}_PATH")"
	local archive_files
	archive_files="$(get_value "ARCHIVE_${1}_FILES")"

	if [ "$archive_path" ] && [ "$archive_files" ] && [ -d "$PLAYIT_WORKDIR/gamedata/$archive_path" ]; then
		pkg_path="$(get_value "${PKG}_PATH")"
		[ -n "$pkg_path" ] || missing_pkg_error 'organize_data' "$PKG"
		pkg_path="${pkg_path}$2"
		mkdir --parents "$pkg_path"
		(
			cd "$PLAYIT_WORKDIR/gamedata/$archive_path"
			for file in $archive_files; do
				if [ -e "$file" ]; then
					cp --recursive --force --link --parents --no-dereference --preserve=links "$file" "$pkg_path"
					rm --recursive "$file"
				fi
			done
		)
	fi
}

# display an error when calling organize_data() with $PKG unset or empty
# USAGE: organize_data_error_missing_pkg
# NEEDED VARS: (LANG)
organize_data_error_missing_pkg() {
	print_error
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='organize_data ne peut pas être appelé si $PKG n’est pas défini.\n'
		;;
		('en'|*)
			string='organize_data can not be called if $PKG is not set.\n'
		;;
	esac
	printf "$string"
	return 1
}

# update dependencies list with commands needed for icons extraction
# USAGE: icons_list_dependencies
icons_list_dependencies() {
	local script
	script="$0"
	if grep\
		--regexp="^APP_[^_]\\+_ICON='.\\+'"\
		--regexp="^APP_[^_]\\+_ICON_.\\+='.\\+'"\
		"$script" 1>/dev/null
	then
		SCRIPT_DEPS="$SCRIPT_DEPS identify"
		if grep\
			--regexp="^APP_[^_]\\+_ICON='.\\+\\.bmp'"\
			--regexp="^APP_[^_]\\+_ICON_.\\+='.\\+\\.bmp'"\
			--regexp="^APP_[^_]\\+_ICON='.\\+\\.ico'"\
			--regexp="^APP_[^_]\\+_ICON_.\\+='.\\+\\.ico'"\
			"$script" 1>/dev/null
		then
			SCRIPT_DEPS="$SCRIPT_DEPS convert"
		fi
		if grep\
			--regexp="^APP_[^_]\\+_ICON='.\\+\\.exe'"\
			--regexp="^APP_[^_]\\+_ICON_.\\+='.\\+\\.exe'"\
			"$script" 1>/dev/null
		then
			SCRIPT_DEPS="$SCRIPT_DEPS convert wrestool"
		fi
	fi
	export SCRIPT_DEPS
}

# get .png file(s) from various icon sources in current package
# USAGE: icons_get_from_package $app[…]
# NEEDED VARS: APP_ID|GAME_ID PATH_GAME PATH_ICON_BASE PLAYIT_WORKDIR PKG
# CALLS: icons_get_from_path
icons_get_from_package() {
	local path
	local path_pkg
	path_pkg="$(get_value "${PKG}_PATH")"
	[ -n "$path_pkg" ] || missing_pkg_error 'icons_get_from_package' "$PKG"
	path="${path_pkg}${PATH_GAME}"
	icons_get_from_path "$path" "$@"
}

# get .png file(s) from various icon sources in temporary work directory
# USAGE: icons_get_from_package $app[…]
# NEEDED VARS: APP_ID|GAME_ID PATH_ICON_BASE PLAYIT_WORKDIR PKG
# CALLS: icons_get_from_path
icons_get_from_workdir() {
	local path
	path="$PLAYIT_WORKDIR/gamedata"
	icons_get_from_path "$path" "$@"
}

# get .png file(s) from various icon sources
# USAGE: icons_get_from_path $directory $app[…]
# NEEDED VARS: APP_ID|GAME_ID PATH_ICON_BASE PLAYIT_WORKDIR PKG
# CALLS: icon_extract_png_from_file icons_include_png_from_directory testvar liberror
icons_get_from_path() {
	local app
	local destination
	local directory
	local file
	local icon
	local list
	local path_pkg
	local wrestool_id
	directory="$1"
	shift 1
	destination="$PLAYIT_WORKDIR/icons"
	path_pkg="$(get_value "${PKG}_PATH")"
	[ -n "$path_pkg" ] || missing_pkg_error 'icons_get_from_package' "$PKG"
	for app in "$@"; do
		testvar "$app" 'APP' || liberror 'app' 'icons_get_from_package'
		list="$(get_value "${app}_ICONS_LIST")"
		[ -n "$list" ] || list="${app}_ICON"
		for icon in $list; do
			use_archive_specific_value "$icon"
			file="$(get_value "$icon")"
			[ -z "$file" ] && icon_path_empty_error "$icon"
			if [ $DRY_RUN -eq 0 ] && [ ! -f "$directory/$file" ]; then
				icon_file_not_found_error "$directory/$file"
			fi
			wrestool_id="$(get_value "${icon}_ID")"
			icon_extract_png_from_file "$directory/$file" "$destination"
			icons_include_png_from_directory "$app" "$destination"
		done
	done
}

# extract .png file(s) from target file
# USAGE: icon_extract_png_from_file $file $destination
# CALLS: icon_convert_bmp_to_png icon_extract_png_from_exe icon_extract_png_from_ico icon_copy_png
# CALLED BY: icons_get_from_path
icon_extract_png_from_file() {
	local destination
	local extension
	local file
	file="$1"
	destination="$2"
	extension="${file##*.}"
	mkdir --parents "$destination"
	case "$extension" in
		('bmp')
			icon_convert_bmp_to_png "$file" "$destination"
		;;
		('exe')
			icon_extract_png_from_exe "$file" "$destination"
		;;
		('ico')
			icon_extract_png_from_ico "$file" "$destination"
		;;
		('png')
			icon_copy_png "$file" "$destination"
		;;
		(*)
			liberror 'extension' 'icon_extract_png_from_file'
		;;
	esac
}

# extract .png file(s) for .exe
# USAGE: icon_extract_png_from_exe $file $destination
# CALLS: icon_extract_ico_from_exe icon_extract_png_from_ico
# CALLED BY: icon_extract_png_from_file
icon_extract_png_from_exe() {
	[ "$DRY_RUN" = '1' ] && return 0
	local destination
	local file
	file="$1"
	destination="$2"
	icon_extract_ico_from_exe "$file" "$destination"
	for file in "$destination"/*.ico; do
		icon_extract_png_from_ico "$file" "$destination"
		rm "$file"
	done
}

# extract .ico file(s) from .exe
# USAGE: icon_extract_ico_from_exe $file $destination
# CALLED BY: icon_extract_png_from_exe
icon_extract_ico_from_exe() {
	[ "$DRY_RUN" = '1' ] && return 0
	local destination
	local file
	local options
	file="$1"
	destination="$2"
	[ "$wrestool_id" ] && options="--name=$wrestool_id"
	wrestool --extract --type=14 $options --output="$destination" "$file" 2>/dev/null
}

# convert .bmp file to .png
# USAGE: icon_convert_bmp_to_png $file $destination
# CALLED BY: icon_extract_png_from_file
icon_convert_bmp_to_png() { icon_convert_to_png "$@"; }

# extract .png file(s) from .ico
# USAGE: icon_extract_png_from_ico $file $destination
# CALLED BY: icon_extract_png_from_file icon_extract_png_from_exe
icon_extract_png_from_ico() { icon_convert_to_png "$@"; }

# convert multiple icon formats to .png
# USAGE: icon_convert_to_png $file $destination
# CALLED BY: icon_extract_png_from_bmp icon_extract_png_from_ico
icon_convert_to_png() {
	[ "$DRY_RUN" = '1' ] && return 0
	local destination
	local file
	local name
	file="$1"
	destination="$2"
	name="${file##*/}"
	convert "$file" "$destination/${name%.*}.png"
}

# copy .png file to directory
# USAGE: icon_copy_png $file $destination
# CALLED BY: icon_extract_png_from_file
icon_copy_png() {
	[ "$DRY_RUN" = '1' ] && return 0
	local destination
	local file
	file="$1"
	destination="$2"
	cp "$file" "$destination"
}

# get .png file(s) from target directory and put them in current package
# USAGE: icons_include_png_from_directory $app $directory
# NEEDED VARS: APP_ID|GAME_ID PATH_ICON_BASE PKG
# CALLS: icon_get_resolution_from_file
# CALLED BY: icons_get_from_path
icons_include_png_from_directory() {
	[ "$DRY_RUN" = '1' ] && return 0
	local app
	local directory
	local file
	local path
	local path_icon
	local path_pkg
	local resolution
	app="$1"
	directory="$2"
	name="$(get_value "${app}_ID")"
	[ -n "$name" ] || name="$GAME_ID"
	path_pkg="$(get_value "${PKG}_PATH")"
	[ -n "$path_pkg" ] || missing_pkg_error 'icons_include_png_from_directory' "$PKG"
	for file in "$directory"/*.png; do
		icon_get_resolution_from_file "$file"
		path_icon="$PATH_ICON_BASE/$resolution/apps"
		path="${path_pkg}${path_icon}"
		mkdir --parents "$path"
		mv "$file" "$path/$name.png"
	done
}
# comaptibility alias
sort_icons() {
	local app
	local directory
	directory="$PLAYIT_WORKDIR/icons"
	for app in "$@"; do
		icons_include_png_from_directory "$app" "$directory"
	done
}

# get image resolution for target file, exported as $resolution
# USAGE: icon_get_resolution_from_file $file
# CALLED BY: icons_include_png_from_directory
icon_get_resolution_from_file() {
	local file
	local version_major_target
	local version_minor_target
	file="$1"
	# shellcheck disable=SC2154
	version_major_target="${target_version%%.*}"
	# shellcheck disable=SC2154
	version_minor_target=$(printf '%s' "$target_version" | cut --delimiter='.' --fields=2)
	if
		{ [ $version_major_target -lt 2 ] || [ $version_minor_target -lt 8 ] ; } &&
		[ -n "${file##* *}" ]
	then
		field=2
		unset resolution
		while [ -z "$resolution" ] || [ -n "$(printf '%s' "$resolution" | sed 's/[0-9]*x[0-9]*//')" ]; do
			resolution="$(identify $file | sed "s;^$file ;;" | cut --delimiter=' ' --fields=$field)"
			field=$((field + 1))
		done
	else
		resolution="$(identify "$file" | sed "s;^$file ;;" | cut --delimiter=' ' --fields=2)"
	fi
	export resolution
}

# link icons in place post-installation from game directory
# USAGE: icons_linking_postinst $app[…]
# NEEDED VARS: APP_ID|GAME_ID PATH_GAME PATH_ICON_BASE PKG
icons_linking_postinst() {
	[ "$DRY_RUN" = '1' ] && return 0
	local app
	local file
	local icon
	local list
	local name
	local path
	local path_icon
	local path_pkg
	local version_major_target
	local version_minor_target
	# shellcheck disable=SC2154
	version_major_target="${target_version%%.*}"
	# shellcheck disable=SC2154
	version_minor_target=$(printf '%s' "$target_version" | cut --delimiter='.' --fields=2)
	path_pkg="$(get_value "${PKG}_PATH")"
	[ -n "$path_pkg" ] || missing_pkg_error 'icons_linking_postinst' "$PKG"
	path="${path_pkg}${PATH_GAME}"
	for app in "$@"; do
		list="$(get_value "${app}_ICONS_LIST")"
		[ "$list" ] || list="${app}_ICON"
		name="$(get_value "${app}_ID")"
		[ "$name" ] || name="$GAME_ID"
		for icon in $list; do
			file="$(get_value "$icon")"
			if [ $version_major_target -lt 2 ] || [ $version_minor_target -lt 8 ]; then
				# ensure compatibility with scripts targeting pre-2.8 library
				if [ -e "$path/$file" ] || [ -e "$path"/$file ]; then
					icon_get_resolution_from_file "$path/$file"
				else
					icon_get_resolution_from_file "${PKG_DATA_PATH}${PATH_GAME}/$file"
				fi
			else
				icon_get_resolution_from_file "$path/$file"
			fi
			path_icon="$PATH_ICON_BASE/$resolution/apps"
			if
				{ [ $version_major_target -lt 2 ] || [ $version_minor_target -lt 8 ] ; } &&
				[ -n "${file##* *}" ]
			then
				cat >> "$postinst" <<- EOF
				if [ ! -e "$path_icon/$name.png" ]; then
				  mkdir --parents "$path_icon"
				  ln --symbolic "$PATH_GAME"/$file "$path_icon/$name.png"
				fi
				EOF
			else
				cat >> "$postinst" <<- EOF
				if [ ! -e "$path_icon/$name.png" ]; then
				  mkdir --parents "$path_icon"
				  ln --symbolic "$PATH_GAME/$file" "$path_icon/$name.png"
				fi
				EOF
			fi
			cat >> "$prerm" <<- EOF
			if [ -e "$path_icon/$name.png" ]; then
			  rm "$path_icon/$name.png"
			  rmdir --parents --ignore-fail-on-non-empty "$path_icon"
			fi
			EOF
		done
	done
}

# move icons to the target package
# USAGE: icons_move_to $pkg
# NEEDED VARS: PATH_ICON_BASE PKG
icons_move_to() {
	local destination
	local source
	destination="$1"
	destination_path="$(get_value "${destination}_PATH")"
	[ -n "$destination_path" ] || missing_pkg_error 'icons_move_to' "$destination"
	source="$PKG"
	source_path="$(get_value "${source}_PATH")"
	[ -n "$source_path" ] || missing_pkg_error 'icons_move_to' "$source"
	[ "$DRY_RUN" = '1' ] && return 0
	(
		cd "$source_path"
		cp --link --parents --recursive --no-dereference --preserve=links "./$PATH_ICON_BASE" "$destination_path"
		rm --recursive "./$PATH_ICON_BASE"/*
		rmdir --ignore-fail-on-non-empty --parents "${PATH_ICON_BASE#/}"
	)
}

# print an error message if an icon can not be found
# USAGE: icon_file_not_found_error $file
# CALLED BY: icons_get_from_path
icon_file_not_found_error() {
	local file
	local string1
	local string2
	file="$1"
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string1='Le fichier d’icône suivant est introuvable : %s'
			string2='Merci de signaler cette erreur sur notre outil de gestion de bugs : %s'
		;;
		('en'|*)
			string1='The following icon file could not be found: %s'
			string2='Please report this issue in our bug tracker: %s'
		;;
	esac
	print_error
	printf "$string1\\n" "$1"
	printf "$string2\\n" "$PLAYIT_GAMES_BUG_TRACKER_URL"
	return 1
}

# print an error message if an icon path is empty
# USAGE: icon_path_empty_error $icon
# CALLED BY: icons_get_from_path
icon_path_empty_error() {
	local string
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='Le chemin vers l̛’icône est vide : %s'
		;;
		('en'|*)
			string='The icon path is empty: %s'
		;;
	esac
	print_error
	printf "$string\\n" "$1"
	return 1
}
# print installation instructions
# USAGE: print_instructions $pkg[…]
# NEEDED VARS: (GAME_NAME) (OPTION_PACKAGE) (PACKAGES_LIST)
print_instructions() {
	[ "$GAME_NAME" ] || return 1
	if [ $# = 0 ]; then
		print_instructions $PACKAGES_LIST
		return 0
	fi
	local package_arch
	local packages_list_32
	local packages_list_64
	local packages_list_all
	local string
	for package in "$@"; do
		package_arch="$(get_value "${package}_ARCH")"
		case "$package_arch" in
			('32')
				packages_list_32="$packages_list_32 $package"
			;;
			('64')
				packages_list_64="$packages_list_64 $package"
			;;
			(*)
				packages_list_all="$packages_list_all $package"
			;;
		esac

	done
	if [ "$OPTION_PACKAGE" = 'gentoo' ] && [ -n "$GENTOO_OVERLAYS" ]; then
		case "${LANG%_*}" in
			('fr')
				string='\nVous pouvez avoir besoin des overlays suivants pour installer ces paquets :%s\n'
			;;
			('en'|*)
				string='\nYou may need the following overlays to install these packages:%s\n'
			;;
		esac
		printf "$string" "$GENTOO_OVERLAYS"
	fi
	case "${LANG%_*}" in
		('fr')
			string='\nInstallez "%s" en lançant la série de commandes suivantes en root :\n'
		;;
		('en'|*)
			string='\nInstall "%s" by running the following commands as root:\n'
		;;
	esac
	printf "$string" "$GAME_NAME"
	if [ -n "$packages_list_32" ] && [ -n "$packages_list_64" ]; then
		print_instructions_architecture_specific '32' $packages_list_all $packages_list_32
		print_instructions_architecture_specific '64' $packages_list_all $packages_list_64
	else
		case $OPTION_PACKAGE in
			('arch')
				print_instructions_arch "$@"
			;;
			('deb')
				print_instructions_deb "$@"
			;;
			('gentoo')
				print_instructions_gentoo "$@"
			;;
			(*)
				liberror 'OPTION_PACKAGE' 'print_instructions'
			;;
		esac
	fi
	printf '\n'
}

# print installation instructions for Arch Linux - 32-bit version
# USAGE: print_instructions_architecture_specific $pkg[…]
# CALLS: print_instructions_arch print_instructions_deb print_instructions_gentoo
print_instructions_architecture_specific() {
	case "${LANG%_*}" in
		('fr')
			string='\nversion %s-bit :\n'
		;;
		('en'|*)
			string='\n%s-bit version:\n'
		;;
	esac
	printf "$string" "$1"
	shift 1
	case $OPTION_PACKAGE in
		('arch')
			print_instructions_arch "$@"
		;;
		('deb')
			print_instructions_deb "$@"
		;;
		('gentoo')
			print_instructions_gentoo "$@"
		;;
		(*)
			liberror 'OPTION_PACKAGE' 'print_instructions'
		;;
	esac
}

# print installation instructions for Arch Linux
# USAGE: print_instructions_arch $pkg[…]
print_instructions_arch() {
	local pkg_path
	local str_format
	printf 'pacman -U'
	for pkg in "$@"; do
		if [ "$OPTION_ARCHITECTURE" != all ] && [ -n "${PACKAGES_LIST##*$pkg*}" ]; then
			skipping_pkg_warning 'print_instructions_arch' "$pkg"
			return 0
		fi
		pkg_path="$(get_value "${pkg}_PKG")"
		if [ -z "${pkg_path##* *}" ]; then
			str_format=' "%s"'
		else
			str_format=' %s'
		fi
		printf "$str_format" "$pkg_path"
	done
	printf '\n'
}

# print installation instructions for Debian
# USAGE: print_instructions_deb $pkg[…]
# CALLS: print_instructions_deb_apt print_instructions_deb_dpkg
print_instructions_deb() {
	if command -v apt >/dev/null 2>&1; then
		debian_version="$(apt --version 2>/dev/null | head --lines=1 | cut --delimiter=' ' --fields=2)"
		debian_version_major="$(printf '%s' "$debian_version" | cut --delimiter='.' --fields='1')"
		debian_version_minor="$(printf '%s' "$debian_version" | cut --delimiter='.' --fields='2')"
		if [ $debian_version_major -ge 2 ] ||\
		   [ $debian_version_major = 1 ] &&\
		   [ ${debian_version_minor%~*} -ge 1 ]; then
			print_instructions_deb_apt "$@"
		else
			print_instructions_deb_dpkg "$@"
		fi
	else
		print_instructions_deb_dpkg "$@"
	fi
}

# print installation instructions for Debian with apt
# USAGE: print_instructions_deb_apt $pkg[…]
# CALLS: print_instructions_deb_common
# CALLED BY: print_instructions_deb
print_instructions_deb_apt() {
	printf 'apt install'
	print_instructions_deb_common "$@"
}

# print installation instructions for Debian with dpkg + apt-get
# USAGE: print_instructions_deb_dpkg $pkg[…]
# CALLS: print_instructions_deb_common
# CALLED BY: print_instructions_deb
print_instructions_deb_dpkg() {
	printf 'dpkg -i'
	print_instructions_deb_common "$@"
	printf 'apt-get install -f\n'
}

# print installation instructions for Debian (common part)
# USAGE: print_instructions_deb_common $pkg[…]
# CALLED BY: print_instructions_deb_apt print_instructions_deb_dpkg
print_instructions_deb_common() {
	local pkg_path
	local str_format
	for pkg in "$@"; do
		if [ "$OPTION_ARCHITECTURE" != all ] && [ -n "${PACKAGES_LIST##*$pkg*}" ]; then
			skipping_pkg_warning 'print_instructions_deb_common' "$pkg"
			return 0
		fi
		pkg_path="$(get_value "${pkg}_PKG")"
		if [ -z "${pkg_path##* *}" ]; then
			str_format=' "%s"'
		else
			str_format=' %s'
		fi
		printf "$str_format" "$pkg_path"
	done
	printf '\n'
}

# print installation instructions for Gentoo Linux
# USAGE: print_instructions_gentoo $pkg[…]
print_instructions_gentoo() {
	local pkg_path
	local str_format
	local str_comment
	printf 'quickunpkg --'
	for pkg in "$@"; do
		if [ "$OPTION_ARCHITECTURE" != all ] && [ -n "${PACKAGES_LIST##*$pkg*}" ]; then
			skipping_pkg_warning 'print_instructions_gentoo' "$pkg"
			return 0
		fi
		pkg_path="$(get_value "${pkg}_PKG")"
		if [ -z "${pkg_path##* *}" ]; then
			str_format=' "%s"'
		else
			str_format=' %s'
		fi
		printf "$str_format" "$pkg_path"
	done
	case "${LANG%_*}" in
		('fr')
			str_comment='ou mettez les paquets dans un PKGDIR (dans un dossier nommé games-playit) et emergez-les'
		;;
		('en'|*)
			str_comment='or put the packages in a PKGDIR (in a folder named games-playit) and emerge them'
		;;
	esac
	printf ' # %s %s\n' 'https://www.dotslashplay.it/ressources/gentoo/' "$str_comment"
}

# write launcher script
# USAGE: launcher_write_script $app
# NEEDED VARS: GAME_ID OPTION_ARCHITECTURE PACKAGES_LIST PATH_BIN
# CALLS: error_missing_argument error_extra_arguments testvar liberror error_no_pkg skipping_pkg_warning missing_pkg_error launcher_write_script_headers launcher_write_script_prefix_functions launcher_write_script_wine_winecfg launcher_write_script_dosbox_application_variables launcher_write_script_native_application_variables launcher_write_script_scummvm_application_variables launcher_write_script_wine_application_variables launcher_write_script_prefix_functions launcher_write_script_prefix_build launcher_write_script_wine_prefix_build launcher_write_script_dosbox_run launcher_write_script_native_run launcher_write_script_nativenoprefix_run launcher_write_script_scummvm_run launcher_write_script_winecfg_run launcher_write_script_wine_run
# CALLED BY:
launcher_write_script() {
	# check that this has been called with exactly one argument
	if [ "$#" = '0' ]; then
		error_missing_argument 'launcher_write_script'
	elif [ "$#" -gt 1 ]; then
		error_extra_arguments 'launcher_write_script'
	fi

	# check that $PKG is set
	if [ -z "$PKG" ]; then
		error_no_pkg 'launcher_write_script'
	fi

	# skip any action if called for a package excluded for target architectures
	if [ "$OPTION_ARCHITECTURE" != 'all' ] && [ -n "${PACKAGES_LIST##*$PKG*}" ]; then
		skipping_pkg_warning 'launcher_write_script' "$PKG"
		return 0
	fi

	# parse argument
	local application
	application="$1"
	testvar "$application" 'APP' || liberror 'application' 'launcher_write_script'

	# get application type
	local application_type
	application_type="$(get_value "${application}_TYPE")"

	# compute file name and path
	local application_id
	local package_path
	local target_file
	package_path="$(get_value "${PKG}_PATH")"
	[ -n "$package_path" ] || missing_pkg_error 'launcher_write_script' "$PKG"
	application_id="$(get_value "${application}_ID")"
	if [ -z "$application_id" ]; then
		application_id="$GAME_ID"
	fi
	target_file="${package_path}${PATH_BIN}/$application_id"

	# if called in dry run mode, return before writing anything
	if [ "$DRY_RUN" = '1' ]; then
		return 0
	fi

	# write launcher script
	mkdir --parents "${target_file%/*}"
	touch "$target_file"
	chmod 755 "$target_file"
	launcher_write_script_headers "$target_file"
	case "$application_type" in
		('dosbox')
			launcher_write_script_dosbox_application_variables "$application" "$target_file"
			launcher_write_script_game_variables "$target_file"
			launcher_write_script_user_files "$target_file"
			launcher_write_script_prefix_variables "$target_file"
			launcher_write_script_prefix_functions "$target_file"
			launcher_write_script_prefix_build "$target_file"
			launcher_write_script_dosbox_run "$application" "$target_file"
		;;
		('java')
			launcher_write_script_java_application_variables "$application" "$target_file"
			launcher_write_script_game_variables "$target_file"
			launcher_write_script_user_files "$target_file"
			launcher_write_script_prefix_variables "$target_file"
			launcher_write_script_prefix_functions "$target_file"
			launcher_write_script_prefix_build "$target_file"
			launcher_write_script_java_run "$application" "$target_file"
		;;
		('native')
			launcher_write_script_native_application_variables "$application" "$target_file"
			launcher_write_script_game_variables "$target_file"
			launcher_write_script_user_files "$target_file"
			launcher_write_script_prefix_variables "$target_file"
			launcher_write_script_prefix_functions "$target_file"
			launcher_write_script_prefix_build "$target_file"
			launcher_write_script_native_run "$application" "$target_file"
		;;
		('native_no-prefix')
			launcher_write_script_native_application_variables "$application" "$target_file"
			launcher_write_script_game_variables "$target_file"
			launcher_write_script_nativenoprefix_run "$application" "$target_file"
		;;
		('scummvm')
			launcher_write_script_scummvm_application_variables "$application" "$target_file"
			launcher_write_script_game_variables "$target_file"
			launcher_write_script_scummvm_run "$application" "$target_file"
		;;
		('wine')
			if [ "$application_id" != "${GAME_ID}_winecfg" ]; then
				launcher_write_script_wine_application_variables "$application" "$target_file"
			fi
			launcher_write_script_game_variables "$target_file"
			launcher_write_script_user_files "$target_file"
			launcher_write_script_prefix_variables "$target_file"
			launcher_write_script_prefix_functions "$target_file"
			launcher_write_script_wine_prefix_build "$target_file"
			if [ "$application_id" = "${GAME_ID}_winecfg" ]; then
				launcher_write_script_winecfg_run "$target_file"
			else
				launcher_write_script_wine_run "$application" "$target_file"
			fi
		;;
		(*)
			error_unknown_application_type "$application_type"
		;;
	esac
	cat >> "$target_file" <<- 'EOF'
	exit 0
	EOF

	# for native applications, add execution permissions to the game binary file
	case "$application_type" in
		('native'*)
			local application_exe
			use_package_specific_value "${application}_EXE"
			application_exe="$(get_value "${application}_EXE")"
			chmod +x "${package_path}${PATH_GAME}/$application_exe"
		;;
	esac

	# for WINE applications, write launcher script for winecfg
	case "$application_type" in
		('wine')
			local winecfg_file
			winecfg_file="${package_path}${PATH_BIN}/${GAME_ID}_winecfg"
			if [ ! -e "$winecfg_file" ]; then
				launcher_write_script_wine_winecfg "$application"
			fi
		;;
	esac

	return 0
}

# write launcher script headers
# USAGE: launcher_write_script_headers $file
# NEEDED VARS: library_version
# CALLED BY: launcher_write_script
launcher_write_script_headers() {
	local file
	file="$1"
	cat > "$file" <<- EOF
	#!/bin/sh
	# script generated by ./play.it $library_version - http://wiki.dotslashplay.it/
	set -o errexit

	EOF
	return 0
}

# write launcher script game-specific variables
# USAGE: launcher_write_script_game_variables $file
# NEEDED VARS: GAME_ID PATH_GAME
# CALLED BY: launcher_write_script
launcher_write_script_game_variables() {
	local file
	file="$1"
	cat >> "$file" <<- EOF
	# Set game-specific values

	GAME_ID='$GAME_ID'
	PATH_GAME='$PATH_GAME'

	EOF
	return 0
}

# write launcher script list of user-writable files
# USAGE: launcher_write_script_user_files $file
# NEEDED VARS: CONFIG_DIRS CONFIG_FILES DATA_DIRS DATA_FILES
# CALLED BY: launcher_write_script
launcher_write_script_user_files() {
	local file
	file="$1"
	cat >> "$file" <<- EOF
	# Set list of user-writable files

	CONFIG_DIRS='$CONFIG_DIRS'
	CONFIG_FILES='$CONFIG_FILES'
	DATA_DIRS='$DATA_DIRS'
	DATA_FILES='$DATA_FILES'

	EOF
	return 0
}

# write launcher script prefix-related variables
# USAGE: launcher_write_script_prefix_variables $file
# CALLED BY: launcher_write_script
launcher_write_script_prefix_variables() {
	local file
	file="$1"
	cat >> "$file" <<- 'EOF'
	# Set prefix-related values

	: "${PREFIX_ID:="$GAME_ID"}"
	PATH_CONFIG="${XDG_CONFIG_HOME:="$HOME/.config"}/$PREFIX_ID"
	PATH_DATA="${XDG_DATA_HOME:="$HOME/.local/share"}/games/$PREFIX_ID"

	EOF
	return 0
}

# write launcher script prefix functions
# USAGE: launcher_write_script_prefix_functions $file
# CALLED BY: launcher_write_script
launcher_write_script_prefix_functions() {
	local file
	file="$1"
	cat >> "$file" <<- 'EOF'
	# Set prefix-related functions

	init_prefix_dirs() {
	    (
	        cd "$PATH_GAME"
	        for dir in $2; do
	            if [ ! -e "$1/$dir" ]; then
	                if [ -e "$PATH_PREFIX/$dir" ]; then
	                    (
	                        cd "$PATH_PREFIX"
	                        cp --dereference --parents --recursive "$dir" "$1"
	                    )
	                elif [ -e "$PATH_GAME/$dir" ]; then
	                    cp --parents --recursive "$dir" "$1"
	                else
	                    mkdir --parents "$1/$dir"
	                fi
	            fi
	            rm --force --recursive "$PATH_PREFIX/$dir"
	            mkdir --parents "$PATH_PREFIX/${dir%/*}"
	            ln --symbolic "$(readlink --canonicalize-existing "$1/$dir")" "$PATH_PREFIX/$dir"
	        done
	    )
	}

	init_prefix_files() {
	    (
	        local file_prefix
	        local file_real
	        cd "$1"
	        find -L . -type f | while read -r file; do
	            if [ -e "$PATH_PREFIX/$file" ]; then
	                file_prefix="$(readlink -e "$PATH_PREFIX/$file")"
	            else
	                unset file_prefix
	            fi
	            file_real="$(readlink -e "$file")"
	            if [ "$file_real" != "$file_prefix" ]; then
	                if [ "$file_prefix" ]; then
	                    rm --force "$PATH_PREFIX/$file"
	                fi
	                mkdir --parents "$PATH_PREFIX/${file%/*}"
	                ln --symbolic "$file_real" "$PATH_PREFIX/$file"
	            fi
	        done
	    )
	    (
	        cd "$PATH_PREFIX"
	        for file in $2; do
	            if [ -e "$file" ] && [ ! -e "$1/$file" ]; then
	                cp --parents "$file" "$1"
	                rm --force "$file"
	                ln --symbolic "$1/$file" "$file"
	            fi
	        done
	    )
	}

	init_userdir_files() {
	    (
	        cd "$PATH_GAME"
	        for file in $2; do
	            if [ ! -e "$1/$file" ] && [ -e "$file" ]; then
	                cp --parents "$file" "$1"
	            fi
	        done
	    )
	}

	EOF
	sed --in-place 's/    /\t/g' "$file"
	return 0
}

# write launcher script prefix initialization
# USAGE: launcher_write_script_prefix_build $file
# CALLED BY: launcher_write_build
launcher_write_script_prefix_build() {
	local file
	file="$1"
	cat >> "$file" <<- 'EOF'
	# Build user prefix

	PATH_PREFIX="$XDG_DATA_HOME/play.it/prefixes/$PREFIX_ID"
	for dir in "$PATH_PREFIX" "$PATH_CONFIG" "$PATH_DATA"; do
	    if [ ! -e "$dir" ]; then
	        mkdir --parents "$dir"
	    fi
	done
	(
	    cd "$PATH_GAME"
	    find . -type d | while read dir; do
	        if [ -h "$PATH_PREFIX/$dir" ]; then
	            rm "$PATH_PREFIX/$dir"
	        fi
	    done
	)
	cp --recursive --remove-destination --symbolic-link "$PATH_GAME"/* "$PATH_PREFIX"
	(
	    cd "$PATH_PREFIX"
	    find . -type l | while read link; do
	        if [ ! -e "$link" ]; then
	            rm "$link"
	        fi
	    done
	    find . -depth -type d | while read dir; do
	        if [ ! -e "$PATH_GAME/$dir" ]; then
	            rmdir --ignore-fail-on-non-empty "$dir"
	        fi
	    done
	)
	init_userdir_files "$PATH_CONFIG" "$CONFIG_FILES"
	init_userdir_files "$PATH_DATA" "$DATA_FILES"
	init_prefix_files "$PATH_CONFIG" "$CONFIG_FILES"
	init_prefix_files "$PATH_DATA" "$DATA_FILES"
	init_prefix_dirs "$PATH_CONFIG" "$CONFIG_DIRS"
	init_prefix_dirs "$PATH_DATA" "$DATA_DIRS"

	EOF
	sed --in-place 's/    /\t/g' "$file"
	return 0
}

# write launcher script pre-run actions
# USAGE: launcher_write_script_prerun $application $file
# CALLED BY: launcher_write_script_dosbox_run launcher_write_script_native_run launcher_write_script_nativenoprefix_run launcher_write_script_scummvm_run launcher_write_script_wine_run
launcher_write_script_prerun() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	local application_prerun
	application_prerun="$(get_value "${application}_PRERUN")"
	if [ "$application_prerun" ]; then
		cat >> "$file" <<- EOF
		$application_prerun

		EOF
	fi

	return 0
}

# write launcher script post-run actions
# USAGE: launcher_write_script_postrun $application $file
# CALLED BY: launcher_write_script_dosbox_run launcher_write_script_native_run launcher_write_script_nativenoprefix_run launcher_write_script_scummvm_run launcher_write_script_wine_run
launcher_write_script_postrun() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	local application_postrun
	application_postrun="$(get_value "${application}_POSTRUN")"
	if [ "$application_postrun" ]; then
		cat >> "$file" <<- EOF
		$application_postrun

		EOF
	fi

	return 0
}

# write menu entry
# USAGE: launcher_write_desktop $app
# NEEDED VARS: OPTION_ARCHITECTURE PACKAGES_LIST GAME_ID GAME_NAME PATH_DESK PATH_BIN
# CALLS: error_missing_argument error_extra_arguments error_no_pkg
launcher_write_desktop() {
	# check that this has been called with exactly one argument
	if [ "$#" = '0' ]; then
		error_missing_argument 'launcher_write_desktop'
	elif [ "$#" -gt 1 ]; then
		error_extra_arguments 'launcher_write_desktop'
	fi

	# check that $PKG is set
	if [ -z "$PKG" ]; then
		error_no_pkg 'launcher_write_desktop'
	fi

	# skip any action if called for a package excluded for target architectures
	if [ "$OPTION_ARCHITECTURE" != 'all' ] && [ -n "${PACKAGES_LIST##*$PKG*}" ]; then
		skipping_pkg_warning 'launcher_write_desktop' "$PKG"
		return 0
	fi

	# parse argument
	local application
	application="$1"
	testvar "$application" 'APP' || liberror 'application' 'launcher_write_desktop'

	# get application-specific values
	local application_id
	local application_name
	local application_category
	local application_type
	if [ "$application" = 'APP_WINECFG' ]; then
		application_id="${GAME_ID}_winecfg"
		application_name="$GAME_NAME - WINE configuration"
		application_category='Settings'
		application_type='wine'
		application_icon='winecfg'
	else
		application_id="$(get_value "${application}_ID")"
		application_name="$(get_value "${application}_NAME")"
		application_category="$(get_value "${application}_CAT")"
		application_type="$(get_value "${application}_TYPE")"
		: "${application_id:=$GAME_ID}"
		: "${application_name:=$GAME_NAME}"
		: "${application_category:=Game}"
		application_icon="$application_id"
	fi

	# compute file name and path
	local package_path
	local target_file
	package_path="$(get_value "${PKG}_PATH")"
	[ -n "$package_path" ] || missing_pkg_error 'launcher_write_desktop' "$PKG"
	target_file="${package_path}${PATH_DESK}/${application_id}.desktop"

	# include full binary path in Exec field if using non-standard installation prefix
	local exec_field
	case "$OPTION_PREFIX" in
		('/usr'|'/usr/local')
			exec_field="$application_id"
		;;
		(*)
			exec_field="$PATH_BIN/$application_id"
		;;
	esac

	# if called in dry run mode, return before writing anything
	if [ "$DRY_RUN" = '1' ]; then
		return 0
	fi

	# write desktop file
	mkdir --parents "${target_file%/*}"
	cat >> "$target_file" <<- EOF
	[Desktop Entry]
	Version=1.0
	Type=Application
	Name=$application_name
	Icon=$application_icon
	Exec=$exec_field
	Categories=$application_category
	EOF

	# for WINE applications, write desktop file for winecfg
	case "$application_type" in
		('wine')
			local winecfg_desktop
			winecfg_desktop="${package_path}${PATH_DESK}/${GAME_ID}_winecfg.desktop"
			if [ ! -e "$winecfg_desktop" ]; then
				launcher_write_desktop 'APP_WINECFG'
			fi
		;;
	esac

	return 0
}

# write both launcher script and menu entry for a single application
# USAGE: launcher_write $application
# NEEDED VARS: OPTION_ARCHITECTURE PACKAGES_LIST PKG
# CALLS: launcher_write_script launcher_write_desktop
# CALLED BY: launchers_write
launcher_write() {
	# skip any action if called for a package excluded for target architectures
	if [ "$OPTION_ARCHITECTURE" != 'all' ] && [ -n "${PACKAGES_LIST##*$PKG*}" ]; then
		skipping_pkg_warning 'launcher_write_script' "$PKG"
		return 0
	fi

	local application
	application="$1"
	launcher_write_script "$application"
	launcher_write_desktop "$application"
	return 0
}

# write both launcher script and menu entry for a list of applications
# USAGE: launchers_write $application[…]
# NEEDED VARS: OPTION_ARCHITECTURE PACKAGES_LIST PKG
# CALLS: launcher_write
launchers_write() {
	# skip any action if called for a package excluded for target architectures
	if [ "$OPTION_ARCHITECTURE" != 'all' ] && [ -n "${PACKAGES_LIST##*$PKG*}" ]; then
		skipping_pkg_warning 'launcher_write_script' "$PKG"
		return 0
	fi

	local application
	for application in "$@"; do
		launcher_write "$application"
	done
	return 0
}

# DOSBox - write application-specific variables
# USAGE: launcher_write_script_dosbox_application_variables $application $file
# CALLED BY: launcher_write_script
launcher_write_script_dosbox_application_variables() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	# compute application-specific variables values
	local application_exe
	local application_options
	use_package_specific_value "${application}_EXE"
	use_package_specific_value "${application}_OPTIONS"
	application_exe="$(get_value "${application}_EXE")"
	application_options="$(get_value "${application}_OPTIONS")"

	cat >> "$file" <<- EOF
	# Set application-specific values

	APP_EXE='$application_exe'
	APP_OPTIONS="$application_options"

	EOF
	return 0
}

# DOSBox - run the game
# USAGE: launcher_write_script_dosbox_run $application $file
# NEEDED_VARS: GAME_IMAGE GAME_IMAGE_TYPE PACKAGES_LIST PATH_GAME
# CALLS: launcher_write_script_prerun launcher_write_script_postrun
# CALLED BY: launcher_write_script
launcher_write_script_dosbox_run() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	cat >> "$file" <<- 'EOF'
	# Run the game

	cd "$PATH_PREFIX"
	dosbox -c "mount c .
	c:
	EOF

	# mount CD image file
	if [ "$GAME_IMAGE" ]; then
		case "$GAME_IMAGE_TYPE" in
			('cdrom')
				local image
				local package
				local package_path
				for package in $PACKAGES_LIST; do
					package_path="$(get_value "${pkg}_PATH")"
					if [ -e "${package_path}$PATH_GAME/$GAME_IMAGE" ]; then
						image="${package_path}$PATH_GAME/$GAME_IMAGE"
						break;
					fi
				done
				if [ -d "$image" ]; then
					cat >> "$file" <<- EOF
					mount d $GAME_IMAGE -t cdrom
					EOF
				else
					cat >> "$file" <<- EOF
					imgmount d $GAME_IMAGE -t cdrom
					EOF
				fi
			;;
			('iso'|*)
				cat >> "$file" <<- EOF
				imgmount d $GAME_IMAGE -t iso -fs iso
				EOF
			;;
		esac
	fi

	launcher_write_script_prerun "$application" "$file"

	cat >> "$file" <<- 'EOF'
	$APP_EXE $APP_OPTIONS $@
	EOF

	launcher_write_script_postrun "$application" "$file"

	cat >> "$file" <<- 'EOF'
	exit"

	EOF
	return 0
}

# Java - write application-specific variables
# USAGE: launcher_write_script_java_application_variables $application $file
# CALLED BY: launcher_write_script
launcher_write_script_java_application_variables() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	# compute application-specific variables values
	local application_exe
	local application_java_options
	local application_libs
	local application_options
	use_package_specific_value "${application}_EXE"
	use_package_specific_value "${application}_JAVA_OPTIONS"
	use_package_specific_value "${application}_LIBS"
	use_package_specific_value "${application}_OPTIONS"
	application_exe="$(get_value "${application}_EXE")"
	application_java_options="$(get_value "${application}_JAVA_OPTIONS")"
	application_libs="$(get_value "${application}_LIBS")"
	application_options="$(get_value "${application}_OPTIONS")"

	cat >> "$file" <<- EOF
	# Set application-specific values

	APP_EXE='$application_exe'
	APP_LIBS='$application_libs'
	APP_OPTIONS="$application_options"
	JAVA_OPTIONS='$application_java_options'

	EOF
	return 0
}

# Java - run the game
# USAGE: launcher_write_script_java_run $application $file
# CALLED BY: launcher_write_script
launcher_write_script_java_run() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	cat >> "$file" <<- 'EOF'
	# Run the game

	cd "$PATH_PREFIX"

	EOF

	launcher_write_script_prerun "$application" "$file"

	cat >> "$file" <<- 'EOF'
	library_path=
	if [ -n "$APP_LIBS" ]; then
	    library_path="$APP_LIBS:"
	fi
	EOF
	local extra_library_path
	extra_library_path="$(launcher_native_get_extra_library_path)"
	if [ -n "$extra_library_path" ]; then
		cat >> "$file" <<- EOF
		library_path="\${library_path}$extra_library_path"
		EOF
	fi
	cat >> "$file" <<- 'EOF'
	if [ -n "$library_path" ]; then
	    LD_LIBRARY_PATH="${library_path}$LD_LIBRARY_PATH"
	    export LD_LIBRARY_PATH
	fi
	JAVA_OPTIONS="$(eval printf -- '%b' \"$JAVA_OPTIONS\")"
	java $JAVA_OPTIONS -jar "$APP_EXE" $APP_OPTIONS "$@"

	EOF

	launcher_write_script_postrun "$application" "$file"

	sed --in-place 's/    /\t/g' "$file"
	return 0
}

# native - write application-specific variables
# USAGE: launcher_write_script_native_application_variables $application $file
# CALLED BY: launcher_write_script
launcher_write_script_native_application_variables() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	# compute application-specific variables values
	local application_exe
	local application_libs
	local application_options
	use_package_specific_value "${application}_EXE"
	use_package_specific_value "${application}_LIBS"
	use_package_specific_value "${application}_OPTIONS"
	application_exe="$(get_value "${application}_EXE")"
	application_libs="$(get_value "${application}_LIBS")"
	application_options="$(get_value "${application}_OPTIONS")"

	cat >> "$file" <<- EOF
	# Set application-specific values

	APP_EXE='$application_exe'
	APP_LIBS='$application_libs'
	APP_OPTIONS="$application_options"

	EOF
	return 0
}

# native - run the game (with prefix)
# USAGE: launcher_write_script_native_run $application $file
# CALLED BY: launcher_write_script
launcher_write_script_native_run() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	cat >> "$file" <<- 'EOF'
	# Copy the game binary into the user prefix

	if [ -e "$PATH_DATA/$APP_EXE" ]; then
	    source_dir="$PATH_DATA"
	else
	    source_dir="$PATH_GAME"
	fi

	(
	    cd "$source_dir"
	    cp --parents --dereference --remove-destination "$APP_EXE" "$PATH_PREFIX"
	)

	# Run the game

	cd "$PATH_PREFIX"

	EOF
	sed --in-place 's/    /\t/g' "$file"

	launcher_write_script_native_run_common "$application" "$file"

	return 0
}

# native - run the game (without prefix)
# USAGE: launcher_write_script_nativenoprefix_run $application $file
# CALLED BY: launcher_write_script
launcher_write_script_nativenoprefix_run() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	cat >> "$file" <<- 'EOF'
	# Run the game

	cd "$PATH_GAME"

	EOF

	launcher_write_script_native_run_common "$application" "$file"

	return 0
}

# native - get extra LD_LIBRARY_PATH entries (with a trailing :)
# USAGE: launcher_native_get_extra_library_path
# NEEDED VARS: OPTION_PACKAGE PKG
# CALLED BY: launcher_write_script_native_run_common
launcher_native_get_extra_library_path() {
	if [ "$OPTION_PACKAGE" = 'gentoo' ] && get_value "${PKG}_DEPS" | sed --regexp-extended 's/\s+/\n/g' | grep --fixed-strings --line-regexp --quiet 'libcurl-gnutls'; then
		local pkg_architecture
		set_architecture "$PKG"
		printf '%s' "/usr/\$(portageq envvar 'LIBDIR_$pkg_architecture')/debiancompat:"
	fi
}

# native - run the game (common part)
# USAGE: launcher_write_script_native_run_common $application $file
# CALLS: launcher_write_script_prerun launcher_write_script_postrun launcher_native_get_extra_library_path
# CALLED BY: launcher_write_script_native_run launcher_write_script_nativenoprefix_run
launcher_write_script_native_run_common() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	launcher_write_script_prerun "$application" "$file"

	cat >> "$file" <<- 'EOF'
	library_path=
	if [ -n "$APP_LIBS" ]; then
	    library_path="$APP_LIBS:"
	fi
	EOF
	local extra_library_path
	extra_library_path="$(launcher_native_get_extra_library_path)"
	if [ -n "$extra_library_path" ]; then
		cat >> "$file" <<- EOF
		library_path="\${library_path}$extra_library_path"
		EOF
	fi
	cat >> "$file" <<- 'EOF'
	if [ -n "$library_path" ]; then
	    LD_LIBRARY_PATH="${library_path}$LD_LIBRARY_PATH"
	    export LD_LIBRARY_PATH
	fi
	"./$APP_EXE" $APP_OPTIONS $@

	EOF

	launcher_write_script_postrun "$application" "$file"

	sed --in-place 's/    /\t/g' "$file"
	return 0
}
# ScummVM - write application-specific variables
# USAGE: launcher_write_script_scummvm_application_variables $application $file
# CALLED BY: launcher_write_script
launcher_write_script_scummvm_application_variables() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	# compute application-specific variables values
	local application_scummid
	use_package_specific_value "${application}_SCUMMID"
	application_scummid="$(get_value "${application}_SCUMMID")"

	cat >> "$file" <<- EOF
	# Set application-specific values

	SCUMMVM_ID='$application_scummid'

	EOF
	return 0
}

# ScummVM - run the game
# USAGE: launcher_write_script_scummvm_run $application $file
# CALLS: launcher_write_script_prerun launcher_write_script_postrun
# CALLED BY: launcher_write_script
launcher_write_script_scummvm_run() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	cat >> "$file" <<- 'EOF'
	# Run the game

	EOF

	launcher_write_script_prerun "$application" "$file"

	cat >> "$file" <<- 'EOF'
	scummvm -p "$PATH_GAME" $APP_OPTIONS $@ $SCUMMVM_ID

	EOF

	launcher_write_script_postrun "$application" "$file"

	return 0
}

# WINE - write application-specific variables
# USAGE: launcher_write_script_wine_application_variables $application $file
# CALLED BY: launcher_write_script
launcher_write_script_wine_application_variables() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	# compute application-specific variables values
	local application_exe
	local application_options
	use_package_specific_value "${application}_EXE"
	use_package_specific_value "${application}_OPTIONS"
	application_exe="$(get_value "${application}_EXE")"
	application_options="$(get_value "${application}_OPTIONS")"

	cat >> "$file" <<- EOF
	# Set application-specific values

	APP_EXE='$application_exe'
	APP_OPTIONS="$application_options"

	EOF
	return 0
}

# WINE - write launcher script prefix initialization
# USAGE: launcher_write_script_wine_prefix_build $file
# NEEDED VARS: PKG APP_WINETRICKS APP_REGEDIT
# CALLED BY: launcher_write_build
launcher_write_script_wine_prefix_build() {
	local file
	file="$1"

	# compute WINE prefix architecture
	local architecture
	local winearch
	use_archive_specific_value "${PKG}_ARCH"
	architecture="$(get_value "${PKG}_ARCH")"
	case "$architecture" in
		('32') winearch='win32' ;;
		('64') winearch='win64' ;;
	esac

	cat >> "$file" <<- EOF
	# Build user prefix

	WINEARCH='$winearch'
	EOF

	cat >> "$file" <<- 'EOF'
	WINEDEBUG='-all'
	WINEDLLOVERRIDES='winemenubuilder.exe,mscoree,mshtml=d'
	WINEPREFIX="$XDG_DATA_HOME/play.it/prefixes/$PREFIX_ID"
	# Work around WINE bug 41639
	FREETYPE_PROPERTIES="truetype:interpreter-version=35"

	PATH_PREFIX="$WINEPREFIX/drive_c/$GAME_ID"

	export WINEARCH WINEDEBUG WINEDLLOVERRIDES WINEPREFIX FREETYPE_PROPERTIES

	if ! [ -e "$WINEPREFIX" ]; then
	    mkdir --parents "${WINEPREFIX%/*}"
	    # Use LANG=C to avoid localized directory names
	    LANG=C wineboot --init 2>/dev/null
	EOF

	local version_major_target
	local version_minor_target
	version_major_target="${target_version%%.*}"
	version_minor_target=$(printf '%s' "$target_version" | cut --delimiter='.' --fields=2)
	if ! { [ $version_major_target -lt 2 ] || [ $version_minor_target -lt 8 ] ; }; then
		cat >> "$file" <<- 'EOF'
		    # Remove most links pointing outside of the WINE prefix
		    rm "$WINEPREFIX/dosdevices/z:"
		    find "$WINEPREFIX/drive_c/users/$(whoami)" -type l | while read directory; do
		        rm "$directory"
		        mkdir "$directory"
		    done
		EOF
	fi

	if [ "$APP_WINETRICKS" ]; then
		cat >> "$file" <<- EOF
		    winetricks $APP_WINETRICKS
		    sleep 1s
		EOF
	fi

	if [ "$APP_REGEDIT" ]; then
		cat >> "$file" <<- EOF
		    for reg_file in $APP_REGEDIT; do
		EOF
		cat >> "$file" <<- 'EOF'
		    (
		        cd "$WINEPREFIX/drive_c/"
		        cp "$PATH_GAME/$reg_file" .
		        reg_file_basename="${reg_file##*/}"
		        wine regedit "$reg_file_basename"
		        rm "$reg_file_basename"
		    )
		    done
		EOF
	fi

	cat >> "$file" <<- 'EOF'
	fi
	EOF

	cat >> "$file" <<- 'EOF'
	for dir in "$PATH_PREFIX" "$PATH_CONFIG" "$PATH_DATA"; do
	    if [ ! -e "$dir" ]; then
	        mkdir --parents "$dir"
	    fi
	done
	(
	    cd "$PATH_GAME"
	    find . -type d | while read dir; do
	        if [ -h "$PATH_PREFIX/$dir" ]; then
	            rm "$PATH_PREFIX/$dir"
	        fi
	    done
	)
	cp --recursive --remove-destination --symbolic-link "$PATH_GAME"/* "$PATH_PREFIX"
	(
	    cd "$PATH_PREFIX"
	    find . -type l | while read link; do
	        if [ ! -e "$link" ]; then
	            rm "$link"
	        fi
	    done
	    find . -depth -type d | while read dir; do
	        if [ ! -e "$PATH_GAME/$dir" ]; then
	            rmdir --ignore-fail-on-non-empty "$dir"
	        fi
	    done
	)
	init_userdir_files "$PATH_CONFIG" "$CONFIG_FILES"
	init_userdir_files "$PATH_DATA" "$DATA_FILES"
	init_prefix_files "$PATH_CONFIG" "$CONFIG_FILES"
	init_prefix_files "$PATH_DATA" "$DATA_FILES"
	init_prefix_dirs "$PATH_CONFIG" "$CONFIG_DIRS"
	init_prefix_dirs "$PATH_DATA" "$DATA_DIRS"

	EOF
	sed --in-place 's/    /\t/g' "$file"
	return 0
}

# WINE - write launcher script for winecfg
# USAGE: launcher_write_script_wine_winecfg $application
# NEEDED VARS: GAME_ID
# CALLED BY: launcher_write_script_wine_winecfg
launcher_write_script_wine_winecfg() {
	local application
	application="$1"
	# shellcheck disable=SC2034
	APP_WINECFG_ID="${GAME_ID}_winecfg"
	# shellcheck disable=SC2034
	APP_WINECFG_TYPE='wine'
	# shellcheck disable=SC2034
	APP_WINECFG_EXE='winecfg'
	launcher_write_script 'APP_WINECFG'
	return 0
}

# WINE - run the game
# USAGE: launcher_write_script_wine_run $application $file
# CALLS: launcher_write_script_prerun launcher_write_script_postrun
# CALLED BY: launcher_write_script
launcher_write_script_wine_run() {
	# parse arguments
	local application
	local file
	application="$1"
	file="$2"

	cat >> "$file" <<- 'EOF'
	# Run the game

	cd "$PATH_PREFIX"

	EOF

	launcher_write_script_prerun "$application" "$file"

	cat >> "$file" <<- 'EOF'
	wine "$APP_EXE" $APP_OPTIONS $@

	EOF

	launcher_write_script_postrun "$application" "$file"

	return 0
}

# WINE - run winecfg
# USAGE: launcher_write_script_winecfg_run $file
# CALLED BY: launcher_write_script
launcher_write_script_winecfg_run() {
	# parse arguments
	local file
	file="$1"

	cat >> "$file" <<- 'EOF'
	# Run WINE configuration

	winecfg

	EOF

	return 0
}

# write package meta-data
# USAGE: write_metadata [$pkg…]
# NEEDED VARS: (ARCHIVE) GAME_NAME (OPTION_PACKAGE) PACKAGES_LIST (PKG_ARCH) PKG_DEPS_ARCH PKG_DEPS_DEB PKG_DESCRIPTION PKG_ID (PKG_PATH) PKG_PROVIDE
# CALLS: liberror pkg_write_arch pkg_write_deb pkg_write_gentoo set_architecture testvar
write_metadata() {
	if [ $# = 0 ]; then
		write_metadata $PACKAGES_LIST
		return 0
	fi
	local pkg_architecture
	local pkg_description
	local pkg_id
	local pkg_maint
	local pkg_path
	local pkg_provide
	for pkg in "$@"; do
		testvar "$pkg" 'PKG' || liberror 'pkg' 'write_metadata'
		if [ "$OPTION_ARCHITECTURE" != all ] && [ -n "${PACKAGES_LIST##*$pkg*}" ]; then
			skipping_pkg_warning 'write_metadata' "$pkg"
			continue
		fi

		# Set package-specific variables
		set_architecture "$pkg"
		pkg_id="$(get_value "${pkg}_ID")"
		pkg_maint="$(whoami)@$(hostname)"
		pkg_path="$(get_value "${pkg}_PATH")"
		[ -n "$pkg_path" ] || missing_pkg_error 'write_metadata' "$pkg"
		[ "$DRY_RUN" = '1' ] && continue
		pkg_provide="$(get_value "${pkg}_PROVIDE")"

		use_archive_specific_value "${pkg}_DESCRIPTION"
		pkg_description="$(get_value "${pkg}_DESCRIPTION")"

		case $OPTION_PACKAGE in
			('arch')
				pkg_write_arch
			;;
			('deb')
				pkg_write_deb
			;;
			('gentoo')
				pkg_write_gentoo
			;;
			(*)
				liberror 'OPTION_PACKAGE' 'write_metadata'
			;;
		esac
	done
	rm  --force "$postinst" "$prerm"
}

# build .pkg.tar or .deb package
# USAGE: build_pkg [$pkg…]
# NEEDED VARS: (OPTION_COMPRESSION) (LANG) (OPTION_PACKAGE) PACKAGES_LIST (PKG_PATH) PLAYIT_WORKDIR
# CALLS: liberror pkg_build_arch pkg_build_deb pkg_build_gentoo testvar
build_pkg() {
	if [ $# = 0 ]; then
		build_pkg $PACKAGES_LIST
		return 0
	fi
	local pkg_path
	for pkg in "$@"; do
		testvar "$pkg" 'PKG' || liberror 'pkg' 'build_pkg'
		if [ "$OPTION_ARCHITECTURE" != all ] && [ -n "${PACKAGES_LIST##*$pkg*}" ]; then
			skipping_pkg_warning 'build_pkg' "$pkg"
			return 0
		fi
		pkg_path="$(get_value "${pkg}_PATH")"
		[ -n "$pkg_path" ] || missing_pkg_error 'build_pkg' "$PKG"
		case $OPTION_PACKAGE in
			('arch')
				pkg_build_arch "$pkg_path"
			;;
			('deb')
				pkg_build_deb "$pkg_path"
			;;
			('gentoo')
				pkg_build_gentoo "$pkg_path"
			;;
			(*)
				liberror 'OPTION_PACKAGE' 'build_pkg'
			;;
		esac
	done
}

# print package building message
# USAGE: pkg_print $file
# NEEDED VARS: (LANG)
# CALLED BY: pkg_build_arch pkg_build_deb pkg_build_gentoo
pkg_print() {
	local string
	case "${LANG%_*}" in
		('fr')
			string='Construction de %s'
		;;
		('en'|*)
			string='Building %s'
		;;
	esac
	printf "$string" "$1"
}

# print package building message
# USAGE: pkg_build_print_already_exists $file
# NEEDED VARS: (LANG)
# CALLED BY: pkg_build_arch pkg_build_deb pkg_build_gentoo
pkg_build_print_already_exists() {
	local string
	case "${LANG%_*}" in
		('fr')
			string='%s existe déjà.\n'
		;;
		('en'|*)
			string='%s already exists.\n'
		;;
	esac
	printf "$string" "$1"
}

# guess package format to build from host OS
# USAGE: packages_guess_format $variable_name
# NEEDED VARS: (LANG) DEFAULT_OPTION_PACKAGE
packages_guess_format() {
	local guessed_host_os
	local variable_name
	eval variable_name=\"$1\"
	if [ -e '/etc/os-release' ]; then
		guessed_host_os="$(grep '^ID=' '/etc/os-release' | cut --delimiter='=' --fields=2)"
	elif command -v lsb_release >/dev/null 2>&1; then
		guessed_host_os="$(lsb_release --id --short | tr '[:upper:]' '[:lower:]')"
	fi
	case "$guessed_host_os" in
		('debian'|\
		 'ubuntu'|\
		 'linuxmint'|\
		 'handylinux')
			eval $variable_name=\'deb\'
		;;
		('arch'|\
		 'manjaro'|'manjarolinux')
			eval $variable_name=\'arch\'
		;;
		('gentoo')
			eval $variable_name=\'gentoo\'
		;;
		(*)
			print_warning
			case "${LANG%_*}" in
				('fr')
					# shellcheck disable=SC1112
					string1='L’auto-détection du format de paquet le plus adapté a échoué.\n'
					string2='Le format de paquet %s sera utilisé par défaut.\n'
				;;
				('en'|*)
					string1='Most pertinent package format auto-detection failed.\n'
					string2='%s package format will be used by default.\n'
				;;
			esac
			printf "$string1"
			printf "$string2" "$DEFAULT_OPTION_PACKAGE"
			printf '\n'
			eval $variable_name=\'$DEFAULT_OPTION_PACKAGE\'
		;;
	esac
	export ${variable_name?}
}

# write .pkg.tar package meta-data
# USAGE: pkg_write_arch
# NEEDED VARS: GAME_NAME PKG_DEPS_ARCH
# CALLED BY: write_metadata
pkg_write_arch() {
	local pkg_deps
	use_archive_specific_value "${pkg}_DEPS"
	if [ "$(get_value "${pkg}_DEPS")" ]; then
		# shellcheck disable=SC2046
		pkg_set_deps_arch $(get_value "${pkg}_DEPS")
	fi
	use_archive_specific_value "${pkg}_DEPS_ARCH"
	if [ "$(get_value "${pkg}_DEPS_ARCH")" ]; then
		pkg_deps="$pkg_deps $(get_value "${pkg}_DEPS_ARCH")"
	fi
	local pkg_size
	pkg_size=$(du --total --block-size=1 --summarize "$pkg_path" | tail --lines=1 | cut --fields=1)
	local target
	target="$pkg_path/.PKGINFO"

	PKG="$pkg"
	get_package_version

	mkdir --parents "${target%/*}"

	cat > "$target" <<- EOF
	pkgname = $pkg_id
	pkgver = $PKG_VERSION
	packager = $pkg_maint
	builddate = $(date +"%m%d%Y")
	size = $pkg_size
	arch = $pkg_architecture
	EOF

	if [ -n "$pkg_description" ]; then
		# shellcheck disable=SC2154
		cat >> "$target" <<- EOF
		pkgdesc = $GAME_NAME - $pkg_description - ./play.it script version $script_version
		EOF
	else
		# shellcheck disable=SC2154
		cat >> "$target" <<- EOF
		pkgdesc = $GAME_NAME - ./play.it script version $script_version
		EOF
	fi

	for dep in $pkg_deps; do
		cat >> "$target" <<- EOF
		depend = $dep
		EOF
	done

	if [ -n "$pkg_provide" ]; then
		cat >> "$target" <<- EOF
		conflict = $pkg_provide
		provides = $pkg_provide
		EOF
	fi

	target="$pkg_path/.INSTALL"

	if [ -e "$postinst" ]; then
		cat >> "$target" <<- EOF
		post_install() {
		$(cat "$postinst")
		}

		post_upgrade() {
		post_install
		}
		EOF
	fi

	if [ -e "$prerm" ]; then
		cat >> "$target" <<- EOF
		pre_remove() {
		$(cat "$prerm")
		}

		pre_upgrade() {
		pre_remove
		}
		EOF
	fi
}

# set list or Arch Linux dependencies from generic names
# USAGE: pkg_set_deps_arch $dep[…]
# CALLS: pkg_set_deps_arch32 pkg_set_deps_arch64
# CALLED BY: pkg_write_arch
pkg_set_deps_arch() {
	use_archive_specific_value "${pkg}_ARCH"
	local architecture
	architecture="$(get_value "${pkg}_ARCH")"
	case $architecture in
		('32')
			pkg_set_deps_arch32 "$@"
		;;
		('64')
			pkg_set_deps_arch64 "$@"
		;;
	esac
}

# set list or Arch Linux 32-bit dependencies from generic names
# USAGE: pkg_set_deps_arch32 $dep[…]
# CALLED BY: pkg_set_deps_arch
pkg_set_deps_arch32() {
	for dep in "$@"; do
		case $dep in
			('alsa')
				pkg_dep='lib32-alsa-lib lib32-alsa-plugins'
			;;
			('bzip2')
				pkg_dep='lib32-bzip2'
			;;
			('dosbox')
				pkg_dep='dosbox'
			;;
			('freetype')
				pkg_dep='lib32-freetype2'
			;;
			('gcc32')
				pkg_dep='gcc-multilib lib32-gcc-libs'
			;;
			('gconf')
				pkg_dep='lib32-gconf'
			;;
			('glibc')
				pkg_dep='lib32-glibc'
			;;
			('glu')
				pkg_dep='lib32-glu'
			;;
			('glx')
				pkg_dep='lib32-libgl'
			;;
			('gtk2')
				pkg_dep='lib32-gtk2'
			;;
			('java')
				pkg_dep='jre8-openjdk'
			;;
			('json')
				pkg_dep='lib32-json-c'
			;;
			('libcurl')
				pkg_dep='lib32-curl'
			;;
			('libcurl-gnutls')
				pkg_dep='lib32-libcurl-gnutls'
			;;
			('libstdc++')
				pkg_dep='lib32-gcc-libs'
			;;
			('libudev1')
				pkg_dep='lib32-systemd'
			;;
			('libxrandr')
				pkg_dep='lib32-libxrandr'
			;;
			('nss')
				pkg_dep='lib32-nss'
			;;
			('openal')
				pkg_dep='lib32-openal'
			;;
			('pulseaudio')
				pkg_dep='pulseaudio'
			;;
			('sdl1.2')
				pkg_dep='lib32-sdl'
			;;
			('sdl2')
				pkg_dep='lib32-sdl2'
			;;
			('sdl2_image')
				pkg_dep='lib32-sdl2_image'
			;;
			('sdl2_mixer')
				pkg_dep='lib32-sdl2_mixer'
			;;
			('theora')
				pkg_dep='lib32-libtheora'
			;;
			('vorbis')
				pkg_dep='lib32-libvorbis'
			;;
			('wine'|'wine32'|'wine64')
				pkg_dep='wine'
			;;
			('wine-staging'|'wine32-staging'|'wine64-staging')
				pkg_dep='wine-staging'
			;;
			('winetricks')
				pkg_dep='winetricks'
			;;
			('xcursor')
				pkg_dep='lib32-libxcursor'
			;;
			('xft')
				pkg_dep='lib32-libxft'
			;;
			('xgamma')
				pkg_dep='xorg-xgamma'
			;;
			('xrandr')
				pkg_dep='xorg-xrandr'
			;;
			(*)
				pkg_deps="$dep"
			;;
		esac
		pkg_deps="$pkg_deps $pkg_dep"
	done
}

# set list or Arch Linux 64-bit dependencies from generic names
# USAGE: pkg_set_deps_arch64 $dep[…]
# CALLED BY: pkg_set_deps_arch
pkg_set_deps_arch64() {
	for dep in "$@"; do
		case $dep in
			('alsa')
				pkg_dep='alsa-lib alsa-plugins'
			;;
			('bzip2')
				pkg_dep='bzip2'
			;;
			('dosbox')
				pkg_dep='dosbox'
			;;
			('freetype')
				pkg_dep='freetype2'
			;;
			('gcc32')
				pkg_dep='gcc-multilib lib32-gcc-libs'
			;;
			('gconf')
				pkg_dep='gconf'
			;;
			('glibc')
				pkg_dep='glibc'
			;;
			('glu')
				pkg_dep='glu'
			;;
			('glx')
				pkg_dep='libgl'
			;;
			('gtk2')
				pkg_dep='gtk2'
			;;
			('java')
				pkg_dep='jre8-openjdk'
			;;
			('json')
				pkg_dep='json-c'
			;;
			('libcurl')
				pkg_dep='curl'
			;;
			('libcurl-gnutls')
				pkg_dep='libcurl-gnutls'
			;;
			('libstdc++')
				pkg_dep='gcc-libs'
			;;
			('libudev1')
				pkg_dep='libsystemd'
			;;
			('libxrandr')
				pkg_dep='libxrandr'
			;;
			('nss')
				pkg_dep='nss'
			;;
			('openal')
				pkg_dep='openal'
			;;
			('pulseaudio')
				pkg_dep='pulseaudio'
			;;
			('sdl1.2')
				pkg_dep='sdl'
			;;
			('sdl2')
				pkg_dep='sdl2'
			;;
			('sdl2_image')
				pkg_dep='sdl2_image'
			;;
			('sdl2_mixer')
				pkg_dep='sdl2_mixer'
			;;
			('theora')
				pkg_dep='libtheora'
			;;
			('vorbis')
				pkg_dep='libvorbis'
			;;
			('wine'|'wine32'|'wine64')
				pkg_dep='wine'
			;;
			('winetricks')
				pkg_dep='winetricks'
			;;
			('xcursor')
				pkg_dep='libxcursor'
			;;
			('xft')
				pkg_dep='libxft'
			;;
			('xgamma')
				pkg_dep='xorg-xgamma'
			;;
			('xrandr')
				pkg_dep='xorg-xrandr'
			;;
			(*)
				pkg_dep="$dep"
			;;
		esac
		pkg_deps="$pkg_deps $pkg_dep"
	done
}

# build .pkg.tar package
# USAGE: pkg_build_arch $pkg_path
# NEEDED VARS: (OPTION_COMPRESSION) (LANG) PLAYIT_WORKDIR
# CALLS: pkg_print
# CALLED BY: build_pkg
pkg_build_arch() {
	local pkg_filename
	pkg_filename="$PWD/${1##*/}.pkg.tar"

	if [ -e "$pkg_filename" ]; then
		pkg_build_print_already_exists "${pkg_filename##*/}"
		eval ${pkg}_PKG=\"$pkg_filename\"
		export ${pkg?}_PKG
		return 0
	fi

	local tar_options
	tar_options='--create --group=root --owner=root'

	case $OPTION_COMPRESSION in
		('gzip')
			tar_options="$tar_options --gzip"
			pkg_filename="${pkg_filename}.gz"
		;;
		('xz')
			tar_options="$tar_options --xz"
			pkg_filename="${pkg_filename}.xz"
		;;
		('bzip2')
			tar_options="$tar_options --bzip2"
			pkg_filename="${pkg_filename}.bz2"
		;;
		('none') ;;
		(*)
			liberror 'OPTION_COMPRESSION' 'pkg_build_arch'
		;;
	esac

	pkg_print "${pkg_filename##*/}"
	if [ "$DRY_RUN" = '1' ]; then
		printf '\n'
		eval ${pkg}_PKG=\"$pkg_filename\"
		export ${pkg?}_PKG
		return 0
	fi

	(
		cd "$1"
		local files
		files='.PKGINFO *'
		if [ -e '.INSTALL' ]; then
			files=".INSTALL $files"
		fi
		tar $tar_options --file "$pkg_filename" $files
	)

	eval ${pkg}_PKG=\"$pkg_filename\"
	export ${pkg?}_PKG

	print_ok
}

# write .deb package meta-data
# USAGE: pkg_write_deb
# NEEDED VARS: GAME_NAME PKG_DEPS_DEB
# CALLED BY: write_metadata
pkg_write_deb() {
	local pkg_deps
	use_archive_specific_value "${pkg}_DEPS"
	if [ "$(get_value "${pkg}_DEPS")" ]; then
		# shellcheck disable=SC2046
		pkg_set_deps_deb $(get_value "${pkg}_DEPS")
	fi
	use_archive_specific_value "${pkg}_DEPS_DEB"
	if [ "$(get_value "${pkg}_DEPS_DEB")" ]; then
		if [ -n "$pkg_deps" ]; then
			pkg_deps="$pkg_deps, $(get_value "${pkg}_DEPS_DEB")"
		else
			pkg_deps="$(get_value "${pkg}_DEPS_DEB")"
		fi
	fi
	local pkg_size
	pkg_size=$(du --total --block-size=1K --summarize "$pkg_path" | tail --lines=1 | cut --fields=1)
	local target
	target="$pkg_path/DEBIAN/control"

	PKG="$pkg"
	get_package_version

	mkdir --parents "${target%/*}"

	cat > "$target" <<- EOF
	Package: $pkg_id
	Version: $PKG_VERSION
	Architecture: $pkg_architecture
	Multi-Arch: foreign
	Maintainer: $pkg_maint
	Installed-Size: $pkg_size
	Section: non-free/games
	EOF

	if [ -n "$pkg_provide" ]; then
		cat >> "$target" <<- EOF
		Conflicts: $pkg_provide
		Provides: $pkg_provide
		Replaces: $pkg_provide
		EOF
	fi

	if [ -n "$pkg_deps" ]; then
		cat >> "$target" <<- EOF
		Depends: $pkg_deps
		EOF
	fi

	if [ -n "$pkg_description" ]; then
		# shellcheck disable=SC2154
		cat >> "$target" <<- EOF
		Description: $GAME_NAME - $pkg_description
		 ./play.it script version $script_version
		EOF
	else
		# shellcheck disable=SC2154
		cat >> "$target" <<- EOF
		Description: $GAME_NAME
		 ./play.it script version $script_version
		EOF
	fi

	if [ -e "$postinst" ]; then
		target="$pkg_path/DEBIAN/postinst"
		cat > "$target" <<- EOF
		#!/bin/sh -e

		$(cat "$postinst")

		exit 0
		EOF
		chmod 755 "$target"
	fi

	if [ -e "$prerm" ]; then
		target="$pkg_path/DEBIAN/prerm"
		cat > "$target" <<- EOF
		#!/bin/sh -e

		$(cat "$prerm")

		exit 0
		EOF
		chmod 755 "$target"
	fi
}

# set list of Debian dependencies from generic names
# USAGE: pkg_set_deps_deb $dep[…]
# CALLED BY: pkg_write_deb
pkg_set_deps_deb() {
	local architecture
	for dep in "$@"; do
		case $dep in
			('alsa')
				pkg_dep='libasound2-plugins'
			;;
			('bzip2')
				pkg_dep='libbz2-1.0'
			;;
			('dosbox')
				pkg_dep='dosbox'
			;;
			('freetype')
				pkg_dep='libfreetype6'
			;;
			('gcc32')
				pkg_dep='gcc-multilib:amd64 | gcc'
			;;
			('gconf')
				pkg_dep='libgconf-2-4'
			;;
			('glibc')
				pkg_dep='libc6'
			;;
			('glu')
				pkg_dep='libglu1-mesa | libglu1'
			;;
			('glx')
				pkg_dep='libgl1 | libgl1-mesa-glx, libglx-mesa0 | libgl1-mesa-glx'
			;;
			('gtk2')
				pkg_dep='libgtk2.0-0'
			;;
			('java')
				pkg_dep='default-jre:amd64 | java-runtime:amd64 | default-jre | java-runtime'
			;;
			('json')
				pkg_dep='libjson-c3 | libjson-c2 | libjson0'
			;;
			('libcurl')
				pkg_dep='libcurl4 | libcurl3'
			;;
			('libcurl-gnutls')
				pkg_dep='libcurl3-gnutls'
			;;
			('libstdc++')
				pkg_dep='libstdc++6'
			;;
			('libudev1')
				pkg_dep='libudev1'
			;;
			('libxrandr')
				pkg_dep='libxrandr2'
			;;
			('nss')
				pkg_dep='libnss3'
			;;
			('openal')
				pkg_dep='libopenal1'
			;;
			('pulseaudio')
				pkg_dep='pulseaudio:amd64 | pulseaudio'
			;;
			('sdl1.2')
				pkg_dep='libsdl1.2debian'
			;;
			('sdl2')
				pkg_dep='libsdl2-2.0-0'
			;;
			('sdl2_image')
				pkg_dep='libsdl2-image-2.0-0'
			;;
			('sdl2_mixer')
				pkg_dep='libsdl2-mixer-2.0-0'
			;;
			('theora')
				pkg_dep='libtheora0'
			;;
			('vorbis')
				pkg_dep='libvorbisfile3'
			;;
			('wine')
				use_archive_specific_value "${pkg}_ARCH"
				architecture="$(get_value "${pkg}_ARCH")"
				case "$architecture" in
					('32') pkg_set_deps_deb 'wine32' ;;
					('64') pkg_set_deps_deb 'wine64' ;;
				esac
			;;
			('wine32')
				pkg_dep='wine32-development | wine32 | wine-bin | wine-i386 | wine-staging-i386, wine:amd64 | wine'
			;;
			('wine64')
				pkg_dep='wine64-development | wine64 | wine64-bin | wine-amd64 | wine-staging-amd64, wine'
			;;
			('wine-staging')
				use_archive_specific_value "${pkg}_ARCH"
				architecture="$(get_value "${pkg}_ARCH")"
				case "$architecture" in
					('32') pkg_set_deps_deb 'wine32-staging' ;;
					('64') pkg_set_deps_deb 'wine64-staging' ;;
				esac
			;;
			('wine32-staging')
				pkg_dep='wine-staging-i386, winehq-staging:amd64 | winehq-staging'
			;;
			('wine64-staging')
				pkg_dep='wine-staging-amd64, winehq-staging'
			;;
			('winetricks')
				pkg_dep='winetricks'
			;;
			('xcursor')
				pkg_dep='libxcursor1'
			;;
			('xft')
				pkg_dep='libxft2'
			;;
			('xgamma'|'xrandr')
				pkg_dep='x11-xserver-utils:amd64 | x11-xserver-utils'
			;;
			(*)
				pkg_dep="$dep"
			;;
		esac
		if [ -n "$pkg_deps" ]; then
			pkg_deps="$pkg_deps, $pkg_dep"
		else
			pkg_deps="$pkg_dep"
		fi
	done
}

# build .deb package
# USAGE: pkg_build_deb $pkg_path
# NEEDED VARS: (OPTION_COMPRESSION) (LANG) PLAYIT_WORKDIR
# CALLS: pkg_print
# CALLED BY: build_pkg
pkg_build_deb() {
	local pkg_filename
	pkg_filename="$PWD/${1##*/}.deb"
	if [ -e "$pkg_filename" ]; then
		pkg_build_print_already_exists "${pkg_filename##*/}"
		eval ${pkg}_PKG=\"$pkg_filename\"
		export ${pkg?}_PKG
		return 0
	fi

	local dpkg_options
	case $OPTION_COMPRESSION in
		('gzip'|'none'|'xz')
			dpkg_options="-Z$OPTION_COMPRESSION"
		;;
		(*)
			liberror 'OPTION_COMPRESSION' 'pkg_build_deb'
		;;
	esac

	pkg_print "${pkg_filename##*/}"
	if [ "$DRY_RUN" = '1' ]; then
		printf '\n'
		eval ${pkg}_PKG=\"$pkg_filename\"
		export ${pkg?}_PKG
		return 0
	fi
	TMPDIR="$PLAYIT_WORKDIR" fakeroot -- dpkg-deb $dpkg_options --build "$1" "$pkg_filename" 1>/dev/null
	eval ${pkg}_PKG=\"$pkg_filename\"
	export ${pkg?}_PKG

	print_ok
}

# Get packages that provides the given package
# USAGE: gentoo_get_pkg_providers $provided_package
# NEEDED VARS: PACKAGES_LIST pkg
# CALLED BY: pkg_write_gentoo pkg_set_deps_gentoo
gentoo_get_pkg_providers() {
	local provided="$1"
	for package in $PACKAGES_LIST; do
		if [ "$package" != "$pkg" ]; then
			use_archive_specific_value "${package}_ID"
			if [ "$(get_value "${package}_PROVIDE")" = "$provided" ]; then
				printf '%s\n' "$(get_value "${package}_ID")"
			fi
		fi
	done
}

# write .ebuild package meta-data
# USAGE: pkg_write_gentoo
# NEEDED VARS: GAME_NAME PKG_DEPS_GENTOO
# CALLS: gentoo_get_pkg_providers
# CALLED BY: write_metadata
pkg_write_gentoo() {
	pkg_id="$(printf '%s' "$pkg_id" | sed 's/-/_/g')" # This makes sure numbers in the package name doesn't get interpreted as a version by portage

	local pkg_deps
	use_archive_specific_value "${pkg}_DEPS"
	if [ "$(get_value "${pkg}_DEPS")" ]; then
		# shellcheck disable=SC2046
		pkg_set_deps_gentoo $(get_value "${pkg}_DEPS")
		export GENTOO_OVERLAYS
	fi
	use_archive_specific_value "${pkg}_DEPS_GENTOO"
	if [ "$(get_value "${pkg}_DEPS_GENTOO")" ]; then
		pkg_deps="$pkg_deps $(get_value "${pkg}_DEPS_GENTOO")"
	fi

	if [ -n "$pkg_provide" ]; then
		for package_provide in $pkg_provide; do
			pkg_deps="$pkg_deps $(gentoo_get_pkg_providers "$package_provide" | sed -e 's/-/_/g' -e 's|^|!!games-playit/|')"
		done
	fi

	PKG="$pkg"
	get_package_version

	mkdir --parents \
		"$PLAYIT_WORKDIR/$pkg/gentoo-overlay/metadata" \
		"$PLAYIT_WORKDIR/$pkg/gentoo-overlay/profiles" \
		"$PLAYIT_WORKDIR/$pkg/gentoo-overlay/games-playit/$pkg_id/files"
	printf '%s\n' "masters = gentoo" > "$PLAYIT_WORKDIR/$pkg/gentoo-overlay/metadata/layout.conf"
	printf '%s\n' 'games-playit' > "$PLAYIT_WORKDIR/$pkg/gentoo-overlay/profiles/categories"
	ln --symbolic --force --no-target-directory "$pkg_path" "$PLAYIT_WORKDIR/$pkg/gentoo-overlay/games-playit/$pkg_id/files/install"
	local target
	target="$PLAYIT_WORKDIR/$pkg/gentoo-overlay/games-playit/$pkg_id/$pkg_id-$PKG_VERSION.ebuild"

	cat > "$target" <<- EOF
	EAPI=7
	RESTRICT="fetch strip binchecks"
	EOF
	local pkg_architectures
	set_supported_architectures "$PKG"
	cat >> "$target" <<- EOF
	KEYWORDS="$pkg_architectures"
	EOF

	if [ -n "$pkg_description" ]; then
		cat >> "$target" <<- EOF
		DESCRIPTION="$GAME_NAME - $pkg_description - ./play.it script version $script_version"
		EOF
	else
		cat >> "$target" <<- EOF
		DESCRIPTION="$GAME_NAME - ./play.it script version $script_version"
		EOF
	fi

	cat >> "$target" <<- EOF
	SLOT="0"
	EOF

	# fowners is needed to make sure all files in the generated package belong to root (arch linux packages use tar options that do the same thing)
	cat >> "$target" <<- EOF
	RDEPEND="$pkg_deps"

	src_unpack() {
		mkdir --parents "\$S"
	}
	src_install() {
		cp --recursive --link \$FILESDIR/install/* \$ED/
		fowners --recursive root:root /
	}
	EOF

	if [ -e "$postinst" ]; then
		cat >> "$target" <<- EOF
		pkg_postinst() {
		$(cat "$postinst")
		}
		EOF
	fi

	if [ -e "$prerm" ]; then
		cat >> "$target" <<- EOF
		pkg_prerm() {
		$(cat "$prerm")
		}
		EOF
	fi
}

# set list or Gentoo Linux dependencies from generic names
# USAGE: pkg_set_deps_gentoo $dep[…]
# CALLS: gentoo_get_pkg_providers
# CALLED BY: pkg_write_gentoo
pkg_set_deps_gentoo() {
	use_archive_specific_value "${pkg}_ARCH"
	local architecture
	architecture="$(get_value "${pkg}_ARCH")"
	local architecture_suffix
	local architecture_suffix_use
	case $architecture in
		('32')
			architecture_suffix='[abi_x86_32]'
			architecture_suffix_use=',abi_x86_32'
		;;
		('64')
			architecture_suffix=''
			architecture_suffix_use=''
		;;
	esac
	for dep in "$@"; do
		case $dep in
			('alsa')
				pkg_dep="media-libs/alsa-lib$architecture_suffix media-plugins/alsa-plugins$architecture_suffix"
			;;
			('bzip2')
				pkg_dep="app-arch/bzip2$architecture_suffix"
			;;
			('dosbox')
				pkg_dep="games-emulation/dosbox"
			;;
			('freetype')
				pkg_dep="media-libs/freetype$architecture_suffix"
			;;
			('gcc32')
				pkg_dep='' #gcc (in @system) should be multilib unless it is a no-multilib profile, in which case the 32 bits libraries wouldn't work
			;;
			('gconf')
				pkg_dep="gnome-base/gconf$architecture_suffix"
			;;
			('glibc')
				pkg_dep="sys-libs/glibc"
				if [ "$architecture" = '32' ]; then
					pkg_dep="$pkg_dep amd64? ( sys-libs/glibc[multilib] )"
				fi
			;;
			('glu')
				pkg_dep="virtual/glu$architecture_suffix"
			;;
			('glx')
				pkg_dep="virtual/opengl$architecture_suffix"
			;;
			('gtk2')
				pkg_dep="x11-libs/gtk+:2$architecture_suffix"
			;;
			('java')
				pkg_dep='virtual/jre'
			;;
			('json')
				pkg_dep="dev-libs/json-c$architecture_suffix"
			;;
			('libcurl')
				pkg_dep="net-misc/curl$architecture_suffix"
			;;
			('libcurl-gnutls')
				pkg_dep="net-libs/libcurl-debian$architecture_suffix"
				pkg_overlay='steam-overlay'
			;;
			('libstdc++')
				pkg_dep='' #maybe this should be virtual/libstdc++, otherwise, it is included in gcc, which should be in @system
			;;
			('libudev1')
				pkg_dep="virtual/libudev$architecture_suffix"
			;;
			('libxrandr')
				pkg_dep="x11-libs/libXrandr$architecture_suffix"
			;;
			('nss')
				pkg_dep="dev-libs/nss$architecture_suffix"
			;;
			('openal')
				pkg_dep="media-libs/openal$architecture_suffix"
			;;
			('pulseaudio')
				pkg_dep='media-sound/pulseaudio'
			;;
			('sdl1.2')
				pkg_dep="media-libs/libsdl$architecture_suffix"
			;;
			('sdl2')
				pkg_dep="media-libs/libsdl2$architecture_suffix"
			;;
			('sdl2_image')
				pkg_dep="media-libs/sdl2-image$architecture_suffix"
			;;
			('sdl2_mixer')
				#Most games will require at least one of flac, mp3, vorbis or wav USE flags, it should better to require them all instead of not requiring any and having non-fonctionnal sound in some games.
				pkg_dep="media-libs/sdl2-mixer[flac,mp3,vorbis,wav$architecture_suffix_use]"
			;;
			('theora')
				pkg_dep="media-libs/libtheora$architecture_suffix"
			;;
			('vorbis')
				pkg_dep="media-libs/libvorbis$architecture_suffix"
			;;
			('wine')
				use_archive_specific_value "${pkg}_ARCH"
				architecture="$(get_value "${pkg}_ARCH")"
				case "$architecture" in
					('32') pkg_set_deps_gentoo 'wine32' ;;
					('64') pkg_set_deps_gentoo 'wine64' ;;
				esac
			;;
			('wine32')
				pkg_dep='virtual/wine[abi_x86_32]'
			;;
			('wine64')
				pkg_dep='virtual/wine[abi_x86_64]'
			;;
			('wine-staging')
				use_archive_specific_value "${pkg}_ARCH"
				architecture="$(get_value "${pkg}_ARCH")"
				case "$architecture" in
					('32') pkg_set_deps_gentoo 'wine32-staging' ;;
					('64') pkg_set_deps_gentoo 'wine64-staging' ;;
				esac
			;;
			('wine32-staging')
				pkg_dep='virtual/wine[staging,abi_x86_32]'
			;;
			('wine64-staging')
				pkg_dep='virtual/wine[staging,abi_x86_64]'
			;;
			('winetricks')
				pkg_dep="app-emulation/winetricks$architecture_suffix"
			;;
			('xcursor')
				pkg_dep="x11-libs/libXcursor$architecture_suffix"
			;;
			('xft')
				pkg_dep="x11-libs/libXft$architecture_suffix"
			;;
			('xgamma')
				pkg_dep='x11-apps/xgamma'
			;;
			('xrandr')
				pkg_dep='x11-apps/xrandr'
			;;
			(*)
				pkg_dep="$(gentoo_get_pkg_providers "$dep" | sed -e 's/-/_/g' -e 's|^|games-playit/|')"
				if [ -z "$pkg_dep" ]; then
					pkg_dep='games-playit/'"$(printf '%s' "$dep" | sed 's/-/_/g')"
				else
					pkg_dep="|| ( $pkg_dep )"
				fi
			;;
		esac
		pkg_deps="$pkg_deps $pkg_dep"
		if [ -n "$pkg_overlay" ]; then
			if ! printf '%s' "$GENTOO_OVERLAYS" | sed --regexp-extended 's/\s+/\n/g' | grep --fixed-strings --line-regexp --quiet "$pkg_overlay"; then
				GENTOO_OVERLAYS="$GENTOO_OVERLAYS $pkg_overlay"
			fi
			pkg_overlay=''
		fi
	done
}

# build .tbz2 gentoo package
# USAGE: pkg_build_gentoo $pkg_path
# NEEDED VARS: (LANG) PLAYIT_WORKDIR
# CALLS: pkg_print
# CALLED BY: build_pkg
pkg_build_gentoo() {
	pkg_id="$(get_value "${pkg}_ID" | sed 's/-/_/g')" # This makes sure numbers in the package name doesn't get interpreted as a version by portage

	local pkg_filename_base="$pkg_id-$PKG_VERSION.tbz2"
	for package in $PACKAGES_LIST; do
		if [ "$package" != "$pkg" ] && [ "$(get_value "${package}_ID" | sed 's/-/_/g')" = "$pkg_id" ]; then
			set_architecture "$pkg"
			[ -d "$PWD/$pkg_architecture" ] || mkdir "$PWD/$pkg_architecture"
			pkg_filename_base="$pkg_architecture/$pkg_filename_base"
		fi
	done
	local pkg_filename="$PWD/$pkg_filename_base"

	if [ -e "$pkg_filename" ]; then
		pkg_build_print_already_exists "$pkg_filename_base"
		eval ${pkg}_PKG=\"$pkg_filename\"
		export ${pkg}_PKG
		return 0
	fi

	pkg_print "$pkg_filename_base"
	if [ "$DRY_RUN" = '1' ]; then
		printf '\n'
		eval ${pkg}_PKG=\"$pkg_filename\"
		export ${pkg}_PKG
		return 0
	fi

	mkdir --parents "$PLAYIT_WORKDIR/portage-tmpdir"
	local ebuild_path="$PLAYIT_WORKDIR/$pkg/gentoo-overlay/games-playit/$pkg_id/$pkg_id-$PKG_VERSION.ebuild"
	ebuild "$ebuild_path" manifest 1>/dev/null
	PORTAGE_TMPDIR="$PLAYIT_WORKDIR/portage-tmpdir" PKGDIR="$PLAYIT_WORKDIR/gentoo-pkgdir" BINPKG_COMPRESS="$OPTION_COMPRESSION" fakeroot-ng -- ebuild "$ebuild_path" package 1>/dev/null
	mv "$PLAYIT_WORKDIR/gentoo-pkgdir/games-playit/$pkg_id-$PKG_VERSION.tbz2" "$pkg_filename"
	rm --recursive "$PLAYIT_WORKDIR/portage-tmpdir"

	eval ${pkg}_PKG=\"$pkg_filename\"
	export ${pkg}_PKG

	print_ok
}

# display an error if a function is called without an argument
# USAGE: error_missing_argument $function
# CALLS: print_error
error_missing_argument() {
	local function
	function="$1"
	local string
	print_error
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='La fonction "%s" ne peut pas être appelée sans argument.\n'
		;;
		('en'|*)
			string='"%s" function can not be called without an argument.\n'
		;;
	esac
	printf "$string" "$function"
	exit 1
}

# display an error if a function is called more than one argument
# USAGE: error_extra_arguments $function
# CALLS: print_error
error_extra_arguments() {
	local function
	function="$1"
	local string
	print_error
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='La fonction "%s" ne peut pas être appelée avec plus d’un argument.\n'
		;;
		('en'|*)
			string='"%s" function can not be called with mor than one single argument.\n'
		;;
	esac
	printf "$string" "$function"
	exit 1
}

# display an error if function is called while $PKG is unset
# USAGE: error_no_pkg $function
# CALLS: print_error
error_no_pkg() {
	local function
	function="$1"
	local string
	print_error
	case "${LANG%_*}" in
		('fr')
			# shellcheck disable=SC1112
			string='La fonction "%s" ne peut pas être appelée lorsque $PKG n’a pas de valeur définie.\n'
		;;
		('en'|*)
			string='"%s" function can not be called when $PKG is not set.\n'
		;;
	esac
	printf "$string" "$function"
	exit 1
}

# display an error if a file is expected and something else has been given
# USAGE: error_not_a_file $param
# CALLS: print_error
error_not_a_file() {
	if [ $# -lt 1 ]; then
		error_missing_argument 'error_not_a_file'
	fi
	if [ $# -gt 1 ]; then
		error_extra_arguments 'error_not_a_file'
	fi
	local param
	param="$1"
	print_error
	case "${LANG%_*}" in
		('fr')
			string='"%s" nʼest pas un fichier valide.\n'
		;;
		('en'|*)
			string='"%s" is not a valid file.\n'
		;;
	esac
	printf "$string" "$param"
	exit 1
}

# display an error when an unknown application type is used
# USAGE: error_unknown_application_type $app_type
# CALLS: print_error
error_unknown_application_type() {
	local application_type
	application_type="$1"
	local string
	print_error
	case "${LANG%_*}" in
		('fr')
			string='Le type dʼapplication "%s" est inconnu.\n'
			string="$string"'Merci de signaler cette erreur sur notre outil de gestion de bugs : %s\n'
		;;
		('en'|*)
			string='"%s" application type is unknown.\n'
			string="$string"'Please report this issue in our bug tracker: %s\n'
		;;
	esac
	printf "$string" "$application_type" "$PLAYIT_GAMES_BUG_TRACKER_URL"
	exit 1
}

# Keep compatibility with 2.10 and older

write_bin() {
	local application
	for application in "$@"; do
		launcher_write_script "$application"
	done
}

write_desktop() {
	local application
	for application in "$@"; do
		launcher_write_desktop "$application"
	done
}

write_desktop_winecfg() {
	launcher_write_desktop 'APP_WINECFG'
}

write_launcher() {
	launchers_write "$@"
}

# Keep compatibility with 2.7 and older

extract_and_sort_icons_from() {
	icons_get_from_package "$@"
}

extract_icon_from() {
	local destination
	local file
	destination="$PLAYIT_WORKDIR/icons"
	mkdir --parents "$destination"
	for file in "$@"; do
		extension="${file##*.}"
		case "$extension" in
			('exe')
				icon_extract_ico_from_exe "$file" "$destination"
			;;
			(*)
				icon_extract_png_from_file "$file" "$destination"
			;;
		esac
	done
}

get_icon_from_temp_dir() {
	icons_get_from_workdir "$@"
}

move_icons_to() {
	icons_move_to "$@"
}

postinst_icons_linking() {
	icons_linking_postinst "$@"
}

# Keep compatibility with 2.6.0 and older

set_archive() {
	archive_set "$@"
}

set_archive_error_not_found() {
	archive_set_error_not_found "$@"
}

if [ "${0##*/}" != 'libplayit2.sh' ] && [ -z "$LIB_ONLY" ]; then

	# Set input field separator to default value (space, tab, newline)
	unset IFS

	# Check library version against script target version

	version_major_library="${library_version%%.*}"
	# shellcheck disable=SC2154
	version_major_target="${target_version%%.*}"

	version_minor_library=$(printf '%s' "$library_version" | cut --delimiter='.' --fields=2)
	# shellcheck disable=SC2154
	version_minor_target=$(printf '%s' "$target_version" | cut --delimiter='.' --fields=2)

	if [ $version_major_library -ne $version_major_target ] || [ $version_minor_library -lt $version_minor_target ]; then
		print_error
		case "${LANG%_*}" in
			('fr')
				string1='Mauvaise version de libplayit2.sh\n'
				string2='La version cible est : %s\n'
			;;
			('en'|*)
				string1='Wrong version of libplayit2.sh\n'
				string2='Target version is: %s\n'
			;;
		esac
		printf "$string1"
		# shellcheck disable=SC2154
		printf "$string2" "$target_version"
		exit 1
	fi

	# Set URL for error messages

	PLAYIT_GAMES_BUG_TRACKER_URL='https://framagit.org/vv221/play.it-games/issues'

	# Set allowed values for common options

	# shellcheck disable=SC2034
	ALLOWED_VALUES_ARCHITECTURE='all 32 64 auto'
	# shellcheck disable=SC2034
	ALLOWED_VALUES_CHECKSUM='none md5'
	# shellcheck disable=SC2034
	ALLOWED_VALUES_COMPRESSION='none gzip xz bzip2'
	# shellcheck disable=SC2034
	ALLOWED_VALUES_PACKAGE='arch deb gentoo'

	# Set default values for common options

	# shellcheck disable=SC2034
	DEFAULT_OPTION_ARCHITECTURE='all'
	# shellcheck disable=SC2034
	DEFAULT_OPTION_CHECKSUM='md5'
	# shellcheck disable=SC2034
	DEFAULT_OPTION_COMPRESSION='none'
	# shellcheck disable=SC2034
	DEFAULT_OPTION_PREFIX='/usr/local'
	# shellcheck disable=SC2034
	DEFAULT_OPTION_PACKAGE='deb'
	unset winecfg_desktop
	unset winecfg_launcher

	# Parse arguments given to the script

	unset OPTION_ARCHITECTURE
	unset OPTION_CHECKSUM
	unset OPTION_COMPRESSION
	unset OPTION_PREFIX
	unset OPTION_PACKAGE
	unset SOURCE_ARCHIVE
	DRY_RUN='0'
	NO_FREE_SPACE_CHECK='0'

	while [ $# -gt 0 ]; do
		case "$1" in
			('--help')
				help
				exit 0
			;;
			('--architecture='*|\
			 '--architecture'|\
			 '--checksum='*|\
			 '--checksum'|\
			 '--compression='*|\
			 '--compression'|\
			 '--prefix='*|\
			 '--prefix'|\
			 '--package='*|\
			 '--package')
				if [ "${1%=*}" != "${1#*=}" ]; then
					option="$(printf '%s' "${1%=*}" | sed 's/^--//')"
					value="${1#*=}"
				else
					option="$(printf '%s' "$1" | sed 's/^--//')"
					value="$2"
					shift 1
				fi
				if [ "$value" = 'help' ]; then
					eval help_$option
					exit 0
				else
					# shellcheck disable=SC2046
					eval OPTION_$(printf '%s' "$option" | tr '[:lower:]' '[:upper:]')=\"$value\"
					# shellcheck disable=SC2046
					export OPTION_$(printf '%s' "$option" | tr '[:lower:]' '[:upper:]')
				fi
				unset option
				unset value
			;;
			('--dry-run')
				DRY_RUN='1'
				export DRY_RUN
			;;
			('--skip-free-space-check')
				NO_FREE_SPACE_CHECK='1'
				export NO_FREE_SPACE_CHECK
			;;
			('--'*)
				print_error
				case "${LANG%_*}" in
					('fr')
						string='Option inconnue : %s\n'
					;;
					('en'|*)
						string='Unkown option: %s\n'
					;;
				esac
				printf "$string" "$1"
				return 1
			;;
			(*)
				if [ -f "$1" ]; then
					SOURCE_ARCHIVE="$1"
					export SOURCE_ARCHIVE
				else
					error_not_a_file "$1"
				fi
			;;
		esac
		shift 1
	done

	# Try to detect the host distribution if no package format has been explicitely set

	[ "$OPTION_PACKAGE" ] || packages_guess_format 'OPTION_PACKAGE'

	# Set options not already set by script arguments to default values

	for option in 'ARCHITECTURE' 'CHECKSUM' 'COMPRESSION' 'PREFIX'; do
		if [ -z "$(get_value "OPTION_$option")" ]\
		&& [ -n "$(get_value "DEFAULT_OPTION_$option")" ]; then
			# shellcheck disable=SC2046
			eval OPTION_$option=\"$(get_value "DEFAULT_OPTION_$option")\"
			export OPTION_$option
		fi
	done

	# Check options values validity

	check_option_validity() {
		local name
		name="$1"
		local value
		value="$(get_value "OPTION_$option")"
		local allowed_values
		allowed_values="$(get_value "ALLOWED_VALUES_$option")"
		for allowed_value in $allowed_values; do
			if [ "$value" = "$allowed_value" ]; then
				return 0
			fi
		done
		print_error
		local string1
		local string2
		case "${LANG%_*}" in
			('fr')
				# shellcheck disable=SC1112
				string1='%s n’est pas une valeur valide pour --%s.\n'
				# shellcheck disable=SC1112
				string2='Lancez le script avec l’option --%s=help pour une liste des valeurs acceptés.\n'
			;;
			('en'|*)
				string1='%s is not a valid value for --%s.\n'
				string2='Run the script with the option --%s=help to get a list of supported values.\n'
			;;
		esac
		printf "$string1" "$value" "$(printf '%s' $option | tr '[:upper:]' '[:lower:]')"
		printf "$string2" "$(printf '%s' $option | tr '[:upper:]' '[:lower:]')"
		printf '\n'
		exit 1
	}

	for option in 'CHECKSUM' 'COMPRESSION' 'PACKAGE'; do
		check_option_validity "$option"
	done

	# Do not allow bzip2 compression when building Debian packages

	if
		[ "$OPTION_PACKAGE" = 'deb' ] && \
		[ "$OPTION_COMPRESSION" = 'bzip2' ]
	then
		print_error
		case "${LANG%_*}" in
			('fr')
				# shellcheck disable=SC1112
				string='Le mode de compression bzip2 n’est pas compatible avec la génération de paquets deb.'
			;;
			('en'|*)
				string='bzip2 compression mode is not compatible with deb packages generation.'
			;;
		esac
		printf '%s\n' "$string"
		exit 1
	fi

	# Do not allow none compression when building Gentoo packages

	if
		[ "$OPTION_PACKAGE" = 'gentoo' ] && \
		[ "$OPTION_COMPRESSION" = 'none' ]
	then
		print_error
		case "${LANG%_*}" in
			('fr')
				# shellcheck disable=SC1112
				string='Le mode de compression none n’est pas compatible avec la génération de paquets gentoo.'
			;;
			('en'|*)
				string='none compression mode is not compatible with gentoo packages generation.'
			;;
		esac
		printf '%s\n' "$string"
		exit 1
	fi

	# Restrict packages list to target architecture

	select_package_architecture

	# Check script dependencies

	check_deps

	# Set package paths

	case $OPTION_PACKAGE in
		('arch'|'gentoo')
			PATH_BIN="$OPTION_PREFIX/bin"
			PATH_DESK='/usr/local/share/applications'
			PATH_DOC="$OPTION_PREFIX/share/doc/$GAME_ID"
			PATH_GAME="$OPTION_PREFIX/share/$GAME_ID"
			PATH_ICON_BASE='/usr/local/share/icons/hicolor'
		;;
		('deb')
			PATH_BIN="$OPTION_PREFIX/games"
			PATH_DESK='/usr/local/share/applications'
			PATH_DOC="$OPTION_PREFIX/share/doc/$GAME_ID"
			PATH_GAME="$OPTION_PREFIX/share/games/$GAME_ID"
			PATH_ICON_BASE='/usr/local/share/icons/hicolor'
		;;
		(*)
			liberror 'OPTION_PACKAGE' "$0"
		;;
	esac

	# Set main archive

	archives_get_list
	archive_set_main $ARCHIVES_LIST

	# Set working directories

	set_temp_directories $PACKAGES_LIST

fi
