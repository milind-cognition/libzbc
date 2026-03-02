#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# zbc_zone_lib.sh — Zone-related helper functions for the ZBC test suite.
# Sourced by zbc_test_lib.sh; do not execute directly.

/**
 * @file zbc_zone_lib.sh
 * @brief Zone-related helper functions for the ZBC/ZAC test suite.
 *
 * This shell library provides functions for querying, filtering, and
 * manipulating zone information on Zoned Block Devices.  It is sourced
 * by zbc_test_lib.sh and relies on shared variables such as @c bin_path,
 * @c device, @c log_file, @c zone_info_file, and the zone-type/condition
 * constants (e.g. @c ZT_CONV, @c ZT_SEQ, @c ZC_EMPTY, @c ZC_AVAIL).
 *
 * @note Do not execute this file directly; it must be sourced.
 */

/**
 * @brief Retrieve zone information from the device and store it in the
 *        zone info file.
 *
 * Runs @c zbc_test_report_zones with the given reporting-options value and
 * writes the output to @c zone_info_file.  The command and timestamp are
 * logged to @c log_file.
 *
 * @param $1 (optional) Reporting-options value passed to
 *        @c zbc_test_report_zones.  Defaults to "0" if omitted.
 *
 * @return 0 always.
 *
 * @note Sets the global variable @c last_ro to the reporting-options value
 *       that was used.
 */
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

/**
 * @brief Emit all zone records from the zone info file to stdout.
 *
 * Reads @c zone_info_file and filters lines matching the
 * @c [ZONE_INFO] tag so they can be piped into further filter functions.
 *
 * @return 0 on success (grep exit status).
 */
# Issue all zone records to a pipeline
function zbc_zones()
{
	cat ${zone_info_file} | grep -E "\[ZONE_INFO\]"
}

/**
 * @brief Pipeline filter: keep only zones whose type matches the pattern.
 *
 * Reads @c [ZONE_INFO] records from stdin and passes through only those
 * whose type field matches the extended-regex pattern given in @p $1.
 *
 * @param $1 Extended-regex pattern for zone types to keep
 *           (e.g. "0x1" for conventional, "0x2|0x3" for sequential).
 *
 * @return 0 if at least one line matched; 1 otherwise (grep semantics).
 */
# Remove zones with NON-matching types from the pipeline
# $1 examples:	0x1		match conventional zones, filter others out
#		0x2|0x3		match sequential zones, filter others out
function zbc_zone_filter_in_type()
{
	grep -E "\[ZONE_INFO\],.*,($1),.*,.*,.*,.*"
}

/**
 * @brief Pipeline filter: remove zones whose type matches the pattern.
 *
 * Reads @c [ZONE_INFO] records from stdin and removes those whose type
 * field matches the extended-regex pattern given in @p $1.
 *
 * @param $1 Extended-regex pattern for zone types to remove
 *           (e.g. "0x1" to drop conventional, "0x2|0x3" to drop sequential).
 *
 * @return 0 if at least one line was passed through; 1 otherwise.
 */
# Remove zones with MATCHING types from the pipeline
# $1 examples:	0x1		filter conventional zones out of the pipeline
#		0x2|0x3		filter sequential zones out of the pipeline
function zbc_zone_filter_out_type()
{
	grep -v -E "\[ZONE_INFO\],.*,($1),.*,.*,.*,.*"
}

/**
 * @brief Pipeline filter: keep only zones whose condition matches the pattern.
 *
 * Reads @c [ZONE_INFO] records from stdin and passes through only those
 * whose condition field matches the extended-regex pattern given in @p $1.
 *
 * @param $1 Extended-regex pattern for zone conditions to keep
 *           (e.g. "0x1" for empty, "0x2|0x3" for open).
 *
 * @return 0 if at least one line matched; 1 otherwise.
 */
# Remove zones with NON-matching conditions from the pipeline
# $1 examples:	0x1		match empty zones, filter others out
#		0x2|0x3		match open zones, filter others out
function zbc_zone_filter_in_cond()
{
	local zone_cond="$1"
	grep -E "\[ZONE_INFO\],.*,.*,($1),.*,.*,.*"
}

