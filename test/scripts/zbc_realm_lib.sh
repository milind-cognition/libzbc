#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# zbc_realm_lib.sh — Realm-related helper functions for the ZBC test suite.
# Sourced by zbc_test_lib.sh; do not execute directly.

## @file zbc_realm_lib.sh
## @brief Realm-related helper functions for the ZBC/ZAC test suite.
##
## This shell library provides functions for querying, searching, and
## inspecting zone realms on XMR (cross-managed-resource) devices.
## It is sourced by zbc_test_lib.sh and should not be executed directly.
##
## @note All functions in this file operate on global shell variables
##       populated by the test harness (e.g. zone_realm_info_file,
##       nr_realms, realm_* arrays).

# Zone realm manipulation functions

## @brief Retrieve zone realm information for the current device.
##
## Determines the CMR and SMR zone type strings based on the device
## capabilities, executes zbc_test_report_realms to populate the
## zone_realm_info_file, and counts total realms and activation
## categories.
##
## @return 0 on success; exits via zbc_test_print_not_applicable if
##         the device lacks conventional or sequential zone support.
function zbc_test_get_zone_realm_info()
{
	if [ ${report_realms} -eq 0 ]; then
		echo -n "(emulated REALMS)"
	fi

	if [ ${conv_zone} -ne 0 ]; then
		cmr_type="conv"
	elif [ ${sobr_zone} -ne 0 ]; then
		cmr_type="sobr"
	else
		zbc_test_print_not_applicable "Conventional zones are not supported by the device"
	fi

	if [ ${seq_req_zone} -ne 0 ]; then
		smr_type="seq"
	elif [ ${seq_pref_zone} -ne 0 ]; then
		smr_type="seqp"
	else
		zbc_test_print_not_applicable "Sequential zones are not supported by the device"
	fi

	local _cmd="${bin_path}/zbc_test_report_realms ${device}"
	echo "" >> ${log_file} 2>&1
	echo "## `date -Ins` Executing: ${_cmd} > ${zone_realm_info_file} 2>&1" >> ${log_file} 2>&1
	echo "" >> ${log_file} 2>&1

	${VALGRIND} ${_cmd} > ${zone_realm_info_file} 2>> ${log_file}

	_zbc_test_count_zone_realms
	_zbc_test_count_actv_as_conv_realms
	_zbc_test_count_actv_as_seq_realms

	return 0
}

## @brief Count the total number of zone realms reported by the device.
##
## Parses zone_realm_info_file for ZONE_REALM_INFO entries and stores
## the count in the global variable nr_realms.  Exits with failure if
## the device is a Zone Domains device yet reports zero realms.
function _zbc_test_count_zone_realms()
{
	nr_realms=`cat ${zone_realm_info_file} | grep "\[ZONE_REALM_INFO\]" | wc -l`

	if [ ${zdr_device} -ne 0 -a ${nr_realms} -eq 0 ]; then
		zbc_test_print_failed "Zone Domains device reports zero realm count"
		date -Ins
		exit 1
	fi
}

## @brief Count realms that can be activated as conventional.
##
## Parses the actv_as_conv column (field 9) from zone_realm_info_file
## and stores the count of "Y" entries in nr_actv_as_conv_realms.
function _zbc_test_count_actv_as_conv_realms()
{
	local _IFS="${IFS}"
	nr_actv_as_conv_realms=`cat ${zone_realm_info_file} | while IFS=, read a b c d e f g h i j k; do echo $i; done | grep -c Y`
	IFS="$_IFS"
}

## @brief Count realms that can be activated as sequential.
##
## Parses the actv_as_seq column (field 10) from zone_realm_info_file
## and stores the count of "Y" entries in nr_actv_as_seq_realms.
function _zbc_test_count_actv_as_seq_realms()
{
	local _IFS="${IFS}"
	nr_actv_as_seq_realms=`cat ${zone_realm_info_file} | while IFS=, read a b c d e f g h i j k; do echo $j; done | grep -c Y`
	IFS="$_IFS"
}

