%top{
/*
 * scanner.l — Analizador léxico (scanner) de la calculadora, para flex.
 *
 * flex lee este archivo y genera build/scanner.c (la función yylex) y
 * build/scanner.h (su header, para que bison conozca yylex). Cada vez que el
 * parser necesita un token llama a yylex(), que devuelve el código del token
 * y deja su valor semántico en yylval.
 *
 * Este bloque %top va al principio de build/scanner.c, antes de cualquier
 * #include del código generado. Definir _POSIX_C_SOURCE hace visibles
 * funciones POSIX que usa el código de flex (fileno, isatty) aunque se
 * compile con -std=c23 (C estándar estricto).
 */
#define _POSIX_C_SOURCE 200809L
}

%{
/* Este bloque se copia a scanner.c después de las definiciones de flex. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "calc.h"   /* error_lexico() */
#include "parser.h" /* Tokens (NUM, ID, ...) y yylval, generados por bison. */
%}

/*
 * Opciones: con ellas basta invocar `flex scanner.l`, sin opciones en la
 * línea de comandos (requisito de la consigna).
 *   header-file  genera build/scanner.h (prototipo de yylex, yyin...).
 *   outfile      nombre del fuente generado (si no, sería lex.yy.c).
 *                Los dos van a build/, la carpeta de archivos de compilación
 *                (las rutas son relativas al directorio desde donde se
 *                invoca flex: la raíz del repo, que es donde corre make).
 *   noinput      no genera input()  -> evita el warning de función sin usar.
 *   nounput      no genera yyunput() -> idem.
 *   noyywrap     al llegar a EOF no llama a yywrap(): se termina. Así no hace
 *                falta enlazar con -lfl (la biblioteca de flex).
 */
%option header-file="build/scanner.h"
%option outfile="build/scanner.c"
%option noinput
%option nounput
%option noyywrap

/*
 * Definiciones: nombres para ER, tomadas de la gramática léxica del TP2.
 * Al usarlas como {nombre}, flex las expande entre paréntesis.
 *
 *   entero:     dígito | entero dígito
 *   exponente:  (e|E)(+|-)opt entero
 *   fracción:   entero . entero_opt  |  entero_opt . entero
 *   real:       entero exponente  |  fracción exponente_opt
 *   identificador: letra | identificador letra | identificador dígito
 *
 * `nosep` es cualquier carácter que NO separa lexemas: todo salvo blancos,
 * fin de línea, operadores y paréntesis. Las reglas de error lo usan para
 * tomar el lexema mal formado completo (por ejemplo "2.3.4a2.3"), en lugar
 * de partirlo en pedazos.
 */
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
                      /* Identificador. yytext se reutiliza en el próximo
                       * token, así que se pasa una COPIA a bison. El parser
                       * la libera con free() cuando ya no la necesita. */
                      yylval.id = strdup(yytext);
                      return ID;
                    }

{entero}|{real}     {
                      /* Número: toda constante se guarda como double. */
                      sscanf(yytext, "%lf", &yylval.num);
                      return NUM;
                    }

"+="                { return MAS_IGUAL;   /* Asignaciones compuestas: */ }
"-="                { return MENOS_IGUAL; /* son tokens de 2 caracteres */ }
"*="                { return POR_IGUAL;   /* declarados en parser.y.    */ }
"/="                { return DIV_IGUAL; }

[-+*/^=()]          {
                      /* Operadores de un carácter y paréntesis: el token es
                       * el propio carácter (bison los usa como '+', '(' ...).
                       * El '-' va primero en la clase para que sea literal. */
                      return yytext[0];
                    }

\n                  { return '\n'; /* Fin de línea: termina una sentencia. */ }

[ \t\r]+            { /* Blancos: se descartan. \r tolera finales CRLF. */ }

{letra}{nosep}+     {
                      /* --- Reglas de error ---
                       * Van DEBAJO de las correctas: si un lexema empareja
                       * con las dos con el mismo largo, flex elige la primera
                       * (la correcta). Sólo ganan cuando el lexema es más
                       * largo, o sea, cuando tiene caracteres inválidos.
                       *
                       * Empieza con letra y sigue con algo que no es letra ni
                       * dígito: identificador inválido (ej. "a#2.4"). */
                      error_lexico("Error léxico: identificador inválido",
                                   yytext);
                      return LEXERR;
                    }

{real}{nosep}+      {
                      /* Un real seguido de basura (ej. "2.3.4a2.3"). */
                      error_lexico("Error léxico REAL inválido", yytext);
                      return LEXERR;
                    }

{entero}{nosep}+    {
                      /* Un entero pegado a letras u otros símbolos que no
                       * forman un real (ej. "12a3"). */
                      error_lexico("Error léxico: constante inválida", yytext);
                      return LEXERR;
                    }

{nosep}+            {
                      /* Cualquier otra cosa: caracteres que no pertenecen al
                       * alfabeto (ej. "@@#;@"). Es el único error obligatorio.
                       * Como es la última regla, también cubre un "." suelto. */
                      error_lexico("Error léxico: cadena desconocida", yytext);
                      return LEXERR;
                    }

%%
/*
 * Sobre LEXERR: es un token que la gramática nunca usa. Al recibirlo, el
 * parser detecta un error sintáctico y se recupera con la regla
 * `linea: error '\n'`, descartando el resto de la línea. Así una línea con un
 * error léxico nunca se evalúa (por ejemplo "a = 3 @" no asigna nada).
 * yyerror (en parser.y) no imprime nada en ese caso, porque el error ya se
 * informó acá.
 */
