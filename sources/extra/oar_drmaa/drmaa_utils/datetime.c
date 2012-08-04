/* $Id: datetime.c 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file datetime.c
 * DRMAA date/time parser.
 */

#include <ctype.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <drmaa_utils/compat.h>
#include <drmaa_utils/datetime_impl.h>
#include <drmaa_utils/datetime_tab.h>


void
drmaa_print_datetime( const drmaa_datetime_t *dt, char *s, size_t len )
{
	char mask[] = "YMDhmsZ";
	char sign = '+';
	long tz_delta = dt->tz_delta;
	unsigned d_hour, d_min, d_sec;
	unsigned m;
	if( tz_delta < 0 )
	 {
		tz_delta = -tz_delta;
		sign = '-';
	 }
	d_sec = tz_delta%60;  tz_delta/=60;
	d_min = tz_delta%60;  tz_delta/=60;
	d_hour = tz_delta;
	for( m=0;  m<7;  m++ )
	 {
		if( !(dt->mask & (1<<m)) )
			mask[m]='-';
	 }
	snprintf( s, len, "%04d/%02d/%02d %02d:%02d:%02d %c%02d:%02d:%02d [%s]",
			dt->year, dt->month, dt->day,
			dt->hour, dt->minute, dt->second,
			sign, d_hour, d_min, d_sec,
			mask
			);
}


long
drmaa_timezone( time_t t )
{
	struct tm utc_tm;
	struct tm local_tm;
	int d;
	long result;

	gmtime_r( &t, &utc_tm );
	localtime_r( &t, &local_tm );
	if( local_tm.tm_year != utc_tm.tm_year )
		d = local_tm.tm_year - utc_tm.tm_year;
	else if( local_tm.tm_mon != utc_tm.tm_mon )
		d = local_tm.tm_mon - utc_tm.tm_mon;
	else if( local_tm.tm_mday != utc_tm.tm_mday )
		d = local_tm.tm_mday - utc_tm.tm_mday;
	else
		d = 0;
	result =
		( (local_tm.tm_hour-utc_tm.tm_hour)*60
		+ local_tm.tm_min-utc_tm.tm_min )*60
		+ local_tm.tm_sec-utc_tm.tm_sec;
	if( d > 0 )
		result += 24*3600;
	else if( d < 0 )
		result -= 24*3600;
	return result;
}


void
drmaa_fill_datetime( drmaa_datetime_t *dt, time_t filler )
{
	unsigned unfilled = ~dt->mask;
	struct tm t;

#ifdef DRMAA_DEBUG
	char dbg[256];
	drmaa_print_datetime( dt, dbg, sizeof(dbg) );
	DEBUG(( "-> drmaa_fill_datetime( dt={%s}, filler=%u )",
				dbg, (unsigned)filler ));
#endif

#ifdef __GNUC__
	/*
	 * glibc have tm_gmtoff field in tm struct
	 * which is number of second east from UTC
	 */
	if( unfilled & TZ_DELTA )
	 {
		localtime_r( &filler, &t );
		dt->tz_delta = t.tm_gmtoff;
	 }
	else
	 {
		filler += dt->tz_delta;
		gmtime_r( &filler, &t );
	 }
#else /* ! __GNUC__ */
	if( unfilled & TZ_DELTA )
		dt->tz_delta = drmaa_timezone( filler );
	filler += dt->tz_delta;
	gmtime_r( &filler, &t );
#endif

	if( unfilled & YEAR )
		dt->year = t.tm_year + 1900;
	else if( dt->year < 100 )
		dt->year += 100 * ( (t.tm_year+1900)/100 );
	if( unfilled & MONTH )
		dt->month = t.tm_mon + 1;
	if( unfilled & DAY )
		dt->day = t.tm_mday;
	if( unfilled & HOUR )
		dt->hour = t.tm_hour;
	if( unfilled & MINUTE )
		dt->minute = t.tm_min;
	if( unfilled & SECOND )
		dt->second = 0;

#ifdef DRMAA_DEBUG
	drmaa_print_datetime( dt, dbg, sizeof(dbg) );
	DEBUG(( "<- drmaa_fill_datetime; dt={%s}", dbg ));
#endif
}


