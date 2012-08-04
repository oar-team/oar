/* $Id: datetime_tab.y 533 2007-12-22 15:25:42Z lukasz $ */
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

%{
#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif
#include <drmaa_utils/datetime_impl.h>
%}

/* those are Bison extensions */
%glr-parser
%pure-parser
%name-prefix="drmaa_dt_"
%parse-param { drmaa_dt_parser_t *parser }
%parse-param { drmaa_dt_lexer_t *lexer }
%lex-param { drmaa_dt_lexer_t *lexer }

%union {
	drmaa_datetime_t datetime;
	int              integer;
}

%type<datetime> datetime date time timezone
%type<integer>  sign
%token<integer> NUM
%token LEXER_ERROR

%%

start : datetime { parser->result = $1; }
	;

datetime
	: date time timezone {
		$$.mask = $1.mask | $2.mask | $3.mask;
		$$.year   = $1.year;
		$$.month  = $1.month;
		$$.day    = $1.day;
		$$.hour   = $2.hour;
		$$.minute = $2.minute;
		$$.second = $2.second;
		$$.tz_delta = $3.tz_delta;
	}
	;

date
	: NUM '/' NUM '/' NUM  { $$.year=$1;  $$.month=$3;  $$.day=$5;  $$.mask=YEAR|MONTH|DAY; }
	| NUM '/' NUM          { $$.year=0;   $$.month=$1;  $$.day=$3;  $$.mask=MONTH|DAY; }
	| NUM                  { $$.year=0;   $$.month=0;   $$.day=$1;  $$.mask=DAY; }
	|                      { $$.year=0;   $$.month=0;   $$.day=0;   $$.mask=0; }
	;


time
	: NUM ':' NUM          { $$.hour=$1;  $$.minute=$3;  $$.second=0;   $$.mask=HOUR|MINUTE; }
	| NUM ':' NUM ':' NUM  { $$.hour=$1;  $$.minute=$3;  $$.second=$5;  $$.mask=HOUR|MINUTE|SECOND; }
	;

/*
time
	: hour_min
	| hour_min ':' NUM  { $$=$1;  $$.second=$3;  $$.mask|=SECOND; }
	;

hour_min
	: NUM ':' NUM    { $$.hour=$1;  $$.minute=$3;  $$.mask=HOUR|MINUTE; }
	;
*/

timezone
	:                   { $$.tz_delta=0;  $$.mask=0; }
	| sign NUM          { $$.tz_delta=$1*3600*$2;  $$.mask=TZ_DELTA; }
	| sign NUM ':' NUM  { $$.tz_delta=$1*60*(60*$2+$4);  $$.mask=TZ_DELTA; }
	;

sign
	:      { $$ = +1; }
	| '+'  { $$ = +1; }
	| '-'  { $$ = -1; }
	;

