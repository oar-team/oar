/* $Id: conf.c 533 2007-12-22 15:25:42Z lukasz $ */
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

#ifdef HAVE_CONFIG_H
#	include <config.h>
#endif

#include <assert.h>
#include <ctype.h>
#include <stdarg.h>
#include <string.h>

#include <drmaa_utils/common.h>
#include <drmaa_utils/conf_impl.h>
#include <drmaa_utils/conf_tab.h>
#include <drmaa_utils/util.h>

#ifndef lint
static char rcsid[]
#	ifdef __GNUC__
		__attribute__ ((unused))
#	endif
	= "$Id: conf.c 533 2007-12-22 15:25:42Z lukasz $";
#endif


drmaa_conf_dict_t *
drmaa_conf_read(
		drmaa_conf_dict_t *configuration,
		const char *filename, bool must_exist,
		const char *content, size_t content_len,
		drmaa_err_ctx_t *err
		)
{
	drmaa_conf_dict_t *result = NULL;
	drmaa_conf_parser_t *parser = NULL;
	drmaa_conf_lexer_t *lexer = NULL;
	char *file_content = NULL;
	size_t file_content_len = 0;

	DEBUG((
		"-> drmaa_conf_read( filename=%s, must_exist=%s, content=%s )",
		filename, must_exist ? "true" : "false", content
		));
	if( OK(err) )
		DRMAA_MALLOC( parser, drmaa_conf_parser_t );
	if( OK(err) )
	 {
		parser->lexer = lexer;
		parser->result = NULL;
		parser->n_errors = 0;
		parser->first_error = NULL;
		parser->last_error = NULL;
		parser->err = err;
	 }
	if( OK(err) )
		DRMAA_MALLOC( lexer, drmaa_conf_lexer_t );
	if( OK(err) )
	 {
		lexer->parser = parser;
		lexer->filename = filename;
		lexer->buffer = NULL;
		lexer->buflen = 0;
		lexer->pos = NULL;
		lexer->lineno = 0;
		lexer->cline = NULL;
	 }

	if( OK(err)  &&  filename )
		drmaa_read_file(
				filename, must_exist,
				&file_content, &file_content_len, err
				);
	if( OK(err) )
	 {
		if( file_content )
		 {
			lexer->buffer = (const uchar*)file_content;
			lexer->buflen = file_content_len;
			DEBUG(( "content from file" ));
		 }
		else if( content )
		 {
			lexer->buffer = (const uchar*)content;
			lexer->buflen = content_len;
			DEBUG(( "content from memory" ));
		 }
		else
			goto cleanup;
	 }

	if( OK(err) )
	 {
		lexer->pos = lexer->cline = lexer->buffer;
		lexer->lineno = 1;
	 }

	if( OK(err) )
	 {
		drmaa_conf_parse( parser, lexer );
		result = parser->result;
	 }

	if( parser  &&  parser->n_errors > 0 )
	 {
		if( err->n_errors == 0 )
		 {
			err->rc = DRMAA_ERRNO_INTERNAL_ERROR;
			if( err->msg )
			 {
				drmaa_conf_error_t *i;
				size_t pos = 0;
				size_t capacity = err->msgsize - 1;
				for( i = parser->first_error;  i != NULL;  i = i->next )
				 {
					size_t len;
					if( pos>0  &&  pos < capacity )
						err->msg[ pos++ ] = '\n';
					len = strlen( i->message );
					if( pos+len > capacity )
						len = capacity-pos;
					memcpy( err->msg + pos, i->message, len );
					pos += len;
				 }
				err->msg[ pos ] = '\0';
			 }
		 }
		err->n_errors += parser->n_errors;
	 }

cleanup:
	if( parser != NULL )
	 {
		drmaa_conf_error_t *i, *j;
		for( i = parser->first_error;  i != NULL;  )
		 {
			j = i;
			i = i->next;
			DRMAA_FREE( j->message );
			DRMAA_FREE( j );
		 }
	 }
	DRMAA_FREE( parser );
	DRMAA_FREE( lexer );
	DRMAA_FREE( file_content );

	if( OK(err) )
	 {
		if( configuration )
			result = drmaa_conf_dict_merge( configuration, result, err );
	 }
	else
	 {
		drmaa_conf_dict_destroy( result );
		result = NULL;
	 }

	DEBUG(( "<- drmaa_conf_read" ));
	return result;
}



