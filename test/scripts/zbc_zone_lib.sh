#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# zbc_zone_lib.sh — Zone-related helper functions for the ZBC test suite.
# Sourced by zbc_test_lib.sh; do not execute directly.

function zbc_test_get_zone_info()
{
	if [ $# -eq 1 ]; then
		local ro="${1}"
	else
		local ro="0"
	fi

	local _cmd="${bin_path}/zbc_test_report_zones -ro ${ro} ${device}"
	echo "" >> ${log_file} 2>&1
	echo "## `date -Ins` Executing: ${_cmd} > ${zone_info_file} 2>&1" >> ${log_file} 2>&1
	echo "" >> ${log_file} 2>&1

	${VALGRIND} ${_cmd} > ${zone_info_file} 2>> ${log_file}
	last_ro="$ro"

	return 0
}

### [ZONE_INFO],<id>,<type>,<cond>,<slba>,<size>,<ptr>

# Issue all zone records to a pipeline
function zbc_zones()
{
	cat ${zone_info_file} | grep -E "\[ZONE_INFO\]"
}

# Remove zones with NON-matching types from the pipeline
# $1 examples:	0x1		match conventional zones, filter others out
#		0x2|0x3		match sequential zones, filter others out
function zbc_zone_filter_in_type()
{
	grep -E "\[ZONE_INFO\],.*,($1),.*,.*,.*,.*"
}

# Remove zones with MATCHING types from the pipeline
# $1 examples:	0x1		filter conventional zones out of the pipeline
#		0x2|0x3		filter sequential zones out of the pipeline
function zbc_zone_filter_out_type()
{
	grep -v -E "\[ZONE_INFO\],.*,($1),.*,.*,.*,.*"
}

# Remove zones with NON-matching conditions from the pipeline
# $1 examples:	0x1		match empty zones, filter others out
#		0x2|0x3		match open zones, filter others out
function zbc_zone_filter_in_cond()
{
	local zone_cond="$1"
	grep -E "\[ZONE_INFO\],.*,.*,($1),.*,.*,.*"
}

# Remove zones with MATCHING conditions from the pipeline
# $1 examples:	0x1		filter empty zones out of pipeline
#		0x2|0x3		filter open zones out of pipeline
function zbc_zone_filter_out_cond()
{
	local zone_cond="$1"
	grep -v -E "\[ZONE_INFO\],.*,.*,($1),.*,.*,.*"
}

# Preparation functions

function UNUSED_zbc_test_count_zones()
{
	nr_zones=`zbc_zones | wc -l`
}

function UNUSED_zbc_test_count_conv_zones()
{
	nr_conv_zones=`zbc_zones | zbc_zone_filter_in_type "${ZT_CONV}" | wc -l`
}

function UNUSED_zbc_test_count_seq_zones()
{
	nr_seq_zones=`zbc_zones | zbc_zone_filter_in_type "${ZT_SEQ}" | wc -l`
}

function UNUSED_zbc_test_count_inactive_zones()
{
	nr_inactive_zones=`zbc_zones | zbc_zone_filter_in_cond "${ZC_INACTIVE}" | wc -l`
}

# Set expected errors if zone is not available for write
function zbc_write_check_available()
{
	local _type="$1"
	local _cond="$2"

	if [ "${_cond}" = "${ZC_OFFLINE}" ]; then
		alt_expected_sk="Data-protect"
		alt_expected_asc="Zone-is-offline"
	elif [ "${_cond}" = "${ZC_RDONLY}" ]; then
		alt_expected_sk="Data-protect"
		alt_expected_asc="Zone-is-read-only"
	elif [ "${_cond}" = "${ZC_INACTIVE}" ]; then
		alt_expected_sk="Data-protect"
		alt_expected_asc="Zone-is-inactive"
	elif [ "${_type}" = "${ZT_GAP}" ]; then
		alt_expected_sk="Illegal-request"
		alt_expected_asc="Attempt-to-access-GAP-zone"
	else
		return 0
	fi

	return 1
}

# Set expected errors if zone is not available for read
function zbc_read_check_available()
{
	local _type="$1"
	local _cond="$2"

	if [ "${_cond}" = "${ZC_OFFLINE}" ]; then
		alt_expected_sk="Data-protect"
		alt_expected_asc="Zone-is-offline"
	elif [ "${_type}" = "${ZT_CONV}" ]; then
		return 0
	elif [ "${unrestricted_read}" -ne 0 ]; then
		return 0
	elif [ "${_cond}" = "${ZC_INACTIVE}" ]; then
		alt_expected_sk="Data-protect"
		alt_expected_asc="Zone-is-inactive"
	elif [ "${_type}" = "${ZT_GAP}" ]; then
		alt_expected_sk="Illegal-request"
		alt_expected_asc="Attempt-to-access-GAP-zone"
	else
		return 0
	fi

	return 1
}

# $1 is type of zones to open; $2 is number of zones to open
# It is expected that the requested number can be opened
function zbc_test_open_nr_zones()
{
	local _zone_cond="${ZC_EMPTY}"
	local _zone_type="${1}"
	local -i _open_num=${2}
	local -i _count=0
	if [ ${_open_num} -eq 0 ]; then
		return 0
	fi

	for _line in `zbc_zones | zbc_zone_filter_in_type "${_zone_type}" \
				| zbc_zone_filter_in_cond "${_zone_cond}"` ; do
		local _IFS="${IFS}"
		IFS=$',\n'
		set -- ${_line}

		local zone_type=${3}
		local zone_cond=${4}
		local start_lba=${5}
		local zone_size=${6}
		local write_ptr=${7}

		IFS="$_IFS"

		zbc_test_run ${bin_path}/zbc_test_open_zone -v ${device} ${start_lba}
		if [ $? -ne 0 ]; then
			echo "WARNING: Unexpected failure to open zone ${start_lba} after ${_count}/${_open_num} opens"
			zbc_test_dump_zone_info
			return 1
		fi

		_count=${_count}+1

		if [ ${_count} -ge ${_open_num} ]; then
			return 0
		fi
	done

	echo "FAIL: Opened ${_count} of ${_open_num} of type ${ZT_SWR} (max_open=${max_open})"
	zbc_test_dump_zone_info
	return 1
}

function zbc_test_iopen_nr_zones()
{
	local _zone_cond="${ZC_EMPTY}"
	local _zone_type="${1}"
	local -i _open_num=${2}
	local -i _count=0
	if [ ${_open_num} -eq 0 ]; then
		return 0
	fi

	for _line in `zbc_zones | zbc_zone_filter_in_type "${_zone_type}" \
				| zbc_zone_filter_in_cond "${_zone_cond}"` ; do
		local _IFS="${IFS}"
		IFS=$',\n'
		set -- ${_line}

		local zone_type=${3}
		local zone_cond=${4}
		local start_lba=${5}
		local zone_size=${6}
		local write_ptr=${7}

		IFS="$_IFS"

		zbc_test_run ${bin_path}/zbc_test_write_zone -v ${device} ${start_lba} ${lblk_per_pblk}
		if [ $? -ne 0 ]; then
			echo "WARNING: Unexpected failure to write zone ${start_lba} after ${_count}/${_open_num} zones written"
			zbc_test_dump_zone_info
			return 1
		fi

		_count=${_count}+1

		if [ ${_count} -ge ${_open_num} ]; then
			return 0
		fi
	done

	echo "FAIL: Wrote ${_count} of ${_open_num} of type ${ZT_SWR} (max_open=${max_open})"
	zbc_test_dump_zone_info
	return 1
}

function zbc_test_close_nr_zones()
{
	local _zone_cond="${ZC_EMPTY}"
	local _zone_type="${1}"
	local -i _close_num=${2}
	local -i _count=0
	if [ ${_close_num} -eq 0 ]; then
		return 0
	fi

	for _line in `zbc_zones | zbc_zone_filter_in_type "${_zone_type}" \
				| zbc_zone_filter_in_cond "${_zone_cond}"` ; do
		local _IFS="${IFS}"
		IFS=$',\n'
		set -- ${_line}

		local zone_type=${3}
		local zone_cond=${4}
		local start_lba=${5}
		local zone_size=${6}
		local write_ptr=${7}

		IFS="$_IFS"

		zbc_test_run ${bin_path}/zbc_test_write_zone -v ${device} ${start_lba} ${lblk_per_pblk}
		if [ $? -ne 0 ]; then
			echo "WARNING: Unexpected failure to write zone ${start_lba} after writing ${_count}/${_close_num} zones"
			zbc_test_dump_zone_info
			return 1
		fi

		zbc_test_run ${bin_path}/zbc_test_close_zone -v ${device} ${start_lba}
		if [ $? -ne 0 ]; then
			echo "WARNING: Unexpected failure to close zone ${start_lba}"
			zbc_test_dump_zone_info
			return 1
		fi

		_count=${_count}+1

		if [ ${_count} -ge ${_close_num} ]; then
			return 0
		fi
	done

	echo "FAIL: Wrote/Closed ${_count} of ${_open_num} of type ${ZT_SWR} (max_open=${max_open})"
	zbc_test_dump_zone_info
	return 1
}

# This function expects always to find the requested slba
function zbc_test_get_target_zone_from_slba_or_fail()
{
	local start_lba=${1}
	if [ -z ${start_lba} ]; then
		zbc_test_fail_exit \
			"WARNING: zbc_test_get_target_zone_from_slba_or_fail called with empty start_lba argument"
	fi

	zbc_test_get_zone_info

	# [ZONE_INFO],<id>,<type>,<cond>,<slba>,<size>,<ptr>
	for _line in `cat ${zone_info_file} | grep "\[ZONE_INFO\],.*,.*,.*,${start_lba},.*,.*"`; do

		local _IFS="${IFS}"
		IFS=$',\n'
		set -- ${_line}

		# Warning: ${2} is *not* the zone number, merely the index in the current report
		target_type=${3}
		target_cond=${4}
		target_slba=${5}
		target_size=${6}
		target_ptr=${7}

		IFS="$_IFS"

		return 0

	done

	zbc_test_fail_exit "Cannot find slba=${slba} in ${zone_info_file}"
}

# This function expects always to find the requested slba
function zbc_test_get_target_zone_from_slba_or_fail_cached()
{
	local start_lba=${1}
	if [ -z ${start_lba} ]; then
		zbc_test_fail_exit \
			"WARNING: zbc_test_get_target_zone_from_slba_or_fail_cached called with empty start_lba argument"
	fi

	if [ ! -r "${zone_info_file}" ]; then
		zbc_test_get_zone_info
	elif [ "$last_ro" != "0" ]; then
		zbc_test_get_zone_info
	fi

	# [ZONE_INFO],<id>,<type>,<cond>,<slba>,<size>,<ptr>
	for _line in `cat ${zone_info_file} | grep "\[ZONE_INFO\],.*,.*,.*,${start_lba},.*,.*"`; do

		local _IFS="${IFS}"
		IFS=$',\n'
		set -- ${_line}

		# Warning: ${2} is *not* the zone number, merely the index in the current report
		target_type=${3}
		target_cond=${4}
		target_slba=${5}
		target_size=${6}
		target_ptr=${7}

		IFS="$_IFS"

		return 0

	done

	zbc_test_fail_exit "Cannot find slba=${slba} in ${zone_info_file}"
}

# Compatibility name is called from 81 scripts
function zbc_test_get_target_zone_from_slba()
{
	zbc_test_get_target_zone_from_slba_or_fail "$@"
}

# These _search_ functions look for a zone aleady in the condition

function zbc_test_search_target_zone_from_type_and_cond()
{
	local zone_type="${1}"
	local zone_cond="${2}"

	zbc_test_get_zone_info

	for _line in `zbc_zones | zbc_zone_filter_in_type "${zone_type}" \
				| zbc_zone_filter_in_cond "${zone_cond}"`; do

		local _IFS="${IFS}"
		IFS=$',\n'
		set -- ${_line}

		target_type=${3}
		target_cond=${4}
		target_slba=${5}
		target_size=${6}
		target_ptr=${7}

		IFS="$_IFS"

		return 0
	done

	return 1
}

function zbc_test_search_gap_zone_or_NA()
{
	local _zone_type="${ZT_GAP}"
	local _zone_cond="${ZC_NOT_WP}"

	zbc_test_search_target_zone_from_type_and_cond "${_zone_type}" "${_zone_cond}"
	if [ $? -ne 0 ]; then
		zbc_test_print_not_applicable "No GAP zones"
	fi
}

function zbc_test_search_last_zone_vals_from_zone_type()
{
	local zone_type="${1}"

	zbc_test_get_zone_info

	for _line in `zbc_zones | zbc_zone_filter_in_type "${zone_type}" | tail -n 1`; do

		local _IFS="${IFS}"
		IFS=$',\n'
		set -- ${_line}

		target_type=${3}
		target_cond=${4}
		target_slba=${5}
		target_size=${6}
		target_ptr=${7}

		IFS="$_IFS"

		return 0
	done

	return 1
}

# Select a zone for testing and return info.
#
# If ${test_zone_type} is set, search for that; otherwise search for SWR|SWP.
# $1 is a regular expression denoting the desired zone condition.
# If $1 is omitted, a zone is matched if it is available (not OFFLINE, etc).
#
# Return info is the same as zbc_test_search_vals_*
function zbc_test_search_zone_cond()
{
	local _zone_type="${test_zone_type:-${ZT_SEQ}}"
	local _zone_cond="${1:-${ZC_AVAIL}}"

	zbc_test_search_target_zone_from_type_and_cond "${_zone_type}" "${_zone_cond}"
	if [ $? -ne 0 ]; then
		return 1
	fi

	return 0
}

function zbc_test_search_zone_cond_or_NA()
{
	local _zone_type="${test_zone_type:-${ZT_SEQ}}"
	local _zone_cond="${1:-${ZC_AVAIL}}"

	zbc_test_search_target_zone_from_type_and_cond "${_zone_type}" "${_zone_cond}"
	if [ $? -ne 0 ]; then
		zbc_test_print_not_applicable \
		    "No zone is of type ${_zone_type} and condition ${_zone_cond}"
	fi
}

# Select a Write-Pointer zone for testing and return info.
# Argument and return information are the same as zbc_test_search_zone_cond_or_NA.
function zbc_test_search_wp_zone_cond_or_NA()
{
	local _zone_type="${test_zone_type:-${ZT_SEQ}}"

	if [ "${_zone_type}" = "${ZT_CONV}" ]; then
		zbc_test_print_not_applicable \
		    "WARNING: Zone type ${_zone_type} is not a write-pointer zone type"
	fi

	zbc_test_search_zone_cond_or_NA "$@"
}

# Select a non-Sequential zone for testing and return info.
# Argument and return information are the same as zbc_test_search_zone_cond_or_NA.
function zbc_test_search_non_seq_zone_cond_or_NA()
{
	local _zone_type="${ZT_NON_SEQ}"
	local _zone_cond="${1:-${ZC_AVAIL}}"

	zbc_test_search_target_zone_from_type_and_cond "${_zone_type}" "${_zone_cond}"
	if [ $? -ne 0 ]; then
		zbc_test_print_not_applicable \
		    "No zone is of type ${_zone_type} and condition ${_zone_cond}"
	fi
}

# Select a Sequential zone for testing and return info.
# Argument and return information are the same as zbc_test_search_zone_cond_or_NA.
function zbc_test_search_seq_zone_cond()
{
	local _zone_type="${ZT_SEQ}"
	local _zone_cond="${1:-${ZC_AVAIL}}"

	zbc_test_search_target_zone_from_type_and_cond "${_zone_type}" "${_zone_cond}"
	return $?
}

function zbc_test_search_seq_zone_cond_or_NA()
{
	local _zone_type="${ZT_SEQ}"
	local _zone_cond="${1:-${ZC_AVAIL}}"

	zbc_test_search_seq_zone_cond "$@"
	if [ $? -ne 0 ]; then
		zbc_test_print_not_applicable \
		    "No zone is of type ${_zone_type} and condition ${_zone_cond}"
	fi
}

# zbc_test_get_zones zone_type num_zones
# Returns the first zone of a contiguous sequence of length nz with the specified type.
# Returns non-zero if the request could not be met.
function zbc_test_get_zones()
{
	local zone_type="${1}"
	local -i nz=${2}
	local cand_type cand_cond cand_slba cand_size cand_ptr
	local cur_type cur_cond cur_slba cur_size cur_ptr
	local -i candidate=0
	local -i ret=1
	local -i i=0

	zbc_test_get_zone_info

	for _line in `zbc_zones | zbc_zone_filter_in_type "${zone_type}" \
				| zbc_zone_filter_in_cond "${ZC_AVAIL}"`; do

		local _IFS="${IFS}"
		IFS=$',\n'
		set -- ${_line}

		cur_type=${3}
		cur_cond=${4}
		cur_slba=${5}
		cur_size=${6}
		cur_ptr=${7}

		IFS="$_IFS"

		if [[ $candidate == 0 ]]; then
			# Candidate first zone found
			cand_type=${cur_type}
			cand_cond=${cur_cond}
			cand_slba=${cur_slba}
			cand_size=${cur_size}
			cand_ptr=${cur_ptr}
			candidate=1
			i=1
		else
			if [[ ${cur_type} != ${cand_type} ]]; then
				candidate=0
				i=0
				continue
			fi

			i=$(($i + 1))
		fi

		if [ $i -ge $nz ]; then
			target_type=${cand_type}
			target_cond=${cand_cond}
			target_slba=${cand_slba}
			target_size=${cand_size}
			target_ptr=${cand_ptr}
			ret=0
			break
		fi
	done

	return $ret
}

function zbc_test_search_zone_pair()
{
	local zone_type="${1}"
	local zone1_cond=${2}
	local zone2_cond=${3}
	local cand_type cand_cond cand_slba cand_size cand_ptr
	local cur_type cur_cond cur_slba cur_size cur_ptr
	local -i candidate=0
	local -i ret=1

	zbc_test_get_zone_info

	for _line in `zbc_zones | zbc_zone_filter_in_type "${zone_type}"`; do

		local _IFS="${IFS}"
		IFS=$',\n'
		set -- ${_line}

		cur_type=${3}
		cur_cond=${4}
		cur_slba=${5}
		cur_size=${6}
		cur_ptr=${7}

		IFS="$_IFS"

		if [[ $candidate == 0 ]]; then
			# Make sure the first zone has the needed condition
			if [[ ${cur_cond} != @(${zone1_cond}) ]]; then
				continue
			fi

			# Candidate first zone found
			cand_type=${cur_type}
			cand_cond=${cur_cond}
			cand_slba=${cur_slba}
			cand_size=${cur_size}
			cand_ptr=${cur_ptr}
			candidate=1
			continue
		else
			# Make sure the second zone has the needed type/condition
			if [[ ${cur_type} != ${cand_type} ]]; then
				candidate=0
				continue
			fi
			if [[ ${cur_cond} != @(${zone2_cond}) ]]; then
				if [[ ${cur_cond} != @(${zone1_cond}) ]]; then
					candidate=0
					continue
				fi
				# No match with the second condition, but still a candidate
				cand_slba=${cur_slba}
				cand_size=${cur_size}
				cand_ptr=${cur_ptr}
				continue
			fi

			# Full match!
			target_type=${cand_type}
			target_cond=${cand_cond}
			target_slba=${cand_slba}
			target_size=${cand_size}
			target_ptr=${cand_ptr}
			ret=0
			break
		fi
	done

	return $ret
}

function zbc_test_search_zone_pair_or_NA()
{
	zbc_test_search_zone_pair "$@"
	if [ $? -ne 0 ]; then
		local zone_type="${1}"
		local zone1_cond=${2}
		local zone2_cond=${3}
		zbc_test_print_not_applicable \
		    "No available zone pair type=${zone_type} cond=${zone1_cond},${zone2_cond}"
	fi
}

# These _get_ functions set the zone(s) to the specified condition(s)

# zbc_test_get_zones_cond type cond1 [cond2...]
# Sets zbc_test_search_vals from the first zone of a
#	contiguous sequence with the specified type and conditions
# Return value is non-zero if the request cannot be met.
function zbc_test_get_zones_cond()
{
	local zone_type="${1}"
	shift
	local -i nzone=$#

	# Get ${nzone} zones in a row, all of the same ${target_type} matching ${zone_type}
	zbc_test_get_zones ${zone_type} ${nzone}
	if [ $? -ne 0 ]; then
		return 1
	fi
	local start_lba=${target_slba}

	# Set the zones to the requested conditions
	local -i zn
	for (( zn=0 ; zn<${nzone} ; zn++ )) ; do
		local cond="$1"
		case "${cond}" in
		"EMPTY")
			# RESET to EMPTY
			zbc_test_run ${bin_path}/zbc_test_reset_zone -v ${device} ${target_slba}
			;;
		"IOPENZ")
			# IMPLICIT OPEN by writing zero LBA to the zone
			zbc_test_run ${bin_path}/zbc_test_reset_zone -v ${device} ${target_slba}
			zbc_test_run ${bin_path}/zbc_test_write_zone -v ${device} ${target_slba} 0
			;;
		"IOPENL")
			# IMPLICIT OPEN by writing the first ${lblk_per_pblk} LBA of the zone
			zbc_test_run ${bin_path}/zbc_test_reset_zone -v ${device} ${target_slba}
			zbc_test_run ${bin_path}/zbc_test_write_zone -v ${device} ${target_slba} ${lblk_per_pblk}
			;;
		"IOPENH")
			# IMPLICIT OPEN by writing all but the last ${lblk_per_pblk} LBA of the zone
			zbc_test_run ${bin_path}/zbc_test_reset_zone -v ${device} ${target_slba}
			zbc_test_run ${bin_path}/zbc_test_write_zone -v ${device} ${target_slba} $(( ${target_size} - ${lblk_per_pblk} ))
			;;
		"EOPEN")
			# EXPLICIT OPEN of an empty zone
			zbc_test_run ${bin_path}/zbc_test_reset_zone -v ${device} ${target_slba}
			zbc_test_run ${bin_path}/zbc_test_open_zone -v ${device} ${target_slba}
			;;
		"CLOSEDL")
			# CLOSE a zone with the first block written
			zbc_test_run ${bin_path}/zbc_test_reset_zone -v ${device} ${target_slba}
			zbc_test_run ${bin_path}/zbc_test_write_zone -v ${device} ${target_slba} ${lblk_per_pblk}
			zbc_test_run ${bin_path}/zbc_test_close_zone -v ${device} ${target_slba}
			;;
		"CLOSEDH")
			# CLOSE a zone with all but the last block written
			zbc_test_run ${bin_path}/zbc_test_reset_zone -v ${device} ${target_slba}
			zbc_test_run ${bin_path}/zbc_test_write_zone -v ${device} ${target_slba} $(( ${target_size} - ${lblk_per_pblk} ))
			zbc_test_run ${bin_path}/zbc_test_close_zone -v ${device} ${target_slba}
			;;
		"FULL")
			# FULL by writing the entire zone
			zbc_test_run ${bin_path}/zbc_test_reset_zone -v ${device} ${target_slba}
			zbc_test_run ${bin_path}/zbc_test_write_zone -v ${device} ${target_slba} ${target_size}
			;;
		"NOT_WP")
			if [[ ${ZT_CONV} != @(${zone_type}) ]]; then
				zbc_test_fail_exit "Caller requested condition ${cond} with zone type ${zone_type}"
			fi
			;;
		* )
			zbc_test_fail_exit "Caller requested unsupported condition ${cond}"
			;;
		esac

		shift
		zbc_test_get_target_zone_from_slba_or_fail $(( ${target_slba} + ${target_size} ))
	done

	# Update and return the info for the first zone of the tuple
	zbc_test_get_target_zone_from_slba_or_fail ${start_lba}
	return 0
}

