# Trabajo Práctico N.º 3 — Calculadora

**UTN FRBA — Sintaxis y Semántica de los Lenguajes — Curso 26-003 — Grupo XX**

| Legajo | Apellido y nombre |
|--------|-------------------|
| _completar_ | _completar_ |
| _completar_ | _completar_ |

Fecha de entrega: 25 de noviembre de 2026.

Calculadora interactiva implementada con **flex** (scanner), **bison** (parser) y **C** (rutinas semánticas), a partir de la gramática de la calculadora del TP2.

## Archivos

| Archivo | Contenido |
|---------|-----------|
| `main.c` | `main`: muestra el primer prompt y llama a `yyparse` |
| `scanner.l` | Definiciones de flex: tokens y errores léxicos |
| `parser.y` | Definiciones de bison: gramática achatada, precedencia, acciones y recuperación de errores |
| `calc.c` / `calc.h` | Rutinas semánticas y diccionario de variables |
| `makefile` | Construcción del proyecto |
| `DOCUMENTACION.md` | Explicación detallada de todo el TP |
| `ejemplos/` | Ejemplos de la cátedra: `entrada.txt`, `salida.txt` (salida esperada) y `ejecución.txt` (sesión interactiva) |
| `build/` | Se crea al compilar: fuentes generados por flex y bison, objetos y el ejecutable `calc` (no se versiona) |

## Compilar y usar

Hacen falta `flex`, `bison`, `clang` y `make` (y `clang-format` para `make format`).

```sh
make                       # genera build/calc (con -g -O0, para depurar)
./build/calc               # modo interactivo (Ctrl+D para salir)
./build/calc < ejemplos/entrada.txt  # con un archivo de entrada
make test                  # corre el ejemplo y lo compara con la salida esperada
make clean                 # borra la carpeta build/
make run                   # compila y ejecuta
make format                # da formato estilo Google a los fuentes C
```

Ejemplo:

```
> b = 2.3
2.3
> a = b += 1
3.3
> 2^-3+2
2.125
> @@#;@
Error léxico: cadena desconocida: @@#;@
> 2 * * 3
syntax error, unexpected '*', expecting NUM or ID or '-' or '('
```

Con `ejemplos/entrada.txt`, la salida coincide con `ejemplos/salida.txt` (`make test` lo verifica). La sesión interactiva da lo mismo que `ejemplos/ejecución.txt`.

## Resumen de decisiones

- **Gramática achatada**: una sola regla `expresion`, con la precedencia y la asociatividad declaradas con `%right`, `%left` y `%precedence`, y `%prec NEG` para el menos unario.
- **Variables** autodeclaradas al primer uso con valor 0 (diccionario en `calc.c`).
- **Errores léxicos**: cadena desconocida (obligatorio), y además identificador inválido, constante inválida y REAL inválido. La línea se descarta completa.
- **Errores sintácticos**: recuperación con `linea: error '\n'`, sin `yyerrok`.
- **Errores semánticos**: división por cero (`/` y `/=`) y potencias sin resultado real, con `YYERROR`.
- Una línea con error no tiene efectos (no asigna nada).

El detalle de todo esto está en [DOCUMENTACION.md](DOCUMENTACION.md).