int
drmaa_conf_lex(
		union YYSTYPE *lvalp, struct YYLTYPE *locp,
		drmaa_conf_lexer_t *lexer
		)
{
	drmaa_err_ctx_t *err = lexer->parser->err;
	const uchar *c = lexer->pos;
	const uchar *end = lexer->buffer + lexer->buflen;
	const char *error = NULL;
	int result;

	while( c<end )
		switch( *c )
		 {
			case '#':  /* a comment */
				while( c<end && *c != '\n' )
					c++;
			case '\n':  /* no break */
				lexer->lineno++;
				lexer->cline = c+1;
			case ' ':  case '\t':  case '\r':  /* no break */
				c++;
				break;
			default:
				goto token_begin;
		 }

token_begin:
	locp->first_line = lexer->lineno;
	locp->first_column = c - lexer->cline + 1;

	if( c == end )
		result = 0;
	else
		switch( *c )
		 {
			case ':':  case ',':  case '{':  case '}':
				result = *c++;
				break;

			case '0':  case '1':  case '2':  case '3':  case '4':
			case '5':  case '6':  case '7':  case '8':  case '9':
			 {
				int v = 0;
				while( c < end  &&  '0' <= *c  &&  *c <= '9' )
				 {
					v *= 10;
					v += *c - '0';
					c++;
				 }
				lvalp->integer = v;
				result = INTEGER;
				break;
			 }

			case '"':  case '\'':
			 {
				uchar delimiter;
				const uchar *begin;
				delimiter = *c++;
				begin = c;
				while( c < end  &&  *c != delimiter )
					c++;
				if( c == end )
				 {
					error = "expected string delimiter but EOF found";
					result = LEXER_ERROR;
				 }
				else
				 {
					lvalp->string = drmaa_strndup( (const char*)begin, c-begin, err );
					result = STRING;
					c++;
				 }
				break;
			 }

			default:
			 {
				const uchar *begin = c;
				while( c<end  &&  !isspace(*c) )
					switch( *c )
					 {
						case ':':  case ',':  case '{':  case '}':
							goto end_of_string;
						default:
							c++;
							break;
					 }
			end_of_string:
				lvalp->string = drmaa_strndup( (const char*)begin, c-begin, err );
				result = STRING;
				break;
			 }
		 }

	locp->last_line = lexer->lineno;
	locp->last_column = c - lexer->cline;
	if( locp->last_column < locp->first_column )
		locp->last_column = locp->first_column;
	lexer->pos = c;

	if( error )
		drmaa_conf_error( locp, lexer->parser, lexer, error );

	return result;
}



void
drmaa_conf_error(
		struct YYLTYPE *locp,
		drmaa_conf_parser_t *parser, drmaa_conf_lexer_t *lexer,
		const char *fmt, ...
		)
{
	drmaa_err_ctx_t *err = parser->err;
	char *message = NULL;
	drmaa_conf_error_t *error = NULL;

	if( OK(err) )
		DRMAA_MALLOC( error, drmaa_conf_error_t );
	if( OK(err) )
	 {
		error->next = NULL;
		error->message = NULL;
	 }
	if( OK(err) )
	 {
		va_list args;
		va_start( args, fmt );
		message = drmaa_vasprintf( fmt, args, err );
		va_end( args );
	 }
	if( OK(err) )
		error->message = drmaa_asprintf( err, "%s:%d:%d: %s",
				parser->lexer->filename, locp->first_line, locp->first_column,
				message );

	if( OK(err) )
	 {
		if( parser->n_errors == 0 )
			parser->first_error = parser->last_error = error;
		else
		 {
			parser->last_error->next = error;
			parser->last_error = error;
		 }
		parser->n_errors++;
	 }
	else
	 {
		if( error )
		 {
			if( error->message )
				DRMAA_FREE( error->message );
			DRMAA_FREE( error );
		 }
	 }

	if( message )
		DRMAA_FREE( message );
}



drmaa_conf_option_t *
drmaa_conf_option_create(
		drmaa_conf_type_t type,
		void *value,
		drmaa_err_ctx_t *err
		)
{
	drmaa_conf_option_t *o = NULL;
	if( !OK(err) )  return NULL;

	DRMAA_MALLOC( o, drmaa_conf_option_t );
	if( OK(err) )
	 {
		o->type = type;
		switch( type )
		 {
			case DRMAA_CONF_INTEGER:
				o->val.integer = *(int*)value;
				break;
			case DRMAA_CONF_STRING:
				o->val.string = (char*)value;
				break;
			case DRMAA_CONF_DICT:
				o->val.dict = (drmaa_conf_dict_t*)value;
				break;
			default:
				assert(false);
				break;
		 }
		return o;
	 }
	else
		return NULL;
}


void
drmaa_conf_option_destroy( drmaa_conf_option_t *option )
{
	if( option == NULL )
		return;
	switch( option->type )
	 {
		case DRMAA_CONF_INTEGER:
			break;
		case DRMAA_CONF_STRING:
			DRMAA_FREE( option->val.string );
			break;
		case DRMAA_CONF_DICT:
			drmaa_conf_dict_destroy( option->val.dict );
			break;
		default:
			assert( false );
	 }
	DRMAA_FREE( option );
}


