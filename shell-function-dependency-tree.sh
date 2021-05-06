#!/bin/bash

# shell-function-dependency-tree.sh
#
# for a shell script 
# lists function names and dependencies
#  $Revision: 1.2 $
#
#  Copyright (C) 2017-2021 Jordi Pujol <jordipujolp AT gmail DOT com>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3, or (at your option)
#  any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#************************************************************************

#
# Call method: parms are relative to this script directory
#
# parm 1: ShellSource="${1:-"../wwanHotspot-devel/files/wwanHotspot.sh"}"
# parm 2: OutputDir="${2:-"./$(basename "${ShellSource}")"}"
#
# environment:
# DEBUG set to any character will enable shell script xtrace to stderr
#
# Output:
# - List of function names. "&" marks forked processes.
# - One separated file for each function.
# - Calling tree of function names to "functions-tree.txt"


_List() {
	if [ -n "${ListAll}" -o -n "${rc}" ]; then
		echo ${level} "${@}" ${rc} >> "${Tree1}"
		[ ${level} -le ${MaxLevel} ] || \
			MaxLevel=${level}
	fi
}

_Dependencies() {
	local level rc l f s c
	level=${1}; shift
	rc="(end)"
	l="$(eval echo \${${#}} | cut -f 1 -d '(')"
	while read -r f s; do
		if c="$(grep -swF "${f}" "${OutputDir}/${l}" | \
		grep -csvwF "${l}(")"; then
			if echo "${@}" | grep -qswF "${f}"; then
				rc="${f} (recursive)"
				_List "${@}"
				rc=""
				continue
			fi
			rc=""
			_Dependencies "$((level+1))" "${@}" \
				"${f}$(test ${c} -le 1 || echo "(${c})")"
		fi
	done < "${OutputDir}/functions.txt"
	_List "${@}"
}

_commands() {
	local cmd
	for cmd in $(sed -n \
	-re '\|^[^#]*[^(]\(\b([[:alnum:]_]+)\b.*|s||\1|p' \
	< "${ShellSource}" | \
	sort -u); do
		busybox which "${cmd}" > /dev/null 2>&1 || \
			grep -m 1 -qswe "${cmd}" < "${OutputDir}/functions.txt" || \
			grep -m 1 -qswe "${cmd}=" < "${ShellSource}" || \
			echo "${cmd} - Command not found"
	done > "${OutputDir}/functions-commands.txt"
}

_functions() {
	local last f
	sed -nre '/^(function[[:blank:]]+)?([^[:space:]]+)\(\).*/ s//\2/p' \
		< "${ShellSource}" \
		> "${OutputDir}/functions-script.txt"

	last="$(tail -n 1 "${OutputDir}/functions-script.txt")"

	{ sed -r -e '/^(function[[:blank:]]+)?.+\(\)/,$ d' \
		< "${ShellSource}"
	sed -nr -e '/^(function[[:blank:]]+)?'"${last}"'\(\)/,$ p' \
		< "${ShellSource}" | \
		sed -re '1,/^[}]/ d'
	} > "${OutputDir}/$(basename "${ShellSource}")"

	while IFS= read -r f; do
		{ printf '%s\n\n' "${CmdInterpreter}"
		sed -nre '/^(function[[:blank:]]+)?'"${f}"'\(\)/,/^[}]/p' \
			< "${ShellSource}"
		} > "${OutputDir}/${f}"
	done < "${OutputDir}/functions-script.txt"

	while IFS= read -r f; do
		grep -qswEe "\b${f}\b.*[&]$" "${ShellSource}" && \
			echo "${f} &" || \
			echo "${f}"
	done < <(sort < "${OutputDir}/functions-script.txt") \
		> "${OutputDir}/functions.txt"

	while read -r f s; do
		if dep="$(grep -swF "${f}" \
			$(awk -v f="${f}" \
			-v OutputDir="${OutputDir}/" \
			'f == $1 {exit}
			{print OutputDir $1}' \
			< "${OutputDir}/functions-script.txt") )"; then
			printf '%s\n' \
				"*** ${f} ** Dependencies ********************************" \
				"${dep}"
		fi
		echo "*** ${f} ************************************************"
		grep -swF "${f}" \
			$(awk -v OutputDir="${OutputDir}/" \
				'{print OutputDir $1}' \
				< "${OutputDir}/functions-script.txt")
		echo "*********************************************************"
	done < "${OutputDir}/functions.txt" \
		| sed -e 's|^'"${OutputDir}/"'||' \
		> "${OutputDir}/functions-detail.txt"

	#rm "${OutputDir}/functions-script.txt"
}

_main() {
	local ListAll ShellSource OutputDir \
		MaxLevel dir Tree Tree1
	[ -z "${DEBUG:=}" ] || \
		set -o xtrace

	dir="$(dirname "${0}")"
	[ -z "${dir}" ] || \
		cd "${dir}"

	ListAll="y"
	ShellSource="${1:-"../wwanHotspot-devel/files/wwanHotspot.sh"}"
	OutputDir="${2:-"./$(basename "${ShellSource}").d"}"

	mkdir -p "${OutputDir}"
	rm -f "${OutputDir}/"*
	Tree="${OutputDir}/functions-tree.txt"
	Tree1="${OutputDir}/functions-tree-1.txt"

	CmdInterpreter="$(head -n 1 < "${ShellSource}")"

	_functions

	_commands

	: > "${Tree1}"
	MaxLevel=0
	_Dependencies 0 "$(basename "${ShellSource}")"

	sort -k 2,$((MaxLevel+2)) < "${Tree1}" > "${Tree}"
	#rm "${Tree1}"
}

_main "${@}"
