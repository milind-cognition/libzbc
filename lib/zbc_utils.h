/* SPDX-License-Identifier: BSD-2-Clause */
/* SPDX-License-Identifier: LGPL-3.0-or-later */
/*
 * This file is part of libzbc.
 *
 * Copyright (C) 2021, Western Digital or its Affiliates. All rights reserved.
 *
 * Author: Damien Le Moal (damien.lemoal@wdc.com)
 */
/**
 * @file zbc_utils.h
 * @brief Internal libzbc utility function declarations.
 */
#ifndef __LIBZBC_UTILS_H__
#define __LIBZBC_UTILS_H__

/**
 * Get a sysfs file integer value.
 */
int zbc_get_sysfs_val_ull(const char *sysfs_path, unsigned long long *val);

/**
 * Get a sysfs file string value.
 */
int zbc_get_sysfs_val_str(const char *sysfs_path, char *str, int max_len);


/**
 * Get a block device sysfs queue integer attribute.
 */
int zbc_get_sysfs_queue_val_ull(char *dev_name, const char *attr,
				unsigned long long *val);

/**
 * Get a block device sysfs queue string attribute.
 */
int zbc_get_sysfs_queue_str(char *dev_name, const char *attr,
			    char *str, int max_len);

/**
 * Get a block device sysfs device integer attribute.
 */
int zbc_get_sysfs_device_val_ull(char *dev_name, const char *attr,
				 unsigned long long *val);

/**
 * Get a block device sysfs device string attribute.
 */
int zbc_get_sysfs_device_str(char *dev_name, const char *attr,
			     char *str, int max_len);

struct zbc_device;
struct zbc_zone;

/**
 * Check that a reported zone write pointer lies within the zone.
 *
 * @brief Validate the write pointer of a zone parsed from REPORT ZONES.
 *
 * Only sequential and SOBR zones with a valid write pointer are checked.
 * A write pointer equal to the zone end (zbz_start + zbz_length) is valid.
 * Parameters and return value are documented with the definition in
 * zbc_utils.c.
 */
int zbc_zone_check_wp(struct zbc_device *dev, unsigned int idx,
		      struct zbc_zone *zone);

#endif /* __LIBZBC_UTILS_H__ */

