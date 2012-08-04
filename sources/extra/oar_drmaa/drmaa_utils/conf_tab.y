/* $Id: conf_tab.y 533 2007-12-22 15:25:42Z lukasz $ */
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
#include <drmaa_utils/conf_impl.h>
#include <drmaa_utils/conf_tab.h>
%}

%pure-parser
%locations
%name-prefix="drmaa_conf_"
%parse-param { drmaa_conf_parser_t *parser }
%parse-param { drmaa_conf_lexer_t *lexer }
%lex-param { drmaa_conf_lexer_t *lexer }


%union {
	int integer;
	char *string;
	drmaa_conf_option_t *option;
	drmaa_conf_dict_t *dictionary;
	drmaa_conf_pair_t pair;
}

%type<option> value
%destructor { drmaa_conf_option_destroy($$); } value
%type<dictionary> start conf dict dict_body pair_list
%destructor { drmaa_conf_dict_destroy($$); } conf dict dict_body pair_list
%type<pair> pair
%token<integer> INTEGER
%token<string> STRING
%destructor { free($$); } STRING
%token LEXER_ERROR


%%

start
	: conf { parser->result = $1;  $$ = NULL; }
	;

conf
	: dict
	| dict_body
	;

dict
	: '{' dict_body '}' { $$ = $2; }
	;

dict_body
	: pair_list  { $$ = $1; }
	| pair_list ','  { $$ = $1; }
	| { $$ = drmaa_conf_dict_create( parser->err ); }
	;

pair_list
	: pair {
			drmaa_conf_dict_t *dict = NULL;
			dict = drmaa_conf_dict_create( parser->err );
			if( OK(parser->err) )
				drmaa_conf_dict_set( dict, $1.key, $1.value, parser->err );
			$$ = dict;
		}
	| pair_list ',' pair
		{ drmaa_conf_dict_set( $1, $3.key, $3.value, parser->err );  $$ = $1; }
	;

pair
	: STRING ':' value { $$.key = $1;  $$.value = $3; }
	;

value
	: INTEGER
		{ $$ = drmaa_conf_option_create( DRMAA_CONF_INTEGER, &$1, parser->err ); }
	| STRING
		{ $$ = drmaa_conf_option_create( DRMAA_CONF_STRING, $1, parser->err ); }
	| dict
		{ $$ = drmaa_conf_option_create( DRMAA_CONF_DICT, $1, parser->err ); }
	;

%%
