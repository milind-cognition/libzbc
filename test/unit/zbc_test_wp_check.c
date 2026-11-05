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
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>

#include "zbc.h"

struct wp_case {
	const char		*name;
	enum zbc_zone_type	type;
	enum zbc_zone_condition	cond;
	uint64_t		start;
	uint64_t		length;
	uint64_t		wp;
	int			expected;
};

/* FWVAL-4471: zone 1873, SWR, IMP_OPEN */
#define ALERT_START	0x3A880000ULL
#define ALERT_LEN	0x80000ULL

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