time_t
drmaa_mktime( const drmaa_datetime_t *dt )
{
	const unsigned month_days[12]
		= { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };
	unsigned long year, month;
	unsigned long years, days;
	time_t result;
#ifdef DRMAA_DEBUG
	char dbg[ 128 ];
	drmaa_print_datetime( dt, dbg, sizeof(dbg) );
	DEBUG(( "-> drmaa_mktime( dt={%s} )", dbg ));
#endif
	year = dt->year;
	month = dt->month;
	while( month < 1 )
	 { year--;  month += 12; }
	while( month > 12 )
	 { year++;  month -= 12; }
	years = year - 1970;
	days = 365*years + (years+1)/4;
	days += month_days[ month-1 ];
	if( month > 2  &&  (year&3) == 0 )
		days ++;
	days += dt->day - 1;
	result = ( ( days*24 + dt->hour )*60 + dt->minute )*60
		+ dt->second - dt->tz_delta;
#if DRMAA_DEBUG
	 {
		struct tm utc_tm;
		gmtime_r( &result, &utc_tm );
		DEBUG(( "years=%ld, days=%ld", years, days ));
		DEBUG(( "<- drmaa_mktime =%ld (%04d-%02d-%02d %02d:%02d%02d+00:00)",
					result,
					1900+utc_tm.tm_year, 1+utc_tm.tm_mon, utc_tm.tm_mday,
					utc_tm.tm_hour, utc_tm.tm_min, utc_tm.tm_sec
					));
	 }
#endif
	return result;
}


time_t
drmaa_parse_datetime( const char *string, drmaa_err_ctx_t *err )
{
	drmaa_dt_parser_t *parser = NULL;
	drmaa_dt_lexer_t *lexer = NULL;
	time_t result;

	DRMAA_MALLOC( parser, drmaa_dt_parser_t );
	DRMAA_MALLOC( lexer, drmaa_dt_lexer_t );

	if( OK(err) )
	 {
		int parse_err = 0;
		parser->lexer = lexer;
		parser->n_errors = 0;
		lexer->parser = parser;
		lexer->begin = lexer->p = (unsigned char*)string;
		lexer->end = (unsigned char*)( string + strlen(string) );
		parse_err = drmaa_dt_parse( parser, lexer );
		if( parse_err || parser->n_errors )
			RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ATTRIBUTE_VALUE );
	 }

	if( OK(err) )
	 {
		drmaa_datetime_t dt;
		time_t now;
		char dbg[256];

		dt = parser->result;
		drmaa_print_datetime( &dt, dbg, sizeof(dbg) );
		DEBUG(( "parsed: %s", dbg ));
		now = time(NULL);
		drmaa_fill_datetime( &dt, now );
		drmaa_print_datetime( &dt, dbg, sizeof(dbg) );
		DEBUG(( "filled: %s", dbg ));
		result = drmaa_mktime( &dt );
		if( result < now )
		 {
			unsigned unfilled = ~dt.mask;
			if( unfilled & DAY )
			 {
				while( result < now )
				 {
					DEBUG(( "next day" ));
					result += 24*3600;
				 }
			 }
			else if( unfilled & MONTH )
			 {
				while( result < now )
				 {
					DEBUG(( "next month" ));
					dt.month++;
					result = drmaa_mktime( &dt );
				 }
			 }
			else if( unfilled & YEAR )
			 {
				while( result < now )
				 {
					DEBUG(( "next year" ));
					dt.year++;
					result = drmaa_mktime( &dt );
				 }
			 }
			else
				RAISE_DRMAA_1( DRMAA_ERRNO_INVALID_ATTRIBUTE_VALUE );
		 }
	 }

	DRMAA_FREE( parser );
	DRMAA_FREE( lexer );
	return result;
}


void
drmaa_dt_error(
		drmaa_dt_parser_t *parser,
		drmaa_dt_lexer_t *lexer __attribute__((unused)),
		const char *fmt, ... )
{
	va_list args;
	char *msg = NULL;
	parser->n_errors ++;
	va_start( args, fmt );
	vasprintf( &msg, fmt, args );
	va_end( args );
	DEBUG(( "drmaa_dt_error: %s", msg ));
	free( msg );
}



int
drmaa_dt_lex( YYSTYPE *lvalp, drmaa_dt_lexer_t *lex )
{
	const unsigned char *end = lex->end;
	/* int sign = +1; */
	while( isspace(*lex->p)  &&  lex->p != end )
		lex->p++;
	if( lex->p == end )
		return -1;
	switch( *lex->p )
	 {
		case '/':  case ':':
		case '+':  case '-':
			return * lex->p++;
#if 0
		case '-':
			sign = -1;
		case '+': /* fall through */
			if( ++(lex->p) == end )
			 {
				drmaa_dt_error( lex->parser, lex, "unexpected EOT" );
				return -1;
			 }
		default: /* fall through */
#endif
		default:
		 {
			int num = 0;
			if( ! ('0' <= *lex->p  &&  *lex->p <= '9') )
			 {
				drmaa_dt_error( lex->parser, lex, "invalid char '%c'", *(lex->p)++ );
				return LEXER_ERROR;
			 }
			while( lex->p != end  &&  '0' <= *lex->p  &&  *lex->p <= '9' )
			 {
				num *= 10;
				num += *(lex->p)++ - '0';
			 }
			lvalp->integer = num;
			return NUM;
		 }
	 }
}


