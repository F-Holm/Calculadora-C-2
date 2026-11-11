%top{
#define _POSIX_C_SOURCE 200809L
}

%{
#include <stdio.h>
#include <string.h>

#include "calc.h"
#include "parser.h"
%}

%option header-file="build/scanner.h"
%option outfile="build/scanner.c"
%option noinput
%option nounput
%option noyywrap

digito      [0-9]
letra       [a-zA-Z]
entero      {digito}+
exponente   [eE][+-]?{entero}
fraccion    {entero}\.{entero}?|{entero}?\.{entero}
real        {entero}{exponente}|{fraccion}{exponente}?
ident       {letra}({letra}|{digito})*
nosep       [^ \t\r\n+\-*/^=()]

%%

{ident}             {
                      yylval.id = strdup(yytext);
                      return ID;
                    }

{entero}|{real}     {
                      sscanf(yytext, "%lf", &yylval.num);
                      return NUM;
                    }

"+="                { return MAS_IGUAL; }
"-="                { return MENOS_IGUAL; }
"*="                { return POR_IGUAL; }
"/="                { return DIV_IGUAL; }

[-+*/^=()]          { return yytext[0]; }

\n                  { return '\n'; }

[ \t\r]+            ;

{letra}{nosep}+     {
                      error_lexico("Error léxico: identificador inválido",
                                   yytext);
                      return LEXERR;
                    }

{real}{nosep}+      {
                      error_lexico("Error léxico REAL inválido", yytext);
                      return LEXERR;
                    }

{entero}{nosep}+    {
                      error_lexico("Error léxico: constante inválida", yytext);
                      return LEXERR;
                    }

{nosep}+            {
                      error_lexico("Error léxico: cadena desconocida", yytext);
                      return LEXERR;
                    }

%%
