// SPDX-License-Identifier: BSD-2-Clause
// SPDX-License-Identifier: LGPL-3.0-or-later
/*
 * This file is part of libzbc.
 *
 * Host-runnable check of the REPORT ZONES write pointer validation
 * (zbc_zone_check_wp()) using synthetic zone descriptors.
 * No zoned device is needed.
 */

/**
 * @file zbc_test_wp_check.c
 * @brief Unit test for zbc_zone_check_wp().
 *
 * Feeds synthetic zone descriptors built from the FWVAL-4471 zone 1873
 * geometry to zbc_zone_check_wp() and compares the result of each case
 * against the expected return value. Runs under "make check".
 */
#include <stdio.h>
#include <errno.h>

#include "zbc.h"
#include "zbc_utils.h"

/**
 * @brief Library log level, defined here since lib/zbc.c is not linked.
 *
 * Set to ZBC_LOG_ERROR so the out of range write pointer errors reported
 * by zbc_zone_check_wp() are printed.
 */
int zbc_log_level = ZBC_LOG_ERROR;

/* Zone 1873 from FWVAL-4471 */
/** @brief Start sector of the test zone (zone 1873 in FWVAL-4471). */
#define Z_START	0x3A880000ULL
/** @brief Length in sectors of the test zone. */
#define Z_LEN	0x80000ULL
/** @brief End sector of the test zone (first sector after the zone). */
#define Z_END	(Z_START + Z_LEN)

/**
 * @brief Write pointer check test case.
 */
struct wp_case {
	const char	*name;		/**< Test case description */
	uint8_t		type;		/**< Zone type (enum zbc_zone_type) */
	uint8_t		cond;		/**< Zone condition
					     (enum zbc_zone_condition) */
	uint64_t	start;		/**< Zone start sector */
	uint64_t	len;		/**< Zone length in sectors */
	uint64_t	wp;		/**< Reported write pointer sector */
	int		expected;	/**< Expected zbc_zone_check_wp()
					     return value */
};

/**
 * @brief Test cases: valid, out of range and unchecked write pointers.
 */
static const struct wp_case cases[] = {
	{ "SWR imp open, wp inside zone", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_IMP_OPEN, Z_START, Z_LEN, Z_START + 0x1000, 0 },
	{ "SWR empty, wp == zone start", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_EMPTY, Z_START, Z_LEN, Z_START, 0 },
	{ "SWR closed, wp == zone end", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_CLOSED, Z_START, Z_LEN, Z_END, 0 },
	{ "SWR imp open, wp 8 sectors past end (FWVAL-4471)",
	  ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_IMP_OPEN, Z_START, Z_LEN,
	  Z_END + 8, -EIO },
	{ "SWR exp open, wp 1 sector past end", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_EXP_OPEN, Z_START, Z_LEN, Z_END + 1, -EIO },
	{ "SWR imp open, wp before zone start", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_IMP_OPEN, Z_START, Z_LEN, Z_START - 8, -EIO },
	{ "SWP imp open, wp past end", ZBC_ZT_SEQUENTIAL_PREF,
	  ZBC_ZC_IMP_OPEN, Z_START, Z_LEN, Z_END + 8, -EIO },
	{ "SOBR closed, wp past end", ZBC_ZT_SEQ_OR_BEF_REQ,
	  ZBC_ZC_CLOSED, Z_START, Z_LEN, Z_END + 8, -EIO },
	{ "SWR imp open, wp ~0 (no wrap-around)", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_IMP_OPEN, Z_START, Z_LEN, ~0ULL, -EIO },
	{ "SWR full, wp invalid per spec", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_FULL, Z_START, Z_LEN, Z_END + 8, 0 },
	{ "SWR read only, wp invalid per spec", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_RDONLY, Z_START, Z_LEN, ~0ULL, 0 },
	{ "SWR offline, wp invalid per spec", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_OFFLINE, Z_START, Z_LEN, ~0ULL, 0 },
	{ "SWR inactive, wp invalid per spec", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_INACTIVE, Z_START, Z_LEN, ~0ULL, 0 },
	{ "SWR not wp, wp invalid per spec", ZBC_ZT_SEQUENTIAL_REQ,
	  ZBC_ZC_NOT_WP, Z_START, Z_LEN, ~0ULL, 0 },
	{ "conventional, wp not checked", ZBC_ZT_CONVENTIONAL,
	  ZBC_ZC_NOT_WP, Z_START, Z_LEN, (uint64_t)-1, 0 },
};

/**
 * @brief Run all write pointer check test cases.
 *
 * Each case is reported as PASS or FAIL on stdout, followed by a summary.
 *
 * @return 0 if all cases passed, 1 otherwise.
 */
int main(void)
{
	char name[] = "synthetic";
	struct zbc_device dev = { .zbd_filename = name };
	struct zbc_zone zone;
	unsigned int i, failed = 0;
	int ret;

	for (i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
		const struct wp_case *c = &cases[i];

		zone = (struct zbc_zone) {
			.zbz_type = c->type,
			.zbz_condition = c->cond,
			.zbz_start = c->start,
			.zbz_length = c->len,
			.zbz_write_pointer = c->wp,
		};

		ret = zbc_zone_check_wp(&dev, 1873, &zone);
		printf("%s: %s (got %d, expected %d)\n",
		       ret == c->expected ? "PASS" : "FAIL",
		       c->name, ret, c->expected);
		if (ret != c->expected)
			failed++;
	}

	printf("%u/%zu passed\n",
	       (unsigned int)(sizeof(cases) / sizeof(cases[0])) - failed,
	       sizeof(cases) / sizeof(cases[0]));

	return failed ? 1 : 0;
}
