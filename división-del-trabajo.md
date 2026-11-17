# División del trabajo

| Persona | Archivo | Líneas | Parte |
|---|---|---|---|
| 1 | `scanner.l` | 1 a 49 | Directivas de flex, definiciones (ER) y reglas de los tokens válidos |
| 2 | `scanner.l` | 50 a 72 | Reglas de errores léxicos |
| 2 | `calc.c` | 77 a 90 | Prompt, impresión de resultados y mensajes de error |
| 3 | `parser.y` | 1 a 37 | Directivas de bison, `%union`, tokens, precedencia y asociatividad |
| 4 | `parser.y` | 39 a 67 | Reglas `sesion` y `linea` (recuperación de errores) y operaciones aritméticas |
| 4 | `parser.y` | 91 a 96 | `yyerror` |
| 5 | `parser.y` | 68 a 89 | Asignaciones (`=`, `+=`, `-=`, `*=`, `/=`) |
| 5 | `calc.c` | 56 a 75 | Controles semánticos (división por cero y potencia) |
| 6 | `calc.c` | 1 a 54 | Diccionario de variables y autodeclaración |
| 6 | `calc.h` | 1 a 18 | Declaraciones de `calc` |
| 7 | `main.c` | 1 a 14 | `main` |
| 7 | `makefile` | 1 a 41 | Construcción del proyecto, `test`, `format` y `clean` |
| 7 | `.gitignore` | 1 a 8 | Archivos ignorados |
| 7 | `readme.md` | 1 a 67 | Carátula del TP |
| 7 | `ejemplos/entrada.txt` | 1 a 17 | Ejemplo dado por la consigna |
| 7 | `ejemplos/salida.txt` | 1 a 18 | Ejemplo dado por la consigna |
| 7 | `ejemplos/ejecución.txt` | 1 a 32 | Ejemplo dado por la consigna |
