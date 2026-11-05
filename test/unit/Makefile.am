# SPDX-License-Identifier: BSD-2-Clause
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Copyright (c) 2020 Western Digital Corporation or its affiliates.

AM_CFLAGS = \
	-Wall -Wextra -Wno-unused-parameter \
	-I$(top_srcdir)/include \
	-I$(top_builddir)/include \
	-I$(top_srcdir)/lib

check_PROGRAMS = zbc_test_wp_check
zbc_test_wp_check_SOURCES = zbc_test_wp_check.c $(top_srcdir)/lib/zbc_utils.c

TESTS = $(check_PROGRAMS)