function zbc_test_get_zones_cond_or_NA()
{
	local _zone_type="${test_zone_type:-${ZT_SEQ}}"

	zbc_test_get_zones_cond "${_zone_type}" "$@"
	if [ $? -ne 0 ]; then
	    if [ $# -gt 1 ]; then
		zbc_test_print_not_applicable \
		    "No available zone sequence of type ${_zone_type} and length $#"
	    else
		zbc_test_print_not_applicable \
		    "No available zone of type ${_zone_type}"
	    fi
	fi
}

# zbc_test_get_wp_zones_cond_or_NA cond1 [cond2...]
# Sets zbc_test_search_vals from the first zone of a
#	contiguous sequence with the specified type and conditions
# If ${test_zone_type} is set, search for that; otherwise search for SWR|SWP.
# If ${test_zone_type} is set, it should refer (only) to one or more WP zones.
# Exits with "N/A" message if the request cannot be met
function zbc_test_get_wp_zones_cond_or_NA()
{
	local _zone_type="${test_zone_type:-${ZT_SEQ}}"

	if [ "${_zone_type}" = "${ZT_CONV}" ]; then
		zbc_test_print_not_applicable \
			"Zone type ${_zone_type} is not a write-pointer zone type"
	fi

	zbc_test_get_zones_cond_or_NA "$@"
}
