#ifndef CALC_H_INCLUDED
#define CALC_H_INCLUDED

#include <stdbool.h>

double valor_variable(const char* nombre);
double asignar(const char* nombre, double valor);
void liberar_diccionario(void);

bool division_valida(double divisor);
bool potencia(double base, double exponente, double* resultado);

void mostrar_prompt(void);
void mostrar_resultado(double valor);
void error_lexico(const char* mensaje, const char* lexema);
void error_semantico(const char* mensaje);

#endif