## @brief Check whether the currently-found realm contains faulty zones.
##
## Iterates over every domain in the realm previously located by a
## zbc_test_search_* call and inspects each zone's condition.  A realm
## is considered faulty if any of its zones are read-only or offline.
##
## @note Destroys target_zone information; re-get the zone after
##       calling if needed.
##
## @return 0 if the realm is healthy (or test_faulty checking is
##         disabled); 1 if any zone is read-only or offline.
function zbc_test_is_found_realm_faulty()
{
	local _target_slba
	local _realm_start
	local _realm_len

	if [ "${test_faulty}" -eq 0 ]; then
		return 0
	fi

	zbc_test_get_zone_info

	for (( j=0 ; j<${realm_nr_domains} ; j++ )) ; do
		_realm_start=${realm_start_lba[j]}
		_realm_len=${realm_length[j]}
		_target_slba=${_realm_start}
		for (( i=0 ; i<${_realm_len} ; i++ )) ; do
			zbc_test_get_target_zone_from_slba_or_fail_cached ${_target_slba}
			if [ $? -ne 0 ]; then
				break
			fi
			if [ ${target_size} -eq 0 ]; then
				break
			fi
			if [[ ${target_cond} == @(${ZC_RDONLY}|${ZC_OFFLINE}) ]]; then
				return 1
			fi
			_target_slba=$(( ${target_slba} + ${target_size} ))
		done
	done

	return 0
}

## @brief Parse a single domain-specific realm item into global arrays.
##
## Splits a colon-delimited item string and stores the domain type,
## start LBA, end LBA, and length into the corresponding realm_*
## arrays at the given domain index.
##
## @param $1 Domain index (integer) within the realm.
## @param $2 Colon-delimited item string of the form
##           "type:start_lba:end_lba:length".
##
## @return 0 always.
function zbc_parse_realm_item()
{
	local _ifs="${IFS}"
	local -i _dom=${1}

	IFS=$':\n'
	set -- ${2}

	realm_dom_type[${_dom}]=${1}
	realm_start_lba[$_dom]=${2}
	realm_end_lba[$_dom]=${3}
	realm_length[$_dom]=${4}
	IFS="$_ifs"
	return 0
}

## @brief Echo the start LBA of the current realm for a given zone type.
##
## Looks up the domain whose type matches the requested zone type and
## prints its start LBA to stdout.
##
## @pre zbc_test_search_zone_realm_by_number() or
##      zbc_test_search_realm_by_type_and_actv() must have been called
##      to populate the realm_* arrays.
##
## @param $1 Zone type in textual form: "conv", "seq", "seqp", or "sobr".
##
## @return 0 if the type was found and the LBA was printed;
##         1 if no matching domain exists in the current realm.
function zbc_realm_start()
{
	local -i _zt

	case "${1}" in
	"conv")
		_zt=$(( ${ZT_CONV} ))
		;;
	"seq")
		_zt=$(( ${ZT_SWR} ))
		;;
	"seqp")
		_zt=$(( ${ZT_SWP} ))
		;;
	"sobr")
		_zt=$(( ${ZT_SOBR} ))
		;;
	* )
		zbc_test_fail_exit "zbc_realm_start bad zone type arg=\"$1\""
		;;
	esac

	for (( i=0 ; i<${realm_nr_domains} ; i++ )) ; do
		if [[ ${realm_dom_type[i]} == $_zt ]]; then
			echo "${realm_start_lba[i]}"
			return 0
		fi
	done

	return 1
}

## @brief Echo the start LBA of the current realm's CMR domain.
##
## Convenience wrapper around zbc_realm_start() using the global
## cmr_type variable.
##
## @return 0 on success; 1 if no CMR domain exists.
function zbc_realm_cmr_start()
{
	zbc_realm_start "${cmr_type}"
}

