// SPDX-License-Identifier: BSD-2-Clause
// SPDX-License-Identifier: LGPL-3.0-or-later
/*
 * This file is part of libzbc.
 *
 * Copyright (C) 2026 Western Digital Corporation or its affiliates.
 *
 * Host-runnable regression check for zbc_zone_check_wp(): feeds synthetic
 * REPORT ZONES zone descriptors to the write pointer validation helper.
 * No zoned device is needed.
 */

/**
 * @file zbc_test_wp_check.c
 * @brief Unit test for zbc_zone_check_wp()
 *
 * Builds synthetic zone descriptors (including the zone reported in alert
 * FWVAL-4471) and checks that zbc_zone_check_wp() accepts valid write
 * pointers, rejects out-of-range write pointers with -EIO and ignores the
 * write pointer of zones in conditions where it is not valid.
 * Run by "make check".
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>

#include "zbc.h"

/**
 * @brief One write pointer check test case
 *
 * Describes a synthetic zone descriptor and the value that
 * zbc_zone_check_wp() is expected to return for it.
 */
struct wp_case {
	const char		*name;		/**< Test case description */
	enum zbc_zone_type	type;		/**< Zone type */
	enum zbc_zone_condition	cond;		/**< Zone condition */
	uint64_t		start;		/**< Zone start (512B sectors) */
	uint64_t		length;		/**< Zone length (512B sectors) */
	uint64_t		wp;		/**< Write pointer (512B sectors) */
	int			expected;	/**< Expected return value */
};

/* FWVAL-4471: zone 1873, SWR, IMP_OPEN */
/**
 * @brief Start sector of the zone reported in alert FWVAL-4471 (zone 1873)
 */
#define ALERT_START	0x3A880000ULL

/**
 * @brief Length in sectors of the zone reported in alert FWVAL-4471
 */
#define ALERT_LEN	0x80000ULL

/**
 * @brief Test cases run by main()
 *
 * Covers valid write pointers (zone start, inside the zone, zone end),
 * out-of-range write pointers (past the zone end, before the zone start,
 * 64-bit overflow) and zones whose write pointer is not checked (FULL,
 * READ ONLY, OFFLINE, INACTIVE, NOT WP and conventional zones).
 */

static const struct wp_case cases[] = {
	{ "SWR wp == start", ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_EMPTY,
	  ALERT_START, ALERT_LEN, ALERT_START, 0 },
	{ "SWR wp inside zone", ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_IMP_OPEN,
	  ALERT_START, ALERT_LEN, ALERT_START + 0x1000, 0 },
	{ "SWR wp == zone end", ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_IMP_OPEN,
	  ALERT_START, ALERT_LEN, ALERT_START + ALERT_LEN, 0 },
	{ "SWR wp 8 past end (FWVAL-4471)", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_IMP_OPEN, ALERT_START, ALERT_LEN,
	  ALERT_START + ALERT_LEN + 8, -EIO },
	{ "SWR wp before start", ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_CLOSED,
	  ALERT_START, ALERT_LEN, ALERT_START - 1, -EIO },
	{ "SWP wp past end", ZBC_ZT_SEQUENTIAL_PREF, ZBC_ZC_EXP_OPEN,
	  ALERT_START, ALERT_LEN, ALERT_START + ALERT_LEN + 1, -EIO },
	{ "SOBR wp past end", ZBC_ZT_SEQ_OR_BEF_REQ, ZBC_ZC_IMP_OPEN,
	  ALERT_START, ALERT_LEN, ALERT_START + ALERT_LEN + 8, -EIO },
	{ "SWR wp overflow", ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_IMP_OPEN,
	  UINT64_MAX - 0x10, 0x80000, 0x10, -EIO },
	{ "SWR FULL, invalid wp ignored", ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_FULL,
	  ALERT_START, ALERT_LEN, (uint64_t)-1, 0 },
	{ "SWR READ ONLY, invalid wp ignored", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_RDONLY, ALERT_START, ALERT_LEN, (uint64_t)-1, 0 },
	{ "SWR OFFLINE, invalid wp ignored", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_OFFLINE, ALERT_START, ALERT_LEN, (uint64_t)-1, 0 },
	{ "SWR INACTIVE, invalid wp ignored", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_INACTIVE, ALERT_START, ALERT_LEN, (uint64_t)-1, 0 },
	{ "SWR NOT WP, invalid wp ignored", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_NOT_WP, ALERT_START, ALERT_LEN, (uint64_t)-1, 0 },
	{ "Conventional zone ignored", ZBC_ZT_CONVENTIONAL, ZBC_ZC_NOT_WP,
	  0, ALERT_LEN, (uint64_t)-1, 0 },
};

/**
 * @brief Run all write pointer check test cases
 *
 * Calls zbc_zone_check_wp() on a zone built from each entry of @c cases
 * using a synthetic device handle, and prints a PASS or FAIL line for
 * each case followed by a summary.
 *
 * @return 0 if all test cases passed, 1 otherwise.
 */
int main(void)
{
	struct zbc_device dev = { .zbd_filename = "synthetic" };
	struct zbc_zone zone;
	unsigned int i, failed = 0;
	int ret;

	zbc_set_log_level("error");

	for (i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
		zone.zbz_type = cases[i].type;
		zone.zbz_condition = cases[i].cond;
		zone.zbz_attributes = 0;
		zone.zbz_start = cases[i].start;
		zone.zbz_length = cases[i].length;
		zone.zbz_write_pointer = cases[i].wp;

		ret = zbc_zone_check_wp(&dev, &zone, i);
		printf("[%s] %s: got %d, expected %d\n",
		       ret == cases[i].expected ? "PASS" : "FAIL",
		       cases[i].name, ret, cases[i].expected);
		if (ret != cases[i].expected)
			failed++;
	}

	printf("%u/%zu cases passed\n",
	       (unsigned int)(sizeof(cases) / sizeof(cases[0])) - failed,
	       sizeof(cases) / sizeof(cases[0]));

	return failed ? 1 : 0;
}
