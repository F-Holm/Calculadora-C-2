/*
 * calc.h — Interfaz del módulo de rutinas semánticas de la calculadora.
 *
 * Este header es el "contrato" entre las tres partes del programa:
 *   - scanner.l (flex)  lo usa para informar los errores léxicos.
 *   - parser.y  (bison) lo usa en las acciones semánticas (valor de las
 *     variables, asignaciones, controles semánticos, impresión de resultados).
 *   - main.c            lo usa para mostrar el primer prompt y liberar memoria.
 *
 * La implementación (y el diccionario de variables, que queda oculto como
 * dato privado del módulo) está en calc.c. Ver también DOCUMENTACION.md.
 */
#ifndef CALC_H_INCLUDED
#define CALC_H_INCLUDED

#include <stdbool.h>

/* ---------------------------------------------------------------------------
 * Diccionario de variables (tabla de símbolos)
 * ---------------------------------------------------------------------------
 * Las variables se "autodeclaran" al primer uso con valor inicial 0: no
 * existe una sentencia de declaración. Cualquiera de las dos funciones de
 * abajo crea la variable si todavía no existe.
 */

/* Devuelve el valor de la variable `nombre`. Si no existía, la declara con
 * valor 0 y devuelve 0. */
double valor_variable(const char* nombre);

/* Asigna `valor` a la variable `nombre` (declarándola si hace falta) y
 * devuelve el valor asignado, porque en la calculadora la asignación es una
 * expresión (permite `a = b += 1`) y su valor se imprime. */
double asignar(const char* nombre, double valor);

/* Libera toda la memoria del diccionario. Se llama al terminar el programa. */
void liberar_diccionario(void);

/* ---------------------------------------------------------------------------
 * Controles semánticos
 * ---------------------------------------------------------------------------
 * Devuelven false si la operación no se puede hacer. En ese caso ya
 * informaron el error, y el parser hace YYERROR para abandonar la línea.
 */

/* Controla que el divisor no sea cero (para '/' y '/='). */
bool division_valida(double divisor);

/* Calcula base^exponente en *resultado. Falla si el resultado no es un real:
 * 0 elevado a un exponente negativo (división por cero) o una base negativa
 * elevada a un exponente no entero (por ejemplo (-8)^0.5). */
bool potencia(double base, double exponente, double* resultado);

/* ---------------------------------------------------------------------------
 * Entrada / salida
 * ---------------------------------------------------------------------------
 */

/* Imprime el prompt "> " y vacía el buffer de salida. */
void mostrar_prompt(void);

/* Imprime el valor de una expresión (formato %g: 22, 7.6, 0.00237). */
void mostrar_resultado(double valor);

/* Informa un error léxico: imprime "<mensaje>: <lexema>". */
void error_lexico(const char* mensaje, const char* lexema);

/* Informa un error semántico: imprime "Error semántico: <mensaje>". */
void error_semantico(const char* mensaje);

#endif /* CALC_H_INCLUDED */
