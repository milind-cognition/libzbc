// SPDX-License-Identifier: BSD-2-Clause
// SPDX-License-Identifier: LGPL-3.0-or-later
/*
 * This file is part of libzbc.
 *
 * Host-runnable check of the REPORT ZONES write pointer validation
 * (zbc_zone_check_wp()) using synthetic zone descriptors.
 * No zoned device is needed.
 */
#include <stdio.h>
#include <errno.h>

#include "zbc.h"
#include "zbc_utils.h"

int zbc_log_level = ZBC_LOG_ERROR;

/* Zone 1873 from FWVAL-4471 */
#define Z_START	0x3A880000ULL
#define Z_LEN	0x80000ULL
#define Z_END	(Z_START + Z_LEN)

struct wp_case {
	const char	*name;
	uint8_t		type;
	uint8_t		cond;
	uint64_t	start;
	uint64_t	len;
	uint64_t	wp;
	int		expected;
};

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