## @brief Echo the start LBA of the current realm's SMR domain.
##
## Convenience wrapper around zbc_realm_start() using the global
## smr_type variable.
##
## @return 0 on success; 1 if no SMR domain exists.
function zbc_realm_smr_start()
{
	zbc_realm_start "${smr_type}"
}

## @brief Echo the length (in zones) of the current realm for a given zone type.
##
## Looks up the domain whose type matches the requested zone type and
## prints its length to stdout.
##
## @pre zbc_test_search_zone_realm_by_number() or
##      zbc_test_search_realm_by_type_and_actv() must have been called
##      to populate the realm_* arrays.
##
## @param $1 Zone type in textual form: "conv", "seq", "seqp", or "sobr".
##
## @return 0 if the type was found and the length was printed;
##         1 if no matching domain exists in the current realm.
function zbc_realm_len()
{
	local -i _zt

	case "${1}" in
	"conv")
		_zt=$(( ${ZT_CONV} ))
		;;
	"seq")
		_zt=$(( ${ZT_SWR} ))
		;;
	"seqp")
		_zt=$(( ${ZT_SWP} ))
		;;
	"sobr")
		_zt=$(( ${ZT_SOBR} ))
		;;
	* )
		zbc_test_fail_exit "zbc_realm_len bad zone type arg=\"$1\""
		;;
	esac

	for (( i=0 ; i<${realm_nr_domains} ; i++ )) ; do
		if [[ ${realm_dom_type[i]} == $_zt ]]; then
			echo "${realm_length[i]}"
			return 0
		fi
	done

	return 1
}

## @brief Echo the length (in zones) of the current realm's CMR domain.
##
## Convenience wrapper around zbc_realm_len() using the global
## cmr_type variable.
##
## @return 0 on success; 1 if no CMR domain exists.
function zbc_realm_cmr_len()
{
	zbc_realm_len "${cmr_type}"
}

## @brief Echo the length (in zones) of the current realm's SMR domain.
##
## Convenience wrapper around zbc_realm_len() using the global
## smr_type variable.
##
## @return 0 on success; 1 if no SMR domain exists.
function zbc_realm_smr_len()
{
	zbc_realm_len "${smr_type}"
}

## @brief Search for a zone realm by its realm number.
##
## Locates the realm whose number matches the given argument in
## zone_realm_info_file and populates the global realm_* variables
## and arrays with its fields and per-domain information.
##
## @param $1 Realm number (zero-based index into the realm list).
##
## @return 0 if the realm was found and globals were populated;
##         1 if the realm number is out of range or not found.
function zbc_test_search_zone_realm_by_number()
{
	local realm_number=${1}

	if [ ${realm_number} -ge ${nr_realms} ]; then
		zbc_test_print_failed "realm=${realm_number} >= nr_realms=${nr_realms}"
		realm_nr_domains=0
		return 1
	fi

	# [ZONE_REALM_INFO],<num>,<domain>,<type>,<restr>,<allow_actv>,<allow_reset>,<actv_mask>,<actv_as_conv>,<actv_as_seq>,<nr_domains>;
	# 1                 2     3        4      5       6            7             8           9              10            11
	#
	# then <domain-spcific info>;...
	for _line in `cat ${zone_realm_info_file} | grep -E "\[ZONE_REALM_INFO\],(${realm_number}),.*,.*,.*,.*,.*,.*,.*,.*,.*"`; do

		local _IFS="${IFS}"
		local -i _dom=0

		IFS=$',\n'
		set -- ${_line}

		realm_num=$(( ${2} ))
		realm_domain=${3}
		realm_type=${4}
		realm_restrictions=${5}
		realm_allow_actv=${6}
		realm_allow_reset=${7}
		realm_actv_mask=${8}
		realm_actv_as_conv=${9}
		realm_actv_as_seq=${10}
		realm_nr_domains=${11}

		realm_dom_type=()
		realm_start_lba=()
		realm_end_lba=()
		realm_length=()

		IFS=$';\n'
		set -- ${_line}
		shift
		for item in $@; do
			zbc_parse_realm_item $_dom $item
			_dom=${_dom}+1
		done
		IFS="$_IFS"

		return 0

	done

	# Garbage attracts bugs, so clean it out
	realm_nr_domains=0
	realm_dom_type=()
	realm_start_lba=()
	realm_end_lba=()
	realm_length=()

	return 1
}

