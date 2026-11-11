#include <stdio.h>

#include "calc.h"
#include "parser.h"
#include "scanner.h"

int main(void) {
  mostrar_prompt();
  int resultado = yyparse();
  putchar('\n');
  liberar_diccionario();
  yylex_destroy();
  return resultado;
}
