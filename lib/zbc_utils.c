// SPDX-License-Identifier: BSD-2-Clause
// SPDX-License-Identifier: LGPL-3.0-or-later
/*
 * This file is part of libzbc.
 *
 * Copyright (C) 2021, Western Digital. All rights reserved.
 *
 * Author: Damien Le Moal (damien.lemoal@wdc.com)
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <libgen.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#include "zbc.h"
#include "zbc_utils.h"

/**
 * Get a sysfs file integer value.
 */
int zbc_get_sysfs_val_ull(const char *sysfs_path, unsigned long long *val)
{
	FILE *f;
	int ret;

	f = fopen(sysfs_path, "r");
	if (!f)
		return -1;

	ret = fscanf(f, "%llu", val);

	fclose(f);
	if (ret != 1)
		return 0;

	return 0;
}

static int zbc_read_str(FILE *file, char *buf, int buf_size)
{
	int len;

	memset(buf, 0, buf_size);

	if (!fgets(buf, buf_size, file))
		return 0;

	/* Clear any trailing white space, tab and carriage return */
	len = strlen(buf) - 1;
	while (len > 0) {
		if (buf[len] == ' ' ||
		    buf[len] == '\t' ||
		    buf[len] == '\r' ||
		    buf[len] == '\n') {
			buf[len] = '\0';
			len--;
		} else {
			break;
		}
	}

	return len;
}

/**
 * Get a sysfs file string value.
 */
int zbc_get_sysfs_val_str(const char *sysfs_path, char *str,
			  int max_len)
{
	FILE *f;
	int ret;

	f = fopen(sysfs_path, "r");
	if (!f)
		return -1;

	ret = zbc_read_str(f, str, max_len);

	fclose(f);

	if (!ret)
		return -1;

	return 0;
}

static char *zbc_sysfs_path(char *dev_name,
			    const char *group, const char *attr)
{
	char *path;
	int ret;

	ret = asprintf(&path, "/sys/block/%s/%s/%s",
		       basename(dev_name), group, attr);
	if (ret < 0)
		return NULL;

	return path;
}

static int zbc_get_sysfs_group_val_ull(char *dev_name,
				       const char *group, const char *attr,
				       unsigned long long *val)
{
	char *path = zbc_sysfs_path(dev_name, group, attr);
	int ret = -1;

	if (path) {
		ret = zbc_get_sysfs_val_ull(path, val);
		free(path);
	}

	return ret;
}

static int zbc_get_sysfs_group_val_str(char *dev_name,
				       const char *group, const char *attr,
				       char *str, int max_len)
{
	char *path = zbc_sysfs_path(dev_name, group, attr);
	int ret = -1;

	if (path) {
		ret = zbc_get_sysfs_val_str(path, str, max_len);
		free(path);
	}

	return ret;
}

/**
 * Get a block device sysfs queue integer attribute.
 */
int zbc_get_sysfs_queue_val_ull(char *dev_name, const char *attr,
				unsigned long long *val)
{
	return zbc_get_sysfs_group_val_ull(dev_name, "queue", attr, val);
}

/**
 * Get a block device sysfs queue string attribute.
 */
int zbc_get_sysfs_queue_str(char *dev_name, const char *attr,
			    char *str, int max_len)
{
	return zbc_get_sysfs_group_val_str(dev_name, "queue", attr,
					   str, max_len);
}

/**
 * Get a block device sysfs device integer attribute.
 */
int zbc_get_sysfs_device_val_ull(char *dev_name, const char *attr,
				 unsigned long long *val)
{
	return zbc_get_sysfs_group_val_ull(dev_name, "device", attr, val);
}

/**
 * Get a block device sysfs device string attribute.
 */
int zbc_get_sysfs_device_str(char *dev_name, const char *attr,
			     char *str, int max_len)
{
	return zbc_get_sysfs_group_val_str(dev_name, "device", attr,
					   str, max_len);
}

/**
 * @brief Check that a reported zone write pointer lies within the zone.
 * @param[in] dev	Device the zone was reported by
 * @param[in] idx	Index of the zone in the REPORT ZONES reply
 * @param[in] zone	Zone parsed from a zone descriptor
 *
 * For sequential and SOBR zones with a valid write pointer, check that
 * zbz_start <= zbz_write_pointer <= zbz_start + zbz_length.
 * The write pointer of zones that are FULL, READ ONLY, OFFLINE, INACTIVE
 * or NOT WP is invalid and not checked.
 *
 * @return 0 if the write pointer is valid or not checked, -EIO otherwise.
 */
int zbc_zone_check_wp(struct zbc_device *dev, unsigned int idx,
		      struct zbc_zone *zone)
{
	uint64_t start = zone->zbz_start;
	uint64_t len = zone->zbz_length;
	uint64_t wp = zone->zbz_write_pointer;

	if (!zbc_zone_sequential(zone) && !zbc_zone_sobr(zone))
		return 0;

	if (zbc_zone_full(zone) || zbc_zone_rdonly(zone) ||
	    zbc_zone_offline(zone) || zbc_zone_inactive(zone) ||
	    zbc_zone_not_wp(zone))
		return 0;

	if (wp >= start && wp - start <= len)
		return 0;

	zbc_error("%s: REPORT ZONES zone %u (start 0x%llx, length 0x%llx): "
		  "write pointer 0x%llx out of zone range\n",
		  dev->zbd_filename, idx,
		  (unsigned long long)start,
		  (unsigned long long)len,
		  (unsigned long long)wp);

	return -EIO;
}
