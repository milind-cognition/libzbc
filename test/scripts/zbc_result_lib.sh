#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# zbc_result_lib.sh â Result checking, printing, and condition validation
# functions for the ZBC test suite.
# Sourced by zbc_test_lib.sh; do not execute directly.

: <<'DOXYGEN'
/**
 * @file zbc_result_lib.sh
 * @brief Result checking, printing, and condition validation library for the
 *        ZBC/ZAC test suite.
 *
 * Provides functions for parsing SCSI sense key / ASC-ASCQ results from test
 * log files, printing pass/fail verdicts with terminal formatting, validating
 * zone conditions and write-pointer positions, and dumping zone information
 * after failures.
 *
 * This file is sourced by zbc_test_lib.sh and relies on the following global
 * variables set by the caller: log_file, device, dump_zone_info_file,
 * dump_zone_realm_info_file, zdr_device, expected_sk, expected_asc,
 * expected_cond, expected_err_za, expected_err_cbf, target_cond, target_ptr,
 * target_slba, target_size, green, red, end, SCRIPT_DEBUG,
 * ZBC_TEST_PASS_DETAIL, ZBC_ACCEPT_ANY_FAIL, ZC_EMPTY, ZC_CLOSED, ZC_OPEN.
 *
 * @note Do not execute this file directly.
 */
DOXYGEN

: <<'DOXYGEN'
/**
 * @fn zbc_test_get_sk_ascq
 * @brief Parse sense key and additional sense code from the test log file.
 *
 * Reads the log file in reverse order to extract the most recent SENSE_KEY,
 * ASC_ASCQ, ERR_ZA, and ERR_CBF values. Sets the corresponding global
 * variables.
 *
 * @return void. Sets global variables: sk, asc, err_za, err_cbf.
 */
