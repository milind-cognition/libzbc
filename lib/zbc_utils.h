/* SPDX-License-Identifier: BSD-2-Clause */
/* SPDX-License-Identifier: LGPL-3.0-or-later */
/*
 * This file is part of libzbc.
 *
 * Copyright (C) 2021, Western Digital or its Affiliates. All rights reserved.
 *
 * Author: Damien Le Moal (damien.lemoal@wdc.com)
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

/** @brief Opaque device handle (forward declaration). */
struct zbc_device;
/** @brief Zone descriptor (forward declaration, defined in libzbc/zbc.h). */
struct zbc_zone;

/**
 * Check that a zone write pointer is within the zone bounds.
 *
 * @brief Check that a zone write pointer is within the zone bounds.
 *
 * For sequential and SOBR zones with a condition for which the write pointer
 * is valid, check that the write pointer lies within
 * [zone start, zone start + zone length].
 *
 * @param[in] dev	Device the zone descriptor was reported by
 * @param[in] zone	Zone descriptor to check
 * @param[in] idx	Index of the zone descriptor in the REPORT ZONES reply
 *
 * @return 0 if the write pointer is valid or not checked, -EIO otherwise.
 */
int zbc_zone_check_wp(struct zbc_device *dev, struct zbc_zone *zone,
		      unsigned int idx);

#endif /* __LIBZBC_UTILS_H__ */

