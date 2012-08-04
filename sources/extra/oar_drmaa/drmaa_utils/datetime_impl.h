/* $Id: datetime_impl.h 533 2007-12-22 15:25:42Z lukasz $ */
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
 * @file datetime_impl.h
 * DRMAA date/time parser - Bison interface functions.
 */
#ifndef __DRMAA__DATETIME_IMPL_H
#define __DRMAA__DATETIME_IMPL_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/datetime.h>

/** @addtogroup datetime */
/* @{ */

typedef struct drmaa_dt_parser_s drmaa_dt_parser_t;
typedef struct drmaa_dt_lexer_s drmaa_dt_lexer_t;
union YYSTYPE;

/** Date/time parser data. */
struct drmaa_dt_parser_s {
	drmaa_dt_lexer_t *lexer;  /**< Lexical analyzer. */
	drmaa_datetime_t result;  /**< Parsing result. */
	int n_errors; /**< Number of parse errors. */
};

/** Date/time lexical analyzer. */
struct drmaa_dt_lexer_s {
	drmaa_dt_parser_t *parser;  /**< Date/time parser. */
	const unsigned char *begin; /**< Begin of parsed string. */
	const unsigned char *end;   /**< End of parsed string. */
	const unsigned char *p;     /**< Scanner position
		(points to first not parsed character). */
};

/** Parser interface function (Bison generated). */
int drmaa_dt_parse( drmaa_dt_parser_t *parser, drmaa_dt_lexer_t *lexer );

/**
 * Error reporting function (hand written).
 */
void drmaa_dt_error(
		drmaa_dt_parser_t *parser, drmaa_dt_lexer_t *lexer,
		const char *fmt, ...
		);

/** Lexer interface (hand written). */
int drmaa_dt_lex( union YYSTYPE *lvalp, drmaa_dt_lexer_t *lexer );

/* @} */

#endif /* __DRMAA__DATETIME_IMPL_H */

