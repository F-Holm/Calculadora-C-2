%code top {
#include <stdio.h>
#include <stdlib.h>

#include "calc.h"
#include "scanner.h"
}

%code provides {
void yyerror(const char *mensaje);
}

%defines "build/parser.h"
%output "build/parser.c"
%define parse.error verbose
%define lr.default-reduction consistent
%define parse.lac full

%union {
  double num;
  char *id;
}

%token <num> NUM
%token <id>  ID
%token MAS_IGUAL "+=" MENOS_IGUAL "-=" POR_IGUAL "*=" DIV_IGUAL "/="
%token LEXERR

%type <num> expresion

%destructor { free($$); } <id>

%right '=' "+=" "-=" "*=" "/="
%left '+' '-'
%left '*' '/'
%precedence NEG
%right '^'

%%

sesion
    : %empty
    | sesion linea              { mostrar_prompt(); }
    ;

linea
    : '\n'
    | expresion '\n'            { mostrar_resultado($1); }
    | error '\n'
    ;

expresion
    : expresion '+' expresion   { $$ = $1 + $3; }
    | expresion '-' expresion   { $$ = $1 - $3; }
    | expresion '*' expresion   { $$ = $1 * $3; }
    | expresion '/' expresion   {
                                  if (!division_valida($3)) YYERROR;
                                  $$ = $1 / $3;
                                }
    | expresion '^' expresion   { if (!potencia($1, $3, &$$)) YYERROR; }
    | '-' expresion %prec NEG   { $$ = -$2; }
    | '(' expresion ')'         { $$ = $2; }
    | NUM                       { $$ = $1; }
    | ID                        {
                                  $$ = valor_variable($1);
                                  free($1);
                                }
    | ID '=' expresion          { $$ = asignar($1, $3); free($1); }
    | ID "+=" expresion         {
                                  $$ = asignar($1, valor_variable($1) + $3);
                                  free($1);
                                }
    | ID "-=" expresion         {
                                  $$ = asignar($1, valor_variable($1) - $3);
                                  free($1);
                                }
    | ID "*=" expresion         {
                                  $$ = asignar($1, valor_variable($1) * $3);
                                  free($1);
                                }
    | ID "/=" expresion         {
                                  if (!division_valida($3)) {
                                    free($1);
                                    YYERROR;
                                  }
                                  $$ = asignar($1, valor_variable($1) / $3);
                                  free($1);
                                }
    ;

%%

void yyerror(const char *mensaje) {
  if (yychar == LEXERR) return;
  printf("%s\n", mensaje);
}