/**
 * @brief Pipeline filter: remove zones whose condition matches the pattern.
 *
 * Reads @c [ZONE_INFO] records from stdin and removes those whose
 * condition field matches the extended-regex pattern given in @p $1.
 *
 * @param $1 Extended-regex pattern for zone conditions to remove
 *           (e.g. "0x1" to drop empty, "0x2|0x3" to drop open).
 *
 * @return 0 if at least one line was passed through; 1 otherwise.
 */
# Remove zones with MATCHING conditions from the pipeline
# $1 examples:	0x1		filter empty zones out of pipeline
#		0x2|0x3		filter open zones out of pipeline
function zbc_zone_filter_out_cond()
{
	local zone_cond="$1"
	grep -v -E "\[ZONE_INFO\],.*,.*,($1),.*,.*,.*"
}

# Preparation functions

/**
 * @brief Count the total number of zones and store the result in @c nr_zones.
 *
 * @deprecated This function is currently unused (prefixed UNUSED_).
 *
 * @return 0 always.
 */
function UNUSED_zbc_test_count_zones()
{
	nr_zones=`zbc_zones | wc -l`
}

/**
 * @brief Count the number of conventional zones and store the result
 *        in @c nr_conv_zones.
 *
 * @deprecated This function is currently unused (prefixed UNUSED_).
 *
 * @return 0 always.
 */
function UNUSED_zbc_test_count_conv_zones()
{
	nr_conv_zones=`zbc_zones | zbc_zone_filter_in_type "${ZT_CONV}" | wc -l`
}

/**
 * @brief Count the number of sequential zones and store the result
 *        in @c nr_seq_zones.
 *
 * @deprecated This function is currently unused (prefixed UNUSED_).
 *
 * @return 0 always.
 */
function UNUSED_zbc_test_count_seq_zones()
{
	nr_seq_zones=`zbc_zones | zbc_zone_filter_in_type "${ZT_SEQ}" | wc -l`
}

/**
 * @brief Count the number of inactive zones and store the result
 *        in @c nr_inactive_zones.
 *
 * @deprecated This function is currently unused (prefixed UNUSED_).
 *
 * @return 0 always.
 */
function UNUSED_zbc_test_count_inactive_zones()
{
	nr_inactive_zones=`zbc_zones | zbc_zone_filter_in_cond "${ZC_INACTIVE}" | wc -l`
}

/**
 * @brief Check whether a zone is available for writing and set expected
 *        error codes if it is not.
 *
 * Examines the zone type and condition and, when the zone cannot be
 * written, populates @c alt_expected_sk and @c alt_expected_asc with
 * the anticipated SCSI sense-key / ASC strings.
 *
 * @param $1 Zone type  (e.g. @c ZT_GAP, @c ZT_CONV).
 * @param $2 Zone condition (e.g. @c ZC_OFFLINE, @c ZC_RDONLY, @c ZC_INACTIVE).
 *
 * @return 0 if the zone is available for writing.
 * @return 1 if the zone is not available (error globals are set).
 */
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

/**
 * @brief Check whether a zone is available for reading and set expected
 *        error codes if it is not.
 *
 * Similar to @ref zbc_write_check_available but for read operations.
 * Conventional zones are always readable.  When @c unrestricted_read is
 * non-zero, most zone conditions are considered readable as well.
 *
 * @param $1 Zone type  (e.g. @c ZT_CONV, @c ZT_GAP).
 * @param $2 Zone condition (e.g. @c ZC_OFFLINE, @c ZC_INACTIVE).
 *
 * @return 0 if the zone is available for reading.
 * @return 1 if the zone is not available (error globals are set).
 */
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

/**
 * @brief Explicitly open a given number of empty zones of the specified type.
 *
 * Iterates through empty zones matching @p $1 and explicitly opens them
 * via @c zbc_test_open_zone until @p $2 zones have been opened.
 *
 * @param $1 Zone type pattern to match (e.g. @c ZT_SWR).
 * @param $2 Number of zones to open.
 *
 * @return 0 if the requested number of zones were successfully opened.
 * @return 1 if an open operation failed or not enough zones were found.
 */
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