## @brief Search for the zone realm that contains a given LBA.
##
## Iterates over all realm entries in zone_realm_info_file and checks
## each domain's start/end LBA range.  On a match the global realm_*
## variables are populated with the matching realm's information.
##
## @param $1 Logical Block Address to search for.
##
## @return 0 if a realm containing the LBA was found;
##         1 if the LBA is out of range or no realm contains it.
function zbc_test_search_realm_by_lba()
{
	local _LBA=${1}

	if [ ${_LBA} -ge ${max_lba} ]; then
		zbc_test_print_failed "LBA=${_LBA} >= max_lba=${max_lba}"
		realm_nr_domains=0
		return 1
	fi

	# [ZONE_REALM_INFO],<num>,<domain>,<type>,<restr>,<allow_actv>,<allow_reset>,<actv_mask>,<actv_as_conv>,<actv_as_seq>,<nr_domains>;
	# 1                 2     3        4      5       6            7             8           9              10            11
	#
	# then <domain-spcific info>;...
	for _line in `cat ${zone_realm_info_file} | grep -E "\[ZONE_REALM_INFO\],.*,.*,.*,.*,.*,.*,.*,.*,.*,.*"`; do

		local _IFS="${IFS}"
		local -i _dom=0

		IFS=$',\n'
		set -- ${_line}

		realm_num=$(( ${2} ))
		realm_domain=${3}
		realm_type=${4}
		realm_restrictions=${5}
		realm_allow_actv=${6}
		realm_allow_reset=${7}
		realm_actv_mask=${8}
		realm_actv_as_conv=${9}
		realm_actv_as_seq=${10}
		realm_nr_domains=${11}

		realm_dom_type=()
		realm_start_lba=()
		realm_end_lba=()
		realm_length=()

		IFS=$';\n'
		set -- ${_line}
		shift
		for item in $@; do
			zbc_parse_realm_item $_dom $item
			_dom=${_dom}+1
		done
		IFS="$_IFS"

		for (( i=0 ; i<${realm_nr_domains} ; i++ )) ; do
			if [[ realm_start_lba[${i}] -le ${_LBA} &&
				    ${_LBA} -le realm_end_lba[${i}] ]]; then
				return 0
			fi
		done

	done

	# Garbage attracts bugs, so clean it out
	realm_nr_domains=0
	realm_dom_type=()
	realm_start_lba=()
	realm_end_lba=()
	realm_length=()

	return 1
}

## @brief Check whether a specific realm (by number) contains faulty zones.
##
## Looks up the realm by number and delegates to
## zbc_test_is_found_realm_faulty() to inspect zone conditions.
##
## @note Destroys target_zone and current realm information; re-get
##       if needed after calling.
##
## @param $1 Realm number to check.
##
## @return 0 if the realm is healthy; non-zero if any zone is
##         read-only or offline.
function zbc_test_is_realm_faulty()
{
	zbc_test_search_zone_realm_by_number $1
	zbc_test_is_found_realm_faulty
}

