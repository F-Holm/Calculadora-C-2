/*
 * calc.c — Rutinas semánticas y manejo del diccionario de la calculadora.
 *
 * Contiene todo lo que NO es análisis léxico (scanner.l) ni sintáctico
 * (parser.y): la tabla de variables, los controles semánticos y la forma de
 * mostrar resultados, prompt y mensajes de error. Así el parser sólo dice
 * "qué" hacer en cada regla y este módulo resuelve "cómo".
 */
#include "calc.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---------------------------------------------------------------------------
 * Diccionario: lista simplemente enlazada de símbolos
 * ---------------------------------------------------------------------------
 * Para una calculadora interactiva la cantidad de variables es chica, así que
 * una lista con búsqueda lineal es suficiente y fácil de seguir. La lista es
 * `static`: sólo se accede a ella desde las funciones de este archivo
 * (vinculación interna), que son la interfaz publicada en calc.h.
 */
typedef struct Simbolo {
  char* nombre;        /* Copia propia del identificador (memoria dinámica). */
  double valor;        /* Valor actual de la variable. */
  struct Simbolo* sig; /* Siguiente símbolo de la lista. */
} Simbolo;

static Simbolo* diccionario = NULL; /* Primer nodo; NULL = lista vacía. */

/* Busca `nombre` en la lista. Devuelve el símbolo, o NULL si no está. */
static Simbolo* buscar(const char* nombre) {
  for (Simbolo* s = diccionario; s != NULL; s = s->sig) {
    if (strcmp(s->nombre, nombre) == 0) return s;
  }
  return NULL;
}

/* Busca `nombre` y, si no existe, lo "autodeclara": crea el símbolo con valor
 * inicial 0 y lo agrega al principio de la lista (inserción O(1)). */
static Simbolo* buscar_o_declarar(const char* nombre) {
  Simbolo* s = buscar(nombre);
  if (s != NULL) return s;

  s = malloc(sizeof *s);
  if (s == NULL || (s->nombre = strdup(nombre)) == NULL) {
    /* Sin memoria no hay forma razonable de seguir. */
    fputs("Error fatal: memoria insuficiente\n", stderr);
    exit(EXIT_FAILURE);
  }
  s->valor = 0.0;
  s->sig = diccionario;
  diccionario = s;
  return s;
}

double valor_variable(const char* nombre) {
  return buscar_o_declarar(nombre)->valor;
}

double asignar(const char* nombre, double valor) {
  buscar_o_declarar(nombre)->valor = valor;
  return valor;
}

void liberar_diccionario(void) {
  while (diccionario != NULL) {
    Simbolo* sig = diccionario->sig;
    free(diccionario->nombre);
    free(diccionario);
    diccionario = sig;
  }
}

/* ---------------------------------------------------------------------------
 * Controles semánticos
 * ---------------------------------------------------------------------------
 */

bool division_valida(double divisor) {
  if (divisor == 0.0) {
    error_semantico("división por cero");
    return false;
  }
  return true;
}

bool potencia(double base, double exponente, double* resultado) {
  if (base == 0.0 && exponente < 0.0) {
    /* 0^-n = 1 / 0^n: es una división por cero. */
    error_semantico("división por cero");
    return false;
  }
  if (base < 0.0 && exponente != floor(exponente)) {
    /* Raíz de un negativo: el resultado sería complejo, no real. */
    error_semantico("potencia sin resultado real");
    return false;
  }
  *resultado = pow(base, exponente);
  return true;
}

/* ---------------------------------------------------------------------------
 * Entrada / salida
 * ---------------------------------------------------------------------------
 * Todo va a stdout (como en salida.txt, donde los errores aparecen mezclados
 * con los resultados).
 */

void mostrar_prompt(void) {
  printf("> ");
  /* El prompt no termina en '\n'; sin fflush quedaría en el buffer y el
   * usuario no lo vería antes de escribir. */
  fflush(stdout);
}

void mostrar_resultado(double valor) { printf("%g\n", valor); }

void error_lexico(const char* mensaje, const char* lexema) {
  printf("%s: %s\n", mensaje, lexema);
}

void error_semantico(const char* mensaje) {
  printf("Error semántico: %s\n", mensaje);
}
