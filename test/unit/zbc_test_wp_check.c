// SPDX-License-Identifier: BSD-2-Clause
// SPDX-License-Identifier: LGPL-3.0-or-later
/**
 * @file zbc_test_wp_check.c
 * @brief Host-runnable regression check for zbc_zone_check_wp().
 *
 * This file is part of libzbc.
 *
 * Copyright (C) 2020, Western Digital. All rights reserved.
 *
 * Host-runnable regression check for zbc_zone_check_wp(): feeds synthetic
 * zone descriptors to the REPORT ZONES write pointer bounds check. No zoned
 * device is needed.
 */
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

#include "zbc.h"
#include "zbc_utils.h"

/**
 * @brief Library log level, defined here since the test links the library
 *        sources directly. Only errors are printed.
 */
int zbc_log_level = ZBC_LOG_ERROR;

/* Zone 1873 from FWVAL-4471: start 0x3A880000, length 0x80000 */
/** @brief Start sector of the test zone (zone 1873 from FWVAL-4471). */
#define ZSTART	0x3A880000ULL
/** @brief Length in sectors of the test zone (zone 1873 from FWVAL-4471). */
#define ZLEN	0x80000ULL

/**
 * @brief A single write pointer check test case.
 */
struct wp_test {
	const char	*name;		/**< Test case description */
	uint8_t		type;		/**< Zone type (enum zbc_zone_type) */
	uint8_t		cond;		/**< Zone condition (enum zbc_zone_condition) */
	uint64_t	start;		/**< Zone start sector */
	uint64_t	len;		/**< Zone length in sectors */
	uint64_t	wp;		/**< Zone write pointer sector */
	int		expected;	/**< Expected zbc_zone_check_wp() result */
};

/**
 * @brief Test cases: valid, out-of-range and unchecked write pointers.
 */
static struct wp_test tests[] = {
	{ "valid wp (empty, wp == start)", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_EMPTY, ZSTART, ZLEN, ZSTART, 0 },
	{ "valid wp (imp open, mid-zone)", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_IMP_OPEN, ZSTART, ZLEN, ZSTART + 0x1000, 0 },
	{ "wp == zone end", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_IMP_OPEN, ZSTART, ZLEN, ZSTART + ZLEN, 0 },
	{ "wp 8 sectors past end (FWVAL-4471)", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_IMP_OPEN, ZSTART, ZLEN, ZSTART + ZLEN + 8, -EIO },
	{ "wp 1 sector before start", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_CLOSED, ZSTART, ZLEN, ZSTART - 1, -EIO },
	{ "wp past end, seq pref", ZBC_ZT_SEQUENTIAL_PREF,
	  ZBC_ZC_EXP_OPEN, ZSTART, ZLEN, ZSTART + ZLEN + 8, -EIO },
	{ "wp past end, SOBR", ZBC_ZT_SEQ_OR_BEF_REQ,
	  ZBC_ZC_IMP_OPEN, ZSTART, ZLEN, ZSTART + ZLEN + 8, -EIO },
	{ "wp overflow (start + len wraps)", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_IMP_OPEN, UINT64_MAX - 0x10, ZLEN, 0x10, -EIO },
	{ "full zone, wp ignored", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_FULL, ZSTART, ZLEN, ZSTART + ZLEN + 8, 0 },
	{ "read-only zone, wp ignored", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_RDONLY, ZSTART, ZLEN, (uint64_t)-1, 0 },
	{ "offline zone, wp ignored", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_OFFLINE, ZSTART, ZLEN, (uint64_t)-1, 0 },
	{ "inactive zone, wp ignored", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_INACTIVE, ZSTART, ZLEN, (uint64_t)-1, 0 },
	{ "not wp zone, wp ignored", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_NOT_WP, ZSTART, ZLEN, (uint64_t)-1, 0 },
	{ "conventional zone, wp ignored", ZBC_ZT_CONVENTIONAL,
	  ZBC_ZC_NOT_WP, ZSTART, ZLEN, (uint64_t)-1, 0 },
};

/**
 * @brief Run all test cases against zbc_zone_check_wp().
 *
 * Each case is printed as PASS or FAIL, followed by a summary line.
 *
 * @return EXIT_SUCCESS if all test cases pass, EXIT_FAILURE otherwise.
 */
int main(void)
{
	struct zbc_device dev = { .zbd_filename = "synthetic" };
	unsigned int i, nr_fail = 0;
	struct zbc_zone zone;
	int ret;

	for (i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
		struct wp_test *t = &tests[i];

		zone = (struct zbc_zone) {
			.zbz_type = t->type,
			.zbz_condition = t->cond,
			.zbz_start = t->start,
			.zbz_length = t->len,
			.zbz_write_pointer = t->wp,
		};

		ret = zbc_zone_check_wp(&dev, &zone, i);
		if (ret != t->expected) {
			printf("FAIL: %s: got %d, expected %d\n",
			       t->name, ret, t->expected);
			nr_fail++;
		} else {
			printf("PASS: %s\n", t->name);
		}
	}

	printf("%u / %zu tests passed\n",
	       (unsigned int)(sizeof(tests) / sizeof(tests[0])) - nr_fail,
	       sizeof(tests) / sizeof(tests[0]));

	return nr_fail ? EXIT_FAILURE : EXIT_SUCCESS;
}