/**
 * @brief Implicitly open a given number of empty zones by writing to them.
 *
 * Iterates through empty zones matching @p $1 and implicitly opens them
 * by writing @c lblk_per_pblk logical blocks via @c zbc_test_write_zone
 * until @p $2 zones have been written.
 *
 * @param $1 Zone type pattern to match (e.g. @c ZT_SWR).
 * @param $2 Number of zones to implicitly open.
 *
 * @return 0 if the requested number of zones were successfully written.
 * @return 1 if a write operation failed or not enough zones were found.
 */
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

/**
 * @brief Write to and then close a given number of empty zones.
 *
 * Iterates through empty zones matching @p $1, writes @c lblk_per_pblk
 * logical blocks to each, and then explicitly closes them until @p $2
 * zones have been processed.
 *
 * @param $1 Zone type pattern to match (e.g. @c ZT_SWR).
 * @param $2 Number of zones to write-and-close.
 *
 * @return 0 if the requested number of zones were successfully closed.
 * @return 1 if a write or close operation failed or not enough zones
 *         were found.
 */
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

/**
 * @brief Look up a zone by its start LBA, refreshing zone info first.
 *
 * Calls @ref zbc_test_get_zone_info to refresh the zone report, then
 * searches for the zone whose start LBA matches @p $1.  On success the
 * global target variables (@c target_type, @c target_cond, @c target_slba,
 * @c target_size, @c target_ptr) are populated.
 *
 * Calls @c zbc_test_fail_exit if @p $1 is empty or if the LBA is not found.
 *
 * @param $1 Start LBA of the zone to look up.
 *
 * @return 0 if the zone was found (target globals are set).
 * @return Does not return on failure (exits via @c zbc_test_fail_exit).
 */
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

/**
 * @brief Look up a zone by its start LBA, using cached zone info when possible.
 *
 * Like @ref zbc_test_get_target_zone_from_slba_or_fail but avoids
 * re-running @c zbc_test_report_zones when @c zone_info_file already
 * exists and the last report used reporting-options "0".
 *
 * @param $1 Start LBA of the zone to look up.
 *
 * @return 0 if the zone was found (target globals are set).
 * @return Does not return on failure (exits via @c zbc_test_fail_exit).
 */
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

/**
 * @brief Compatibility wrapper for
 *        @ref zbc_test_get_target_zone_from_slba_or_fail.
 *
 * This name is referenced by 81 existing test scripts.  It simply
 * delegates to @ref zbc_test_get_target_zone_from_slba_or_fail.
 *
 * @param $@ All arguments are forwarded.
 *
 * @return Same as @ref zbc_test_get_target_zone_from_slba_or_fail.
 */
# Compatibility name is called from 81 scripts
function zbc_test_get_target_zone_from_slba()
{
	zbc_test_get_target_zone_from_slba_or_fail "$@"
}

# These _search_ functions look for a zone aleady in the condition

/**
 * @brief Search for the first zone matching a given type and condition.
 *
 * Refreshes zone info, then iterates through zones filtered by @p $1
 * (type) and @p $2 (condition).  On success the target globals
 * (@c target_type, @c target_cond, @c target_slba, @c target_size,
 * @c target_ptr) are populated with the first matching zone.
 *
 * @param $1 Extended-regex pattern for the desired zone type.
 * @param $2 Extended-regex pattern for the desired zone condition.
 *
 * @return 0 if a matching zone was found.
 * @return 1 if no matching zone exists.
 */
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

/**
 * @brief Search for a GAP zone, or mark the test not-applicable.
 *
 * Looks for a zone of type @c ZT_GAP with condition @c ZC_NOT_WP.
 * If none is found, exits via @c zbc_test_print_not_applicable.
 *
 * @return 0 if a GAP zone was found (target globals are set).
 * @return Does not return if no GAP zone exists (exits N/A).
 */
function zbc_test_search_gap_zone_or_NA()
{
	local _zone_type="${ZT_GAP}"
	local _zone_cond="${ZC_NOT_WP}"

	zbc_test_search_target_zone_from_type_and_cond "${_zone_type}" "${_zone_cond}"
	if [ $? -ne 0 ]; then
		zbc_test_print_not_applicable "No GAP zones"
	fi
}

