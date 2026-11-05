// SPDX-License-Identifier: BSD-2-Clause
// SPDX-License-Identifier: LGPL-3.0-or-later
/*
 * This file is part of libzbc.
 *
 * Copyright (C) 2020, Western Digital. All rights reserved.
 *
 * Host-runnable check of zbc_zone_check_wp() using synthetic zone
 * descriptors. No zoned device is needed.
 */
#include <unistd.h>

#include "zbc.h"

int zbc_log_level = ZBC_LOG_ERROR;

/* Zone 1873 geometry from FWVAL-4471 */
#define ZSTART	0x3A880000ULL
#define ZLEN	0x80000ULL
#define ZEND	(ZSTART + ZLEN)

struct wp_case {
	const char	*name;
	uint8_t		type;
	uint8_t		cond;
	uint64_t	wp;
	int		expected;
};

static const struct wp_case cases[] = {
	{ "SWR wp at zone start",	ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_EMPTY,
	  ZSTART, 0 },
	{ "SWR wp inside zone",		ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_IMP_OPEN,
	  ZSTART + 0x1000, 0 },
	{ "SWR wp == zone end",		ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_CLOSED,
	  ZEND, 0 },
	{ "SWR wp 8 past end (alert)",	ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_IMP_OPEN,
	  ZEND + 8, -EIO },
	{ "SWR wp before start",	ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_EXP_OPEN,
	  ZSTART - 8, -EIO },
	{ "SWR wp all ones (overflow)",	ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_IMP_OPEN,
	  UINT64_MAX, -EIO },
	{ "SWP wp past end",		ZBC_ZT_SEQUENTIAL_PREF, ZBC_ZC_IMP_OPEN,
	  ZEND + 1, -EIO },
	{ "SOBR wp past end",		ZBC_ZT_SEQ_OR_BEF_REQ, ZBC_ZC_IMP_OPEN,
	  ZEND + 1, -EIO },
	{ "SOBR wp inside zone",	ZBC_ZT_SEQ_OR_BEF_REQ, ZBC_ZC_CLOSED,
	  ZSTART + 8, 0 },
	{ "SWR FULL skipped",		ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_FULL,
	  ZEND + 8, 0 },
	{ "SWR RDONLY skipped",		ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_RDONLY,
	  ZEND + 8, 0 },
	{ "SWR OFFLINE skipped",	ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_OFFLINE,
	  ZEND + 8, 0 },
	{ "SWR INACTIVE skipped",	ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_INACTIVE,
	  ZEND + 8, 0 },
	{ "SWR NOT_WP skipped",		ZBC_ZT_SEQUENTIAL_REQ, ZBC_ZC_NOT_WP,
	  ZEND + 8, 0 },
	{ "CONV zone skipped",		ZBC_ZT_CONVENTIONAL, ZBC_ZC_NOT_WP,
	  (uint64_t)-1, 0 },
};

int main(void)
{
	struct zbc_device dev;
	struct zbc_zone zone;
	unsigned int i, nr_cases = sizeof(cases) / sizeof(cases[0]);
	unsigned int failed = 0;
	int ret;

	memset(&dev, 0, sizeof(dev));
	dev.zbd_filename = "synthetic";

	for (i = 0; i < nr_cases; i++) {
		memset(&zone, 0, sizeof(zone));
		zone.zbz_type = cases[i].type;
		zone.zbz_condition = cases[i].cond;
		zone.zbz_start = ZSTART;
		zone.zbz_length = ZLEN;
		zone.zbz_write_pointer = cases[i].wp;

		ret = zbc_zone_check_wp(&dev, 1873, &zone);
		if (ret != cases[i].expected) {
			printf("FAIL: %s: got %d, expected %d\n",
			       cases[i].name, ret, cases[i].expected);
			failed++;
		} else {
			printf("ok:   %s\n", cases[i].name);
		}
	}

	printf("%u/%u cases passed\n", nr_cases - failed, nr_cases);

	return failed ? 1 : 0;
}
