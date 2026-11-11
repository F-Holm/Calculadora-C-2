/*
 * parser.y — Analizador sintáctico (parser) de la calculadora, para bison.
 *
 * bison lee este archivo y genera build/parser.c (la función yyparse) y
 * build/parser.h (los tokens, el tipo YYSTYPE y yylval, que usa flex).
 * yyparse() es un parser LALR(1) ascendente: pide tokens a yylex() y, cada
 * vez que reduce una regla, ejecuta su acción semántica (el código entre
 * llaves).
 */

/* Va al principio de build/parser.c. */
%code top {
#include <stdio.h>
#include <stdlib.h>

#include "calc.h"    /* Rutinas semánticas y diccionario. */
#include "scanner.h" /* yylex(), generado por flex. */
}

/* Va a build/parser.h: lo ven los demás módulos que lo incluyen. */
%code provides {
void yyerror(const char *mensaje);
}

/*
 * Directivas que reemplazan opciones de línea de comandos (requisito de la
 * consigna: alcanza con `bison parser.y`).
 *   %defines           genera el header con ese nombre (equivale a -d).
 *   %output            nombre del fuente generado (si no, parser.tab.c).
 *                      Los dos van a build/, la carpeta de archivos de
 *                      compilación (rutas relativas a la raíz del repo,
 *                      desde donde make invoca a bison).
 *   parse.error verbose  mensajes detallados:
 *                      "syntax error, unexpected '*', expecting NUM or ..."
 */
%defines "build/parser.h"
%output "build/parser.c"
%define parse.error verbose

/*
 * Que una línea con error NO tenga efectos (por ejemplo, no asigne).
 *
 * Problema: un parser LALR puede reducir una regla antes de darse cuenta de
 * que el token siguiente es inválido, y al reducir ejecuta la acción. Así,
 * en `q = 3 @` o en `a = 5 )` se haría la asignación y recién después se
 * detectaría el error. Hay dos causas, y una directiva para cada una:
 *
 *   lr.default-reduction consistent
 *       Por defecto bison reduce en muchos estados sin mirar el token
 *       siguiente ("reducción por defecto"). Con `consistent` sólo lo hace en
 *       los estados que tienen una única acción posible. Las reducciones que
 *       siguen a un '\n' son de ese tipo, así que en modo interactivo el
 *       resultado se sigue mostrando apenas se aprieta Enter.
 *
 *   parse.lac full   (LAC = LookAhead Correction)
 *       LALR fusiona estados, y por eso ')' parece válido después de `a = 5`
 *       (lo sería dentro de `(a = 5)`). Con LAC, antes de reducir, bison
 *       verifica en una pila auxiliar que el token se vaya a poder desplazar
 *       de verdad; si no, informa el error ahí mismo, sin ejecutar acciones.
 *       Además hace más precisa la lista "expecting ..." de los mensajes.
 */
%define lr.default-reduction consistent
%define parse.lac full

/*
 * Valor semántico de los símbolos (YYSTYPE). Un número lleva un double; un
 * identificador, su nombre (una copia hecha con strdup en el scanner).
 */
%union {
  double num;
  char *id;
}

/*
 * Tokens. El orden importa para los mensajes de error: bison lista los
 * tokens esperados según el orden en que aparecen en este archivo, por eso
 * NUM va antes que ID, y '-' (en %left) aparece antes que '(' (en las reglas).
 * Los alias entre comillas ("+=") son los que se muestran en los mensajes.
 * LEXERR lo devuelve el scanner ante un error léxico; ninguna regla lo usa.
 */
%token <num> NUM
%token <id>  ID
%token MAS_IGUAL "+=" MENOS_IGUAL "-=" POR_IGUAL "*=" DIV_IGUAL "/="
%token LEXERR

%type <num> expresion

/*
 * Si bison descarta un ID durante la recuperación de errores, libera su
 * nombre con este destructor (evita pérdidas de memoria).
 */
%destructor { free($$); } <id>

/*
 * Precedencia y asociatividad (gramática ACHATADA). Una línea por nivel,
 * de MENOR a MAYOR precedencia:
 *   asignaciones   = += -= *= /=   a derecha:  a = b += 1  ->  a = (b += 1)
 *   suma y resta   + -             a izquierda
 *   producto       * /             a izquierda
 *   menos unario   NEG             (por %prec): -2*3 = (-2)*3, -2^2 = -(2^2)
 *   potencia       ^               a derecha:  2^3^2 = 2^(3^2)
 * NEG es un token "ficticio": el scanner nunca lo devuelve, sólo nombra un
 * nivel de precedencia para la regla del '-' unario.
 *
 * Nota sobre las asignaciones: su lado izquierdo es siempre un ID (no una
 * expresion), así que `a = b = 1` sólo puede agruparse a derecha por la
 * forma misma de la regla. %right documenta esa asociatividad; lo que bison
 * usa de verdad es la precedencia (que sea la menor), para que en
 * `a = 3 + b` se desplace el '+' en lugar de reducir `a = 3`. Por eso
 * `bison -Wall` avisa "useless associativity": es un aviso informativo, sin
 * efecto sobre el comportamiento (sin -Wall bison no muestra nada).
 */
%right '=' "+=" "-=" "*=" "/="
%left '+' '-'
%left '*' '/'
%precedence NEG
%right '^'

%%

/*
 * sesion: una secuencia (posiblemente vacía) de líneas. Recursión a
 * izquierda, la recomendada en bison. Después de cada línea se imprime el
 * prompt de la siguiente (el primero lo imprime main).
 */
sesion
    : %empty
    | sesion linea              { mostrar_prompt(); }
    ;

/*
 * linea: vacía, una expresión (se imprime su valor), o un error.
 * `error` es el no terminal predefinido de bison para recuperarse: ante un
 * error sintáctico (o un YYERROR semántico, o un LEXERR) bison descarta lo
 * analizado de la línea y los tokens que siguen hasta el '\n', y continúa con
 * la línea siguiente. No se usa yyerrok, como pide la consigna.
 */
linea
    : '\n'
    | expresion '\n'            { mostrar_resultado($1); }
    | error '\n'
    ;

/*
 * expresion: una sola regla achatada; la ambigüedad la resuelven las
 * declaraciones de precedencia de arriba.
 * Errores semánticos: se informan y se hace YYERROR, que abandona la línea
 * igual que un error sintáctico pero sin llamar a yyerror ni contar en
 * yynerrs. Ojo: YYERROR no llama al %destructor de los símbolos de la regla
 * que se está reduciendo, por eso se libera el ID antes a mano.
 */
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
                                  /* Uso de una variable: si no existía, se
                                   * autodeclara con valor 0. */
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

/*
 * yyerror: bison la llama al detectar un error sintáctico, con el mensaje ya
 * armado ("syntax error, unexpected ..."). yychar es el token de lookahead
 * (la variable global del parser): si es LEXERR, el error lo provocó un error
 * léxico que el scanner ya informó, así que no se repite el aviso.
 */
void yyerror(const char *mensaje) {
  if (yychar == LEXERR) return;
  printf("%s\n", mensaje);
}