/**
 * @brief Retrieve the last zone of a given type.
 *
 * Refreshes zone info, filters by @p $1, and returns the values of the
 * last zone in the list.  On success the target globals are populated.
 *
 * @param $1 Extended-regex pattern for the desired zone type.
 *
 * @return 0 if at least one zone of the given type was found.
 * @return 1 if no zone of that type exists.
 */
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

/**
 * @brief Select a zone for testing by condition, using the current
 *        test zone type.
 *
 * If the global @c test_zone_type is set it is used as the type filter;
 * otherwise @c ZT_SEQ (SWR|SWP) is used.  The zone condition defaults
 * to @c ZC_AVAIL when @p $1 is omitted.
 *
 * On success the target globals are populated.
 *
 * @param $1 (optional) Extended-regex pattern for the desired zone
 *           condition.  Defaults to @c ZC_AVAIL.
 *
 * @return 0 if a matching zone was found.
 * @return 1 if no matching zone exists.
 */
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

/**
 * @brief Select a zone for testing by condition, or mark test not-applicable.
 *
 * Behaves like @ref zbc_test_search_zone_cond but exits via
 * @c zbc_test_print_not_applicable instead of returning 1 when no
 * matching zone is found.
 *
 * @param $1 (optional) Extended-regex pattern for the desired zone
 *           condition.  Defaults to @c ZC_AVAIL.
 *
 * @return 0 if a matching zone was found (target globals are set).
 * @return Does not return if no match (exits N/A).
 */
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

/**
 * @brief Select a Write-Pointer zone for testing, or mark test
 *        not-applicable.
 *
 * Verifies that the test zone type is not conventional (@c ZT_CONV),
 * then delegates to @ref zbc_test_search_zone_cond_or_NA.
 *
 * @param $1 (optional) Extended-regex pattern for the desired zone
 *           condition.  Defaults to @c ZC_AVAIL.
 *
 * @return 0 if a matching write-pointer zone was found.
 * @return Does not return if the type is conventional or no match
 *         (exits N/A).
 */
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

/**
 * @brief Select a non-sequential zone for testing, or mark test
 *        not-applicable.
 *
 * Searches for a zone of type @c ZT_NON_SEQ with the given condition
 * (defaulting to @c ZC_AVAIL).  Exits N/A if none is found.
 *
 * @param $1 (optional) Extended-regex pattern for the desired zone
 *           condition.  Defaults to @c ZC_AVAIL.
 *
 * @return 0 if a matching zone was found (target globals are set).
 * @return Does not return if no match (exits N/A).
 */
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

/**
 * @brief Select a sequential zone for testing by condition.
 *
 * Searches for a zone of type @c ZT_SEQ matching the given condition
 * (defaulting to @c ZC_AVAIL).
 *
 * @param $1 (optional) Extended-regex pattern for the desired zone
 *           condition.  Defaults to @c ZC_AVAIL.
 *
 * @return 0 if a matching sequential zone was found (target globals
 *         are set).
 * @return 1 if no matching zone exists.
 */
# Select a Sequential zone for testing and return info.
# Argument and return information are the same as zbc_test_search_zone_cond_or_NA.
function zbc_test_search_seq_zone_cond()
{
	local _zone_type="${ZT_SEQ}"
	local _zone_cond="${1:-${ZC_AVAIL}}"

	zbc_test_search_target_zone_from_type_and_cond "${_zone_type}" "${_zone_cond}"
	return $?
}

/**
 * @brief Select a sequential zone for testing, or mark test
 *        not-applicable.
 *
 * Like @ref zbc_test_search_seq_zone_cond but exits via
 * @c zbc_test_print_not_applicable when no match is found.
 *
 * @param $1 (optional) Extended-regex pattern for the desired zone
 *           condition.  Defaults to @c ZC_AVAIL.
 *
 * @return 0 if a matching sequential zone was found.
 * @return Does not return if no match (exits N/A).
 */
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