DOXYGEN
function zbc_test_get_sk_ascq()
{
	sk=""
	asc=""
	err_za=""
	err_cbf=""

	local _IFS="${IFS}"
	IFS=$',\n'

	local sk_line=`tac ${log_file} | grep -m 1 -F "[SENSE_KEY]"`
	set -- ${sk_line}
	sk=${2}

	local asc_line=`tac ${log_file} | grep -m 1 -F "[ASC_ASCQ]"`
	set -- ${asc_line}
	asc=${2}

	local err_za_line=`tac ${log_file} | grep -m 1 -F "[ERR_ZA]"`
	set -- ${err_za_line}
	err_za=${2}

	local err_cbf_line=`tac ${log_file} | grep -m 1 -F "[ERR_CBF]"`
	set -- ${err_cbf_line}
	err_cbf=${2}

	IFS="$_IFS"
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_reset_err
 * @brief Reset error indicators in the test log file.
 *
 * Appends empty SENSE_KEY, ASC_ASCQ, ERR_ZA, and ERR_CBF entries to the log
 * file so that subsequent calls to zbc_test_get_sk_ascq will not pick up
 * stale error values from a previous test command.
 *
 * @return void.
 */
DOXYGEN
function zbc_test_reset_err()
{
	echo "Resetting log error:" >> ${log_file}
	echo "[TEST][ERROR][SENSE_KEY],," >> ${log_file}
	echo "[TEST][ERROR][ASC_ASCQ],," >> ${log_file}
	echo "[TEST][ERROR][ERR_ZA],," >> ${log_file}
	echo "[TEST][ERROR][ERR_CBF],," >> ${log_file}
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_print_res
 * @brief Print a formatted test result string to the terminal and log file.
 *
 * Computes the terminal column width, writes the result tag to the log file,
 * and prints a right-aligned colorized result label on the terminal. For
 * failing results (those starting with 'F'), the log file path is appended.
 *
 * @param $1 ANSI color escape sequence for the result label.
 * @param $2 Result text string (e.g. "Passed", "Failed").
 * @return void.
 */
DOXYGEN
function zbc_test_print_res()
{
	local width=`tput cols`

	width=$(( ${width} - 9 ))
	if [ ${width} -gt 108 ]; then
		width=108
	fi

	# Print name of logfile for failing tests
	if [ ${2:0:1} = "F" ]; then
		local _L=" ${log_file}"
	fi

	echo "" >> ${log_file} 2>&1
	echo "TESTRESULT==$2" >> ${log_file} 2>&1
	echo -e "\r\e[${width}C[$1$2${end}]${_L}"
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_print_passed
 * @brief Print a "Passed" test result.
 *
 * Prints a green "Passed" label via zbc_test_print_res. If additional
 * arguments are provided and ZBC_TEST_PASS_DETAIL is set, the extra text is
 * appended to the result. Dumps zone info when SCRIPT_DEBUG is enabled.
 *
 * @param ... Optional detail text appended when ZBC_TEST_PASS_DETAIL is set.
 * @return void.
 */
DOXYGEN
function zbc_test_print_passed()
{
	if [ $# -gt 0 -a -n "${ZBC_TEST_PASS_DETAIL}" ]; then
		zbc_test_print_res "${green}" "Passed $*"
	else
		zbc_test_print_res "${green}" "Passed"
	fi

	if [[ ${SCRIPT_DEBUG} -ne 0 ]]; then
	    zbc_test_dump_info
	fi
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_print_passed_lib
 * @brief Print a "Passed (libzbc)" test result for library-level checks.
 *
 * Behaves like zbc_test_print_passed but includes the "(libzbc)" qualifier
 * in the result label to distinguish library-level pass verdicts.
 *
 * @param ... Optional detail text appended when ZBC_TEST_PASS_DETAIL is set.
 * @return void.
 */
DOXYGEN
function zbc_test_print_passed_lib()
{
	if [ $# -gt 0 -a -n "${ZBC_TEST_PASS_DETAIL}" ]; then
		zbc_test_print_res "${green}" "Passed (libzbc) $*"
	else
		zbc_test_print_res "${green}" "Passed (libzbc)"
	fi

	if [[ ${SCRIPT_DEBUG} -ne 0 ]]; then
	    zbc_test_dump_info
	fi
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_print_not_applicable
 * @brief Print an "N/A" result and exit the test script with success.
 *
 * Used when a test case does not apply to the current device configuration.
 * Prints the not-applicable label, optionally dumps debug info, then exits
 * with code 0.
 *
 * @param ... Reason text explaining why the test is not applicable.
 * @return Does not return; calls exit 0.
 */
DOXYGEN
function zbc_test_print_not_applicable()
{
	zbc_test_print_res "" "N/A $*"
	if [[ ${SCRIPT_DEBUG} -ne 0 ]]; then
	    zbc_test_dump_info
	fi
	exit 0
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_print_failed
 * @brief Print a "Failed" test result.
 *
 * Prints a red "Failed" label via zbc_test_print_res. If additional
 * arguments are provided, the extra text is appended to the result.
 *
 * @param ... Optional detail text appended to the failure message.
 * @return void.
 */
DOXYGEN
function zbc_test_print_failed()
{
	if [ $# -gt 0 ]; then
		zbc_test_print_res "${red}" "Failed $*"
	else
		zbc_test_print_res "${red}" "Failed"
	fi
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_print_failed_sk
 * @brief Print a "Failed" result with sense key / ASC-ASCQ mismatch details.
 *
 * Calls zbc_test_print_failed, then prints the expected vs. actual sense key
 * and ASC/ASCQ values to both the log file and terminal. When ERR_ZA or
 * ERR_CBF fields are present, those are included in the output.
 *
 * Relies on globals: expected_sk, expected_asc, sk, asc, expected_err_za,
 * expected_err_cbf, err_za, err_cbf, log_file.
 *
 * @param ... Optional detail text forwarded to zbc_test_print_failed.
 * @return void.
 */
DOXYGEN
function zbc_test_print_failed_sk()
{
	zbc_test_print_failed "$@"

	if [ -z "${err_za}" -a -z "${err_cbf}" -a  -z "${expected_err_za}" -a -z "${expected_err_cbf}" ] ; then
		echo "=> Expected ${expected_sk} / ${expected_asc}, Got ${sk} / ${asc}" >> ${log_file} 2>&1

		echo "FAIL        => Expected ${expected_sk} / ${expected_asc}"
		echo "FAIL                Got ${sk} / ${asc}"
	else
		echo "=> Expected ${expected_sk} / ${expected_asc} (ZA-status: ${expected_err_za} / ${expected_err_cbf})"  >> ${log_file} 2>&1
		echo "	      Got ${sk} / ${asc} (ZA-status: ${err_za} / ${err_cbf})" >> ${log_file} 2>&1

		echo "FAIL        => Expected ${expected_sk} / ${expected_asc} (ZA-status: ${expected_err_za} / ${expected_err_cbf})"
		echo "FAIL                Got ${sk} / ${asc} (ZA-status: ${err_za} / ${err_cbf})"
	fi
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_check_err
 * @brief Check sense key, ASC-ASCQ, ERR_ZA, and ERR_CBF against expectations.
 *
 * Compares the global error variables (sk, asc, err_za, err_cbf) against
 * the expected values (expected_sk, expected_asc, expected_err_za,
 * expected_err_cbf). If ZBC_ACCEPT_ANY_FAIL is set and a sense key is
 * present, the expected values are overridden with the actual values.
 * Prints passed or failed accordingly.
 *
 * @param ... Optional detail text forwarded to the result printer.
 * @return void.
 */
DOXYGEN
function zbc_test_check_err()
{
	if [ -n "${ZBC_ACCEPT_ANY_FAIL}" -a -n "${expected_err_za}" ]; then
		if [ -n "${sk}" ]; then
			expected_err_za="${err_za}"
			err_cbf="${expected_err_cbf}"
			expected_sk="${sk}"
			expected_asc="${asc}"
		fi
	fi

	if [ -n "${expected_err_za}" -a -z "${expected_err_cbf}" ] ; then
		# Our caller expects ERR_ZA, but specified no expected CBF -- assume zero
		local expected_err_cbf=0	# expect (CBF == 0)
	fi

	if [ "${sk}" = "${expected_sk}" -a "${asc}" = "${expected_asc}" \
			-a "${err_za}" = "${expected_err_za}" -a "${err_cbf}" = "${expected_err_cbf}" ]; then
		zbc_test_print_passed "$*"
	else
		zbc_test_print_failed_sk "$*"
	fi
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_check_sk_ascq
 * @brief Validate sense key and ASC-ASCQ against expected values.
 *
 * Compares the global sk and asc variables against expected_sk and
 * expected_asc. Also checks alt_expected_sk / alt_expected_asc as an
 * alternate acceptable result. If ZBC_ACCEPT_ANY_FAIL is set and a
 * sense key is present, any failure is accepted as a pass.
 *
 * @param ... Optional detail text forwarded to the result printer.
 * @return void.
 */
DOXYGEN
function zbc_test_check_sk_ascq()
{
	if [ -n "${ZBC_ACCEPT_ANY_FAIL}" -a -n "${expected_sk}" ]; then
		if [ -n "${sk}" ]; then
			zbc_test_print_passed "$*"
			return
		fi
	fi

	if [ "${sk}" = "${expected_sk}" -a "${asc}" = "${expected_asc}" ]; then
		zbc_test_print_passed "$*"
		return
	fi

	if [[ -n ${alt_expected_sk+x} && "${sk}" == "${alt_expected_sk}" &&
	      -n ${alt_expected_asc+x} && "${asc}" == "${alt_expected_asc}" ]]; then
		zbc_test_print_passed "$*"
		return
	fi

	zbc_test_print_failed_sk "$*"
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_check_no_sk_ascq
 * @brief Verify that no sense key or ASC-ASCQ was reported.
 *
 * Passes if both sk and asc are empty, indicating the command completed
 * without error. Fails otherwise, printing the unexpected sense data.
 *
 * @param ... Optional detail text forwarded to the result printer.
 * @return void.
 */
DOXYGEN
function zbc_test_check_no_sk_ascq()
{
	local expected_sk=""
	local expected_asc=""
	if [ -z "${sk}" -a -z "${asc}" ]; then
		zbc_test_print_passed "$*"
	else
		zbc_test_print_failed_sk "$*"
	fi
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_fail_if_sk_ascq
 * @brief Fail the test if any sense key or ASC-ASCQ is present.
 *
 * Calls zbc_test_get_sk_ascq to refresh error state, then checks whether
 * sk or asc is non-empty. If so, prints a failure and returns 1.
 *
 * @param ... Optional detail text forwarded to the failure printer.
 * @return 0 if no sense data present, 1 if sense data detected.
 */
DOXYGEN
function zbc_test_fail_if_sk_ascq()
{
	zbc_test_get_sk_ascq
	if [ -n "${sk}" -o -n "${asc}" ]; then
		local expected_sk=""
		local expected_asc=""
		zbc_test_print_failed_sk "$*"
		return 1
	fi
	return 0
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_fail_exit_if_sk_ascq
 * @brief Fail and exit the test script if any sense key or ASC-ASCQ is present.
 *
 * Calls zbc_test_fail_if_sk_ascq. If that returns non-zero, exits the
 * script with code 1.
 *
 * @param ... Optional detail text forwarded to zbc_test_fail_if_sk_ascq.
 * @return 0 if no sense data present. Does not return on failure (exit 1).
 */
DOXYGEN
function zbc_test_fail_exit_if_sk_ascq()
{
	zbc_test_fail_if_sk_ascq "$*"
	if [[ $? -ne 0 ]]; then
		exit 1
	fi
	return 0
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_fail_exit
 * @brief Unconditionally fail and exit the test script.
 *
 * First checks for unexpected sense data via zbc_test_fail_exit_if_sk_ascq.
 * If that passes, prints a generic failure with a stack trace from
 * _stacktrace and exits with code 1.
 *
 * @param ... Optional detail text included in the failure message.
 * @return Does not return; calls exit 1.
 */
DOXYGEN
function zbc_test_fail_exit()
{
	zbc_test_fail_exit_if_sk_ascq "$*"
	zbc_test_print_failed "$* (from `_stacktrace`)"
	exit 1
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_print_failed_zc
 * @brief Print a "Failed" result with zone condition mismatch details.
 *
 * Calls zbc_test_print_failed, then prints the expected vs. actual zone
 * condition values to both the log file and terminal.
 *
 * Relies on globals: expected_cond, target_cond, log_file.
 *
 * @param ... Optional detail text forwarded to zbc_test_print_failed.
 * @return void.
 */
DOXYGEN
function zbc_test_print_failed_zc()
{
	zbc_test_print_failed "$@"

	echo "=> Expected zone condition ${expected_cond}, Got ${target_cond}" >> ${log_file} 2>&1
	echo "            => Expected zone condition ${expected_cond}"
	echo "                    Got zone condition ${target_cond}"
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_check_wp_eq
 * @brief Check that the target write pointer equals an expected value.
 *
 * Compares the global target_ptr against the specified expected write
 * pointer sector. Prints a failure if they differ.
 *
 * @param $1 expected_wp Expected write pointer sector (integer).
 * @param ... Error message text printed on failure.
 * @return 0 if write pointer matches, 1 on mismatch.
 */
DOXYGEN
# zbc_test_check_wp_eq expected_wp err_msg
function zbc_test_check_wp_eq()
{
	local -i expected_wp=$1
	shift
	if [ ${target_ptr} -ne ${expected_wp} ]; then
		zbc_test_print_failed "(WP=${target_ptr}) != (expected=${expected_wp}); $*"
		return 1
	fi
	return 0
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_check_wp_inrange
 * @brief Check that the target write pointer is within a given range.
 *
 * Verifies that the global target_ptr falls within [wp_min, wp_max]
 * inclusive. Prints a failure if it is outside the range.
 *
 * @param $1 wp_min Minimum acceptable write pointer sector (integer).
 * @param $2 wp_max Maximum acceptable write pointer sector (integer).
 * @param ... Error message text printed on failure.
 * @return 0 if write pointer is in range, 1 if out of range.
 */
DOXYGEN
# zbc_test_check_wp_inrange wp_min wp_max err_msg
function zbc_test_check_wp_inrange()
{
	local -i wp_min=$1
	shift
	local -i wp_max=$1
	shift
	if [ ${target_ptr} -lt ${wp_min} -o ${target_ptr} -gt ${wp_max} ]; then
		zbc_test_print_failed "(WP=${target_ptr}) != (expected=${expected_wp}); $*"
		zbc_test_print_failed "(WP=${target_ptr}) not within [${wp_min}, ${wp_max}]; $*"
		return 1
	fi
	return 0
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_check_zone_cond
 * @brief Validate zone condition and write pointer for the target zone.
 *
 * Checks that no unexpected sense data is present, then verifies that
 * target_cond matches expected_cond. For EMPTY, CLOSED, and OPEN
 * conditions, additionally validates that the write pointer is within the
 * expected range for the zone.
 *
 * Relies on globals: sk, asc, target_cond, expected_cond, target_ptr,
 * target_slba, target_size, ZC_EMPTY, ZC_CLOSED, ZC_OPEN.
 *
 * @param ... Optional detail text forwarded to the result printer.
 * @return void.
 */
DOXYGEN
function zbc_test_check_zone_cond()
{
	local expected_sk=""
	local expected_asc=""

	# Check sk_ascq first
	if [ -n "${sk}" -o -n "${asc}" ]; then
		zbc_test_print_failed_sk "$*"
	elif [ "${target_cond}" != "${expected_cond}" ]; then
		zbc_test_print_failed_zc "$*"
	else
		# For zone conditions with valid WP, check within zone range
		if [[ "${expected_cond}" == @(${ZC_EMPTY}) ]]; then
			zbc_test_check_wp_eq ${target_slba}
			if [ $? -ne 0 ]; then return; fi
		elif [[ "${expected_cond}" == @(${ZC_CLOSED}) ]]; then
			zbc_test_check_wp_inrange \
				      $(( ${target_slba} + 1 )) \
				      $(( ${target_slba} + ${target_size} - 1 ))
			if [ $? -ne 0 ]; then return; fi
		elif [[ "${expected_cond}" == @(${ZC_OPEN}) ]]; then
			zbc_test_check_wp_inrange \
				      ${target_slba} \
				      $(( ${target_slba} + ${target_size} - 1 ))
			if [ $? -ne 0 ]; then return; fi
		fi
		zbc_test_print_passed "$*"
	fi
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_check_zone_cond_wp
 * @brief Validate zone condition and exact write pointer position.
 *
 * Checks for unexpected sense data, verifies that target_cond matches
 * expected_cond, and confirms target_ptr equals the specified expected
 * write pointer value.
 *
 * @param $1 expected_wp Expected write pointer sector (integer).
 * @param ... Error message text forwarded to the result printer.
 * @return void.
 */
DOXYGEN
# zbc_test_check_zone_cond_wp expected_wp err_msg
function zbc_test_check_zone_cond_wp()
{
	local expected_sk=""
	local expected_asc=""
	local -i expected_wp=$1
	shift

	# Check sk_ascq first
	if [ -n "${sk}" -o -n "${asc}" ]; then
		zbc_test_print_failed_sk "$*"
	elif [ "${target_cond}" != "${expected_cond}" ]; then
		zbc_test_print_failed_zc "$*"
	elif [ ${target_ptr} -ne ${expected_wp} ]; then
		zbc_test_print_failed "(WP=${target_ptr}) != (expected=${expected_wp}); $*"
	else
		zbc_test_print_passed "$*"
	fi
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_check_sk_ascq_zone_cond
 * @brief Validate sense key, ASC-ASCQ, and zone condition together.
 *
 * Checks that sk/asc match expected_sk/expected_asc and that target_cond
 * matches expected_cond. If ZBC_ACCEPT_ANY_FAIL is set and a sense key
 * is present, the expected values are overridden with the actuals.
 *
 * @param ... Optional detail text forwarded to the result printer.
 * @return void.
 */
DOXYGEN
# Check for expected_sk/expected_asc and expected_cond
function zbc_test_check_sk_ascq_zone_cond()
{
	if [ -n "${ZBC_ACCEPT_ANY_FAIL}" -a -n "${expected_sk}" ]; then
		if [ -n "${sk}" ]; then
			expected_sk="${sk}"
			expected_asc="${asc}"
		fi
	fi

	if [ "${sk}" != "${expected_sk}" -o "${asc}" != "${expected_asc}" ]; then
		zbc_test_print_failed_sk "$*"
	elif [ "${target_cond}" != "${expected_cond}" ]; then
		zbc_test_print_failed_zc "$*"
	else
		zbc_test_print_passed "$*"
	fi
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_check_sk_ascq_zone_cond_wp
 * @brief Validate sense key, ASC-ASCQ, zone condition, and write pointer.
 *
 * Checks that sk/asc match expected_sk/expected_asc, target_cond matches
 * expected_cond, and target_ptr equals the specified expected write pointer.
 * If ZBC_ACCEPT_ANY_FAIL is set, actual sense values override expectations.
 *
 * @param $1 expected_wp Expected write pointer sector (integer).
 * @param ... Optional detail text forwarded to the result printer.
 * @return void.
 */
DOXYGEN
# Check for expected_sk/expected_asc, expected_cond, and expected_wp
function zbc_test_check_sk_ascq_zone_cond_wp()
{
	local -i expected_wp=$1
	shift

	if [ -n "${ZBC_ACCEPT_ANY_FAIL}" -a -n "${expected_sk}" ]; then
		if [ -n "${sk}" ]; then
			expected_sk="${sk}"
			expected_asc="${asc}"
		fi
	fi

	if [ "${sk}" != "${expected_sk}" -o "${asc}" != "${expected_asc}" ]; then
		zbc_test_print_failed_sk "$*"
	elif [ "${target_cond}" != "${expected_cond}" ]; then
		zbc_test_print_failed_zc "$*"
	elif [ ${target_ptr} -ne ${expected_wp} ]; then
		zbc_test_print_failed "(WP=${target_ptr}) != (expected=${expected_wp}); $*"
	else
		zbc_test_print_passed "$*"
	fi
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_dump_zone_info
 * @brief Dump zone report for the device to the zone info file.
 *
 * Runs zbc_report_zones on the global device and writes the output to
 * the dump_zone_info_file for post-mortem analysis.
 *
 * @return void.
 */
DOXYGEN
function zbc_test_dump_zone_info()
{
	zbc_report_zones ${device} > ${dump_zone_info_file}
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_dump_zone_realm_info
 * @brief Dump zone domain and realm reports for the device.
 *
 * Runs zbc_report_domains and zbc_report_realms on the global device,
 * writing combined output to dump_zone_realm_info_file for post-mortem
 * analysis of XMR state.
 *
 * @return void.
 */
DOXYGEN
function zbc_test_dump_zone_realm_info()
{
	zbc_report_domains ${device} > ${dump_zone_realm_info_file}
	zbc_report_realms ${device} >> ${dump_zone_realm_info_file}
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_dump_info
 * @brief Dump all zone information for the device.
 *
 * Calls zbc_test_dump_zone_info unconditionally, and additionally calls
 * zbc_test_dump_zone_realm_info when the device supports zone domains
 * and realms (zdr_device != 0).
 *
 * @return void.
 */
DOXYGEN
function zbc_test_dump_info()
{
	zbc_test_dump_zone_info
	if [ "${zdr_device}" -ne 0 ]; then
		zbc_test_dump_zone_realm_info
	fi
}

: <<'DOXYGEN'
/**
 * @fn zbc_test_check_failed
 * @brief Check whether the test failed and dump info on failure.
 *
 * Scans the log file for a "TESTRESULT==Failed" line. If found, dumps
 * all zone information via zbc_test_dump_info for post-mortem analysis.
 *
 * @return 0 if the test passed, 1 if a failure was detected.
 */
DOXYGEN
# Dump info files after a failed test -- returns 1 if test failed
function zbc_test_check_failed()
{
	failed=`cat ${log_file} | grep -m 1 "TESTRESULT==Failed"`
	if [[ ! -z "${failed}" ]]; then
		zbc_test_dump_info
		return 1
	fi

	return 0
}
