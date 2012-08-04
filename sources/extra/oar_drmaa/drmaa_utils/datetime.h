/* $Id: datetime.h 533 2007-12-22 15:25:42Z lukasz $ */
/*
 *  FedStage DRMAA for PBS Pro
 *  Copyright (C) 2006-2007  Fedstage Systems Inc.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * @file datetime.h
 * DRMAA date/time parser.
 */

#ifndef __DRMAA__DATETIME_H
#define __DRMAA__DATETIME_H

#include <drmaa_utils/common.h>

/**
 * @defgroup datetime  DRMAA date/time parser.
 *
 * It parses date/time string in format of
 * drmaa_start_time and drmaa_deadline_time attributes.
 * In other words it accepts time in following format:
 *
 * <tt>  [[[[CC]YY/]MM/]DD] hh:mm[:ss] [{-|+}UU:uu]  </tt>
 *
 * where
 *    CC is the first two digits of the year (century-1),
 *    YY is the last two digits of the year,
 *    MM is the two digits of the month [01,12],
 *    DD is the two-digit day of the month [01,31],
 *    hh is the two-digit hour of the day [00,23],
 *    mm is the two-digit minute of the day [00,59],
 *    ss is the two-digit second of the minute [00,61],
 *    UU is the two-digit hours since (before) UTC,
 *    uu is the two-digit minutes since (before) UTC.
 */
/* @{ */

typedef struct drmaa_datetime_s drmaa_datetime_t;

/**
 * Parses date/time.
 * When string is invalid syntax error is raised and result is unspecified.
 * @param string  Textual representation to date/time.
 * @param err     Error context.
 * @return Absolute time according to string.
 */
time_t drmaa_parse_datetime( const char *string, drmaa_err_ctx_t *err );

/**
 * Guess local timezone for given UTC time
 * @param t UTC timestamp (time from epoch).
 * @return Numbef of seconds east (since/before) UTC.  For example in CET
 * +3600 is returned (UTC + 1 hour).
 */
long drmaa_timezone( time_t t );

/**
 * Fill drmaa_datetime_t structure according to Unix timestamp.
 * @param dt   Will be filled with local time representation of filler.
 * @param filler  Seconds since epoch.
 */
void drmaa_fill_datetime( drmaa_datetime_t *dt, time_t filler );

/** Makes UTC datetime from (possibly not absolute) drmaa_datetime_t. */
time_t drmaa_mktime( const drmaa_datetime_t *dt );

enum{
	YEAR         = 1<<0,
	MONTH        = 1<<1,
	DAY          = 1<<2,
	HOUR         = 1<<3,
	MINUTE       = 1<<4,
	SECOND       = 1<<5,
	TZ_DELTA     = 1<<6,
	DATETIME_ALL = YEAR | MONTH | DAY | HOUR | MINUTE | SECOND | TZ_DELTA
};

/** Intermediate result of parsing date/time string (may be incomplete). */
struct drmaa_datetime_s {
	unsigned mask;  /**< Bitset of fields which were set. */
	int year;       /**< Year. */
	int month;      /**< Month. */
	int day;        /**< Day. */
	int hour;       /**< Hour. */
	int minute;     /**< Minute. */
	int second;     /**< Second. */
	long tz_delta;  /**< Timezone; Number of seconds ahead of UTC. */
};
/* @} */

#endif /* __DRMAA__DATETIME_H */

