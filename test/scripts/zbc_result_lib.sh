#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# zbc_result_lib.sh — Result checking, printing, and condition validation
# functions for the ZBC test suite.
# Sourced by zbc_test_lib.sh; do not execute directly.

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

function zbc_test_reset_err()
{
	echo "Resetting log error:" >> ${log_file}
	echo "[TEST][ERROR][SENSE_KEY],," >> ${log_file}
	echo "[TEST][ERROR][ASC_ASCQ],," >> ${log_file}
	echo "[TEST][ERROR][ERR_ZA],," >> ${log_file}
	echo "[TEST][ERROR][ERR_CBF],," >> ${log_file}
}

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

function zbc_test_print_not_applicable()
{
	zbc_test_print_res "" "N/A $*"
	if [[ ${SCRIPT_DEBUG} -ne 0 ]]; then
	    zbc_test_dump_info
	fi
	exit 0
}

function zbc_test_print_failed()
{
	if [ $# -gt 0 ]; then
		zbc_test_print_res "${red}" "Failed $*"
	else
		zbc_test_print_res "${red}" "Failed"
	fi
}

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

function zbc_test_fail_exit_if_sk_ascq()
{
	zbc_test_fail_if_sk_ascq "$*"
	if [[ $? -ne 0 ]]; then
		exit 1
	fi
	return 0
}

function zbc_test_fail_exit()
{
	zbc_test_fail_exit_if_sk_ascq "$*"
	zbc_test_print_failed "$* (from `_stacktrace`)"
	exit 1
}

function zbc_test_print_failed_zc()
{
	zbc_test_print_failed "$@"

	echo "=> Expected zone condition ${expected_cond}, Got ${target_cond}" >> ${log_file} 2>&1
	echo "            => Expected zone condition ${expected_cond}"
	echo "                    Got zone condition ${target_cond}"
}

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

function zbc_test_dump_zone_info()
{
	zbc_report_zones ${device} > ${dump_zone_info_file}
}

function zbc_test_dump_zone_realm_info()
{
	zbc_report_domains ${device} > ${dump_zone_realm_info_file}
	zbc_report_realms ${device} >> ${dump_zone_realm_info_file}
}

function zbc_test_dump_info()
{
	zbc_test_dump_zone_info
	if [ "${zdr_device}" -ne 0 ]; then
		zbc_test_dump_zone_realm_info
	fi
}

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
