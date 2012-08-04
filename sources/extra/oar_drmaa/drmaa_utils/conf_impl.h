/* $Id: conf_impl.h 533 2007-12-22 15:25:42Z lukasz $ */
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

#ifndef __DRMAA__CONF_IMPL_H
#define __DRMAA__CONF_IMPL_H

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <drmaa_utils/conf.h>

typedef struct drmaa_conf_parser_s drmaa_conf_parser_t;
typedef struct drmaa_conf_lexer_s drmaa_conf_lexer_t;
typedef struct drmaa_conf_error_s drmaa_conf_error_t;
union YYSTYPE;
struct YYLTYPE;
typedef unsigned char uchar;


int
drmaa_conf_parse( drmaa_conf_parser_t *parser, drmaa_conf_lexer_t *lexer );

int
drmaa_conf_lex( union YYSTYPE *lvalp, struct YYLTYPE *locp,
		drmaa_conf_lexer_t *lexer );

void
drmaa_conf_error(
		struct YYLTYPE *locp,
		drmaa_conf_parser_t *parser, drmaa_conf_lexer_t *lexer,
		const char *fmt, ...
		);


/** DRMAA configuration file parser data. */
struct drmaa_conf_parser_s {
	drmaa_conf_lexer_t *lexer;

	/** Parsing result - root of syntax tree. */
	drmaa_conf_dict_t *result;

	int n_errors;  /**< Number of parse/lexical errors. */
	drmaa_conf_error_t *first_error; /**< First of errors (or @c NULL). */
	drmaa_conf_error_t *last_error;  /**< Last of error (or @c NULL). */

	/** Error context (for non parse/lexical errors. */
	drmaa_err_ctx_t *err;
};

/** DRMAA configuration file lexical analyzer data. */
struct drmaa_conf_lexer_s {
	drmaa_conf_parser_t *parser;  /**< Parser which use this lexer. */
	const char *filename; /**< Name of configuration file. */

	const uchar *buffer;  /**< Entire content of parsed configuration file. */
	size_t buflen;  /**< Length of \a buffer. */

	const uchar *pos;  /**< Current position of lexical analyzer. */
	int lineno; /**< Current line number (counted from 1). */
	const uchar *cline;  /**< Points to first character (byte) of current line. */
};

struct drmaa_conf_error_s {
	drmaa_conf_error_t *next;
	char *message;
};

typedef struct drmaa_conf_pair_s {
	char *key;
	drmaa_conf_option_t *value;
} drmaa_conf_pair_t;

#endif /* __DRMAA__CONF_IMPL_H */

