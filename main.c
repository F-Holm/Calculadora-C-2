/*
 * main.c — Punto de entrada de la calculadora.
 *
 * Como pide la consigna, main está en su propio fuente y sólo lanza el
 * análisis: yyparse() (generado por bison en parser.c) pide los tokens a
 * yylex() (generado por flex en scanner.c) hasta el fin de archivo, y en las
 * acciones semánticas calcula e imprime cada línea.
 */
#include <stdio.h>

#include "calc.h"
#include "parser.h"  /* Declara yyparse(). */
#include "scanner.h" /* Declara yylex_destroy(). */

int main(void) {
  /* El primer prompt se imprime acá; los siguientes los imprime el parser
   * cada vez que termina de procesar una línea (regla `sesion`). */
  mostrar_prompt();

  /* yyparse devuelve 0 = éxito, 1 = error sintáctico irrecuperable,
   * 2 = memoria insuficiente. Gracias a la recuperación de errores
   * (`linea: error '\n'`) los errores de una línea no cortan la sesión. */
  int resultado = yyparse();

  /* Al llegar a EOF (Ctrl+D) el cursor quedó después del último "> ". */
  putchar('\n');

  /* Libera la memoria: las variables y los buffers internos de flex. */
  liberar_diccionario();
  yylex_destroy();
  return resultado;
}
