// SPDX-License-Identifier: BSD-2-Clause
// SPDX-License-Identifier: LGPL-3.0-or-later
/**
 * @file zbc_test_wp_check.c
 * @brief Unit test for zbc_zone_check_wp().
 *
 * This file is part of libzbc.
 *
 * Copyright (c) 2020 Western Digital Corporation or its affiliates.
 *
 * Host-runnable check of zbc_zone_check_wp() using synthetic zone
 * descriptors. Does not require a zoned device.
 */
#include "zbc.h"

int zbc_log_level = ZBC_LOG_ERROR;

/* Zone 1873 from FWVAL-4471: start 0x3A880000, length 0x80000 */
/**
 * @brief Start sector (512B unit) of the synthetic test zone.
 */
#define ZSTART	0x3A880000ULL
/**
 * @brief Length in sectors (512B unit) of the synthetic test zone.
 */
#define ZLEN	0x80000ULL

/**
 * @brief Test case for zbc_zone_check_wp().
 *
 * Describes a synthetic zone descriptor (with start #ZSTART and length
 * #ZLEN) and the expected result of zbc_zone_check_wp() for that zone.
 */
struct wp_check_case {
	const char	*name;		/**< Test case description */
	uint8_t		type;		/**< Zone type (enum zbc_zone_type) */
	uint8_t		cond;		/**< Zone condition
					     (enum zbc_zone_condition) */
	uint64_t	wp;		/**< Zone write pointer (512B unit) */
	int		expected;	/**< Expected return value */
};

/**
 * @brief Test cases: valid and invalid write pointers for sequential zones,
 * and zones whose write pointer must not be checked.
 */
static const struct wp_check_case cases[] = {
	{ "SWR empty, wp == start",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_EMPTY, ZSTART, 0 },
	{ "SWR imp open, wp inside zone",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_IMP_OPEN, ZSTART + 0x1000, 0 },
	{ "SWR closed, wp == zone end",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_CLOSED, ZSTART + ZLEN, 0 },
	{ "SWR imp open, wp 8 sectors past end (FWVAL-4471)",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_IMP_OPEN, ZSTART + ZLEN + 8, -EIO },
	{ "SWR exp open, wp before start",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_EXP_OPEN, ZSTART - 8, -EIO },
	{ "SWR imp open, wp all ones",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_IMP_OPEN, (uint64_t)-1, -EIO },
	{ "SWP imp open, wp past end",
	  ZBC_ZT_SEQUENTIAL_PREF, ZBC_ZC_IMP_OPEN, ZSTART + ZLEN + 1, -EIO },
	{ "SOBR closed, wp before start",
	  ZBC_ZT_SEQ_OR_BEF_REQ, ZBC_ZC_CLOSED, 0, -EIO },
	{ "SWR full, invalid wp ignored",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_FULL, ZSTART + ZLEN + 8, 0 },
	{ "SWR read only, invalid wp ignored",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_RDONLY, (uint64_t)-1, 0 },
	{ "SWR offline, invalid wp ignored",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_OFFLINE, (uint64_t)-1, 0 },
	{ "SWR inactive, invalid wp ignored",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_INACTIVE, (uint64_t)-1, 0 },
	{ "SWR not wp, invalid wp ignored",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_NOT_WP, (uint64_t)-1, 0 },
	{ "Conventional zone not checked",
	  ZBC_ZT_CONVENTIONAL, ZBC_ZC_NOT_WP, (uint64_t)-1, 0 },
};

/**
 * @brief Run all test cases.
 *
 * For each entry of @ref cases, build a synthetic zone, call
 * zbc_zone_check_wp() on it and compare the result with the expected
 * value. A PASS or FAIL line is printed for each case.
 *
 * @return 0 if all test cases pass, 1 otherwise (used as the
 * automake test result).
 */
int main(void)
{
	unsigned int i, nr_cases = sizeof(cases) / sizeof(cases[0]);
	struct zbc_zone zone;
	int ret, failed = 0;

	for (i = 0; i < nr_cases; i++) {
		memset(&zone, 0, sizeof(zone));
		zone.zbz_type = cases[i].type;
		zone.zbz_condition = cases[i].cond;
		zone.zbz_start = ZSTART;
		zone.zbz_length = ZLEN;
		zone.zbz_write_pointer = cases[i].wp;

		ret = zbc_zone_check_wp("synthetic", 1873, &zone);
		if (ret != cases[i].expected) {
			printf("FAIL: %s: got %d, expected %d\n",
			       cases[i].name, ret, cases[i].expected);
			failed++;
		} else {
			printf("PASS: %s\n", cases[i].name);
		}
	}

	printf("%u cases, %d failed\n", nr_cases, failed);

	return failed ? 1 : 0;
}