## @brief Search for a realm matching a given type and activation capability.
##
## Scans zone_realm_info_file for a realm whose type matches the
## requested value and whose activation flags satisfy the given
## constraint.  When the NOFAULTY option is specified, the function
## additionally ensures the found realm (and its successor) are free
## of read-only or offline zones, providing a pair of contiguous
## non-faulty realms suitable for write testing.
##
## @note Destroys target_zone information; re-get the zone after
##       calling if needed.
##
## @param $1 Realm type to match (numeric type code).
## @param $2 Activation filter keyword: "conv", "noconv", "seq",
##           "noseq", "both", or "none".
## @param $3 (Optional) "NOFAULTY" to skip faulty realms and require
##           two contiguous non-faulty realms of the same type.
##
## @return 0 if a matching realm was found and globals were populated;
##         1 if no realm satisfies the criteria.
function zbc_test_search_realm_by_type_and_actv()
{
	local realm_search_type=${1}
	local _NOFAULTY="$3"
	local actv

	case "${2}" in
	"conv")
		actv="Y,.*"
		;;
	"noconv")
		actv="N,.*"
		;;
	"seq")
		actv=".*,Y"
		;;
	"noseq")
		actv=".*,N"
		;;
	"both")
		actv="Y,Y"
		;;
	"none")
		actv="N,N"
		;;
	* )
		zbc_test_fail_exit "zbc_test_search_realm_by_type_and_actv bad can_activate_as arg=\"$2\""
		;;
	esac

	# [ZONE_REALM_INFO],<num>,<domain>,<type>,<restr>,<allow_actv>,<allow_reset>,<actv_mask>,<actv_as_conv>,<actv_as_seq>,<nr_domains>;
	# 1                 2     3        4      5       6            7             8           9              10            11
	#
	# then <domain-spcific info>;...
	for _line in `cat ${zone_realm_info_file} | grep -E "\[ZONE_REALM_INFO\],.*,.*,(${realm_search_type}),.*,.*,.*,0x.*,${actv},.*"`; do

		local _IFS="${IFS}"
		local -i _dom=0

		IFS=$',\n'
		set -- ${_line}

		realm_num=$(( ${2} ))
		realm_domain=${3}
		realm_type=${4}
		realm_restrictions=${5}
		realm_allow_actv=${6}
		realm_allow_reset=${7}
		realm_actv_mask=${8}
		realm_actv_as_conv=${9}
		realm_actv_as_seq=${10}
		realm_nr_domains=${11}

		realm_dom_type=()
		realm_start_lba=()
		realm_end_lba=()
		realm_length=()

		IFS=$';\n'
		set -- ${_line}
		shift
		for item in $@; do
			zbc_parse_realm_item $_dom $item
			_dom=${_dom}+1
		done
		IFS="$_IFS"

		if [ "${realm_allow_actv}" != "Y" ]; then
			continue
		fi

		if [ "${_NOFAULTY}" != "NOFAULTY" ]; then
			return 0
		fi

		# NOFAULTY:
		# Ensure the returned realm is OK for write testing, etc
		zbc_test_is_found_realm_faulty
		if [ $? -ne 0 ]; then
			continue
		fi

		# Ensure two contiguous non-faulty realms needed by some tests.
		# The realms must both have the requested type and actv_as_.

		if [ $(( ${realm_num} + 1 )) -ge ${nr_realms} ]; then
			continue	# second realm number out of range
		fi

		local -i found_realm_num=${realm_num}
		local found_realm_type="${realm_type}"
		local found_realm_actv_conv="${realm_actv_as_conv}"
		local found_realm_actv_seq="${realm_actv_as_seq}"

		zbc_test_is_realm_faulty $(( ${realm_num} + 1 ))
		if [ $? -ne 0 ]; then
			continue	# second realm is faulty
		fi

		if [ "${realm_type}" != "${found_realm_type}" ]; then
			continue	# second realm is different type
		fi

		if [ "${realm_actv_as_seq}" != "${found_realm_actv_seq}" ]; then
			continue	# second realm mismatches seq_actv
		fi

		if [ "${realm_actv_as_conv}" != "${found_realm_actv_conv}" ]; then
			continue	# second realm mismatches conv_actv
		fi

		# Reset the found realm to the first of the pair
		zbc_test_search_zone_realm_by_number ${found_realm_num}
		return 0

	done

	# Garbage attracts bugs, so clean it out
	realm_nr_domains=0
	realm_dom_type=()
	realm_start_lba=()
	realm_end_lba=()
	realm_length=()

	return 1
}

