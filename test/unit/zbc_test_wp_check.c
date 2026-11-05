// SPDX-License-Identifier: BSD-2-Clause
// SPDX-License-Identifier: LGPL-3.0-or-later
/**
 * @file zbc_test_wp_check.c
 * @brief Unit test for the REPORT ZONES write pointer bounds check.
 *
 * This file is part of libzbc.
 *
 * Copyright (c) 2020 Western Digital Corporation or its affiliates.
 *
 * Host-runnable regression test for zbc_zone_check_wp(): feed synthetic
 * zone descriptors to the REPORT ZONES write pointer check. No zoned
 * device is needed.
 */
#include "zbc.h"

/**
 * @brief Library log level, defined here as the test does not link libzbc.
 */
int zbc_log_level = ZBC_LOG_ERROR;

/* Zone 1873 from FWVAL-4471: start 0x3A880000, length 0x80000 sectors */

/**
 * @brief Start sector (512B units) of the test zone.
 */
#define TZ_START	0x3A880000ULL

/**
 * @brief Length in sectors (512B units) of the test zone.
 */
#define TZ_LEN		0x80000ULL

/**
 * @brief Write pointer check test case.
 */
struct wp_test {
	const char		*name;		/**< Test case description */
	enum zbc_zone_type	type;		/**< Zone type */
	enum zbc_zone_condition	cond;		/**< Zone condition */
	uint64_t		wp;		/**< Zone write pointer (512B sectors) */
	int			expected;	/**< Expected zbc_zone_check_wp() return */
};

/**
 * @brief Test cases, all using the TZ_START / TZ_LEN zone geometry.
 */
static struct wp_test tests[] = {
	{ "SWR empty, wp == start",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_EMPTY, TZ_START, 0 },
	{ "SWR imp open, wp mid zone",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_IMP_OPEN, TZ_START + 0x1000, 0 },
	{ "SWR closed, wp == zone end",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_CLOSED, TZ_START + TZ_LEN, 0 },
	{ "SWR imp open, wp 8 sectors past end (FWVAL-4471)",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_IMP_OPEN, TZ_START + TZ_LEN + 8,
	  -EIO },
	{ "SWR exp open, wp before start",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_EXP_OPEN, TZ_START - 1, -EIO },
	{ "SWR imp open, wp near UINT64_MAX",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_IMP_OPEN, (uint64_t)-2, -EIO },
	{ "SWP closed, wp past end",
	  ZBC_ZT_SEQUENTIAL_PREF, ZBC_ZC_CLOSED, TZ_START + TZ_LEN + 1, -EIO },
	{ "SOBR imp open, wp past end",
	  ZBC_ZT_SEQ_OR_BEF_REQ, ZBC_ZC_IMP_OPEN, TZ_START + TZ_LEN + 8,
	  -EIO },
	{ "SOBR empty, wp == start",
	  ZBC_ZT_SEQ_OR_BEF_REQ, ZBC_ZC_EMPTY, TZ_START, 0 },
	{ "SWR full, wp invalid (ignored)",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_FULL, (uint64_t)-1, 0 },
	{ "SWR read only, wp invalid (ignored)",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_RDONLY, (uint64_t)-1, 0 },
	{ "SWR offline, wp invalid (ignored)",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_OFFLINE, (uint64_t)-1, 0 },
	{ "SWR inactive, wp invalid (ignored)",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_INACTIVE, (uint64_t)-1, 0 },
	{ "SWR not wp, wp invalid (ignored)",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_NOT_WP, (uint64_t)-1, 0 },
	{ "Conventional, no wp (ignored)",
	  ZBC_ZT_CONVENTIONAL, ZBC_ZC_NOT_WP, (uint64_t)-1, 0 },
};

/**
 * @brief Run all write pointer check test cases.
 *
 * @return 0 if all test cases pass, 1 otherwise.
 */
int main(void)
{
	unsigned int i, nr_tests = sizeof(tests) / sizeof(tests[0]);
	unsigned int failed = 0;
	struct zbc_zone zone;
	int ret;

	for (i = 0; i < nr_tests; i++) {
		memset(&zone, 0, sizeof(zone));
		zone.zbz_type = tests[i].type;
		zone.zbz_condition = tests[i].cond;
		zone.zbz_start = TZ_START;
		zone.zbz_length = TZ_LEN;
		zone.zbz_write_pointer = tests[i].wp;

		ret = zbc_zone_check_wp("test", 1873, &zone);
		if (ret != tests[i].expected) {
			printf("FAIL: %s: got %d, expected %d\n",
			       tests[i].name, ret, tests[i].expected);
			failed++;
		} else {
			printf("PASS: %s\n", tests[i].name);
		}
	}

	printf("%u/%u tests passed\n", nr_tests - failed, nr_tests);

	return failed ? 1 : 0;
}