drmaa_conf_option_t *
drmaa_conf_option_merge(
		drmaa_conf_option_t *lhs, drmaa_conf_option_t *rhs, drmaa_err_ctx_t *err
		)
{
	if( lhs->type == rhs->type  &&  rhs->type == DRMAA_CONF_DICT )
	 {
		lhs->val.dict = drmaa_conf_dict_merge( lhs->val.dict, rhs->val.dict, err );
		DRMAA_FREE( rhs );
		return lhs;
	 }
	else
	 {
		drmaa_conf_option_destroy( lhs );
		return rhs;
	 }
}


void
drmaa_conf_option_dump( drmaa_conf_option_t *option )
{
	if( option == NULL )
	 {
		printf( "(null)" );
		return;
	 }
	switch( option->type )
	 {
		case DRMAA_CONF_STRING:
			printf( "\"%s\"", option->val.string );
			break;
		case DRMAA_CONF_INTEGER:
			printf( "%d", option->val.integer );
			break;
		case DRMAA_CONF_DICT:
			drmaa_conf_dict_dump( option->val.dict );
			break;
	 }
}



struct drmaa_conf_dict_s {
	drmaa_conf_dict_t *next;
	char *key;
	drmaa_conf_option_t *value;
};


drmaa_conf_dict_t *
drmaa_conf_dict_create( drmaa_err_ctx_t *err )
{
	drmaa_conf_dict_t *dict = NULL;
	DRMAA_MALLOC( dict, drmaa_conf_dict_t );
	if( OK(err) )
	 {
		dict->next = NULL;
		dict->key = NULL;
		dict->value = NULL;
	 }
	return dict;
}


void
drmaa_conf_dict_destroy( drmaa_conf_dict_t *dict )
{
	drmaa_conf_dict_t *i;
	for( i = dict;  i != NULL;  )
	 {
		drmaa_conf_dict_t *c = i;
		i = i->next;
		DRMAA_FREE( c->key );
		drmaa_conf_option_destroy( c->value );
		DRMAA_FREE( c );
	 }
}


drmaa_conf_option_t *
drmaa_conf_dict_get(
		drmaa_conf_dict_t *dict, const char *key, drmaa_err_ctx_t *err )
{
	drmaa_conf_dict_t *i;
	if( dict == NULL  ||  key == NULL )
		return NULL;
	for( i = dict->next;  i != NULL;  i = i->next )
	 {
		if( !strcmp( i->key, key ) )
			return i->value;
	 }
	return NULL;
}


void
drmaa_conf_dict_set(
		drmaa_conf_dict_t *dict, const char *key, drmaa_conf_option_t *value,
		drmaa_err_ctx_t *err
		)
{
	drmaa_conf_dict_t *i;
	for( i = dict->next;  i != NULL;  i = i->next )
	 {
		if( !strcmp( i->key, key ) )
			break;
	 }

	if( i != NULL )
	 {
		drmaa_conf_option_destroy( i->value );
		i->value = value;
	 }
	else
	 {
		drmaa_conf_dict_t *n = NULL;
		DRMAA_MALLOC( n, drmaa_conf_dict_t );
		if( OK(err) )
			n->key = drmaa_strdup( key, err );
		if( OK(err) )
			n->value = value;
		if( OK(err) )
		 {
			n->next = dict->next;
			dict->next = n;
		 }
		else
			DRMAA_FREE( n );
	 }
}


drmaa_conf_dict_t *
drmaa_conf_dict_merge(
		drmaa_conf_dict_t *lhs, drmaa_conf_dict_t *rhs,
		drmaa_err_ctx_t *err
		)
{
	drmaa_conf_dict_t *i, *j;
	for( j = rhs->next;  j != NULL;  )
	 {
		drmaa_conf_dict_t *r = j;
		j = j->next;

		for( i = lhs->next;  i != NULL;  i = i->next )
			if( !strcmp( i->key, r->key ) )
				break;

		if( i != NULL )
		 {
			i->value = drmaa_conf_option_merge( i->value, r->value, err );
			DRMAA_FREE( r->key );
			DRMAA_FREE( r );
		 }
		else
		 {
			r->next = lhs->next;
			lhs->next = r;
		 }
	 }

	DRMAA_FREE( rhs );
	return lhs;
}


void
drmaa_conf_dict_dump( drmaa_conf_dict_t *dict )
{
	drmaa_conf_dict_t *i;

	if( dict == NULL )
	 {
		printf( "(null)" );
		return;
	 }
	printf( "{" );
	for( i=dict->next;  i;  i = i->next )
	 {
		if( i != dict->next )
			printf( "," );
		printf( " %s=", i->key );
		drmaa_conf_option_dump( i->value );
	 }
	printf( " }" );
}