## @brief Search for a realm by type and activation, or mark test N/A.
##
## Wrapper around zbc_test_search_realm_by_type_and_actv() that prints
## a "not applicable" message and exits the test if no matching realm
## is found.
##
## @param $1 Realm type to match (passed through).
## @param $2 Activation filter keyword (passed through).
## @param $3 (Optional) "NOFAULTY" flag (passed through).
function zbc_test_search_realm_by_type_and_actv_or_NA()
{
	zbc_test_search_realm_by_type_and_actv "$@"
	if [[ $? -ne 0 ]]; then
		zbc_test_print_not_applicable \
		    "No realms of type $1 and activatable as $2 $3"
	fi
}

## @brief Skip the test if realm boundaries shift for the given type.
##
## Checks the global "<type>_shifting" flag and, if non-zero, prints a
## "not applicable" message and exits the test.
##
## @param $1 Zone type prefix (e.g. "conv", "seq") used to construct
##           the shifting flag variable name "<type>_shifting".
function zbc_test_realm_boundaries_not_shifting_or_NA()
{
	local flg="$1_shifting"

	if [ ${!flg} -ne 0 ]; then
		zbc_test_print_not_applicable \
		    "Shifting realms of type $1 are not supported for this operation"
	fi
}

## @brief Calculate the number of conventional and sequential zones
##        across a range of realms.
##
## Starting from the given realm number, iterates over the specified
## number of consecutive realms and accumulates zone counts by type.
## Results are stored in the global variables nr_conv_zones and
## nr_seq_zones.
##
## @param $1 Starting realm number.
## @param $2 Number of consecutive realms to process.
##
## @return 0 if all requested realms were processed;
##         1 if the realm file was exhausted before processing
##         the requested count.
function zbc_test_calc_nr_realm_zones()
{
	local _realm_num=${1}
	local -i _nr_realms=${2}
	local _actv_as_conv
	local _actv_as_seq
	local -i _nr_domains
	nr_conv_zones=0
	nr_seq_zones=0

	# [ZONE_REALM_INFO],<num>,<domain>,<type>,<restr>,<allow_actv>,<allow_reset>,<actv_mask>,<actv_as_conv>,<actv_as_seq>,<nr_domains>;
	# 1                 2     3        4      5       6            7             8           9              10            11
	#
	# then <domain-spcific info>;...
	for _line in `cat ${zone_realm_info_file} | grep "\[ZONE_REALM_INFO\]"`; do

		local _IFS="${IFS}"
		local -i _dom

		IFS=$',\n'
		set -- ${_line}

		if [[ $(( ${2} )) -ge $(( ${_realm_num} )) ]]; then

			_actv_as_conv=${9}
			_actv_as_seq=${10}
			_nr_domains=${11}

			IFS=$';\n'
			set -- ${_line}
			shift
			_dom=0
			for item in $@; do
				zbc_parse_realm_item $_dom $item
				_dom=${_dom}+1
			done

			if [ "${_actv_as_conv}" == "Y" ]; then
				for (( i=0; i<_nr_domains; i++ )); do
					if [[ ${realm_dom_type[i]} == $(( ${ZT_CONV} )) || \
					      ${realm_dom_type[i]} == $(( ${ZT_SOBR} )) ]]; then
						nr_conv_zones=$(( ${nr_conv_zones} + ${realm_length[i]} ))
						break
					fi
				done
			fi

			if [ "${_actv_as_seq}" == "Y" ]; then
				for (( i=0; i<_nr_domains; i++ )); do
					if [[ ${realm_dom_type[i]} == $(( ${ZT_SWR} )) || \
					      ${realm_dom_type[i]} == $(( ${ZT_SWP} )) ]]; then
						nr_seq_zones=$(( ${nr_seq_zones} + ${realm_length[i]} ))
						break
					fi
				done
			fi

			_nr_realms=$(( ${_nr_realms} - 1 ))

		fi

		IFS="$_IFS"

		if [ ${_nr_realms} -eq 0 ]; then
			return 0
		fi
	done

	return 1
}