/**
 * @brief Find a contiguous sequence of available zones of a given type.
 *
 * Refreshes zone info and scans for @p $2 consecutive zones of type
 * @p $1 that are all in an available condition (@c ZC_AVAIL).  On
 * success the target globals are set to the first zone of the sequence.
 *
 * @param $1 Extended-regex pattern for the desired zone type.
 * @param $2 Number of contiguous zones required.
 *
 * @return 0 if a contiguous sequence of the requested length was found.
 * @return 1 (non-zero) if the request could not be met.
 */
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

/**
 * @brief Search for two adjacent zones with specified conditions.
 *
 * Scans zones of the given type looking for a pair of consecutive zones
 * where the first has condition @p $2 and the second has condition @p $3.
 * On success the target globals describe the first zone of the pair.
 *
 * @param $1 Extended-regex pattern for the desired zone type.
 * @param $2 Extended-regex pattern for the condition of the first zone.
 * @param $3 Extended-regex pattern for the condition of the second zone.
 *
 * @return 0 if a matching zone pair was found (target globals are set
 *         to the first zone).
 * @return 1 (non-zero) if no matching pair exists.
 */
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

/**
 * @brief Search for a zone pair, or mark the test not-applicable.
 *
 * Delegates to @ref zbc_test_search_zone_pair and exits N/A when no
 * matching pair is found.
 *
 * @param $1 Extended-regex pattern for the desired zone type.
 * @param $2 Extended-regex pattern for the first zone's condition.
 * @param $3 Extended-regex pattern for the second zone's condition.
 *
 * @return 0 if a matching pair was found.
 * @return Does not return if no match (exits N/A).
 */
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

/**
 * @brief Obtain a contiguous sequence of zones and set each to a
 *        requested condition.
 *
 * Finds @c nzone (= number of condition arguments) contiguous zones of
 * type @p $1, then drives each zone into the condition specified by the
 * corresponding positional parameter.  Supported condition strings:
 *
 * - @c EMPTY   -- reset the zone
 * - @c IOPENZ  -- implicit open by writing zero LBAs
 * - @c IOPENL  -- implicit open by writing @c lblk_per_pblk LBAs
 * - @c IOPENH  -- implicit open by writing all but the last physical block
 * - @c EOPEN   -- explicit open of an empty zone
 * - @c CLOSEDL -- close after writing the first physical block
 * - @c CLOSEDH -- close after writing all but the last physical block
 * - @c FULL    -- write the entire zone
 * - @c NOT_WP  -- valid only for conventional zones
 *
 * On success the target globals describe the first zone of the sequence
 * after all conditions have been applied.
 *
 * @param $1     Extended-regex pattern for the desired zone type.
 * @param $2...  One condition string per zone in the contiguous sequence.
 *
 * @return 0 if the zones were found and all conditions applied.
 * @return 1 if a contiguous sequence of the required length was not found.
 * @return Does not return if a condition is unsupported or a zone
 *         operation fails (exits via @c zbc_test_fail_exit).
 */
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

/**
 * @brief Obtain zones in a requested condition sequence, or mark test
 *        not-applicable.
 *
 * Uses the current @c test_zone_type (defaulting to @c ZT_SEQ) and
 * delegates to @ref zbc_test_get_zones_cond.  Exits N/A if a suitable
 * contiguous zone sequence is not available.
 *
 * @param $1...  One or more condition strings (see
 *               @ref zbc_test_get_zones_cond for the list).
 *
 * @return 0 if the zones were obtained and conditioned.
 * @return Does not return if no suitable sequence exists (exits N/A).
 */
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

/**
 * @brief Obtain Write-Pointer zones in a requested condition sequence,
 *        or mark test not-applicable.
 *
 * Verifies that the test zone type is not conventional, then delegates
 * to @ref zbc_test_get_zones_cond_or_NA.
 *
 * @param $1...  One or more condition strings (see
 *               @ref zbc_test_get_zones_cond for the list).
 *
 * @return 0 if the zones were obtained and conditioned.
 * @return Does not return if the type is conventional or no suitable
 *         sequence exists (exits N/A).
 */
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
