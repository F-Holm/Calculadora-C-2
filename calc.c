#include "calc.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct Simbolo {
  char* nombre;
  double valor;
  struct Simbolo* sig;
} Simbolo;

static Simbolo* diccionario = NULL;

static Simbolo* buscar(const char* nombre) {
  for (Simbolo* s = diccionario; s != NULL; s = s->sig) {
    if (strcmp(s->nombre, nombre) == 0) return s;
  }
  return NULL;
}

static Simbolo* buscar_o_declarar(const char* nombre) {
  Simbolo* s = buscar(nombre);
  if (s != NULL) return s;

  s = malloc(sizeof *s);
  if (s == NULL || (s->nombre = strdup(nombre)) == NULL) {
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

bool division_valida(double divisor) {
  if (divisor == 0.0) {
    error_semantico("división por cero");
    return false;
  }
  return true;
}

bool potencia(double base, double exponente, double* resultado) {
  if (base == 0.0 && exponente < 0.0) {
    error_semantico("división por cero");
    return false;
  }
  if (base < 0.0 && exponente != floor(exponente)) {
    error_semantico("potencia sin resultado real");
    return false;
  }
  *resultado = pow(base, exponente);
  return true;
}

void mostrar_prompt(void) {
  printf("> ");
  fflush(stdout);
}

void mostrar_resultado(double valor) { printf("%g\n", valor); }

void error_lexico(const char* mensaje, const char* lexema) {
  printf("%s: %s\n", mensaje, lexema);
}

void error_semantico(const char* mensaje) {
  printf("Error semántico: %s\n", mensaje);
}
