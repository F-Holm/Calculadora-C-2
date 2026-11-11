# Documentación del TP3: calculadora con flex + bison

Este documento explica en detalle cómo está construida la calculadora y por qué se tomó cada decisión. Los fuentes también tienen comentarios, línea por línea donde hace falta. Acá está la visión de conjunto.

Índice:

1. [Herramientas](#1-herramientas)
2. [Arquitectura y flujo de datos](#2-arquitectura-y-flujo-de-datos)
3. [El scanner (`scanner.l`)](#3-el-scanner-scannerl)
4. [El parser (`parser.y`)](#4-el-parser-parsery)
5. [Rutinas semánticas y diccionario (`calc.c` / `calc.h`)](#5-rutinas-semánticas-y-diccionario-calcc--calch)
6. [`main.c`](#6-mainc)
7. [Manejo de errores](#7-manejo-de-errores)
8. [El `makefile`](#8-el-makefile)
9. [Pruebas](#9-pruebas)
10. [Limitaciones conocidas](#10-limitaciones-conocidas)

---

## 1. Herramientas

| Herramienta | Para qué | Versión probada |
|---|---|---|
| `flex` | Genera el scanner (`yylex`) a partir de `scanner.l` | 2.6.4 |
| `bison` | Genera el parser (`yyparse`) a partir de `parser.y` | 3.8.2 |
| `clang` | Compila y enlaza los fuentes C (`CC = clang` en el makefile; con `make CC=gcc` se usa gcc, que también compila sin warnings) | 23 |
| `make` | Ejecuta el `makefile` | 4.4 |
| `clang-format` | Sólo para `make format` (opcional) | 23 |
| `valgrind` | Para buscar pérdidas de memoria (opcional) | — |

Si faltan, se instalan así:

```sh
# Arch / Manjaro / CachyOS
sudo pacman -S --needed base-devel clang valgrind
# Debian / Ubuntu / WSL
sudo apt install build-essential flex bison clang clang-format valgrind
```

`base-devel` y `build-essential` ya traen `make`, y en Arch también `flex` y `bison`. En Arch, el paquete `clang` incluye `clang-format`.

Gracias a las directivas de los fuentes (ver 3.1 y 4.1), las herramientas se invocan **sin opciones**: `flex scanner.l` y `bison parser.y`. Es lo que pide la consigna.

---

## 2. Arquitectura y flujo de datos

### 2.1 Construcción

Los fuentes escritos a mano están en la raíz del repo. **Todo lo que se genera al compilar va a la carpeta `build/`**, que crea el makefile:

```
parser.y  ──bison──►  build/parser.c  +  build/parser.h   (tokens, YYSTYPE, yylval, yyparse)
scanner.l ──flex───►  build/scanner.c +  build/scanner.h  (yylex, yytext, yyin)

main.c ──────────┐
calc.c ──────────┤──clang -c──► build/*.o ──clang──► build/calc  (-lm)
build/parser.c ──┤
build/scanner.c ─┘
```

La raíz queda limpia (sólo fuentes y documentación), `make clean` se reduce a borrar `build/`, y `.gitignore` ignora la carpeta entera.

Las rutas `build/...` están escritas en las directivas de `scanner.l` y `parser.y` (ver 3.1 y 4.1). Son relativas al directorio desde el que se invoca la herramienta, que es la raíz del repo, donde corre `make`.

Los headers se cruzan:

- `scanner.l` incluye **`parser.h`** para conocer los códigos de los tokens (`NUM`, `ID`, `MAS_IGUAL`…) y la variable `yylval`, donde deja el valor de cada token.
- `parser.y` incluye **`scanner.h`** para conocer `yylex`, la función a la que llama para pedir tokens.
- Los dos incluyen **`calc.h`** (rutinas semánticas). `main.c` incluye `calc.h`, `parser.h` (para `yyparse`) y `scanner.h` (para `yylex_destroy`).

### 2.2 Ejecución

```
main ──► mostrar_prompt() ──► yyparse()
                                 │  (repite hasta EOF)
                                 ├──► yylex()  ──► devuelve un token, valor en yylval
                                 ├──► desplaza / reduce según la tabla LALR(1)
                                 └──► al reducir, ejecuta la acción semántica
                                       (calc.c: valores, asignaciones, controles,
                                        impresión del resultado y del prompt)
main ◄── yyparse devuelve 0 ── liberar_diccionario(), yylex_destroy()
```

Cada vez que el parser termina una línea, imprime el resultado (si corresponde) y el prompt `> ` de la siguiente.

Como la entrada se lee de `stdin`, el programa anda igual en forma interactiva o con un archivo redirigido (`./build/calc < ejemplos/entrada.txt`). En el segundo caso no aparece el eco de lo tipeado, y por eso `salida.txt` muestra `> 22` en una sola línea.

---

## 3. El scanner (`scanner.l`)

### 3.1 Opciones

| Directiva | Efecto |
|---|---|
| `%option header-file="build/scanner.h"` | Genera el header para bison, dentro de `build/` |
| `%option outfile="build/scanner.c"` | Nombre y carpeta del fuente generado (si no, `lex.yy.c` en el directorio actual) |
| `%option noinput` / `nounput` | No genera `input()` ni `yyunput()`, así el compilador no avisa "función definida y no usada" (sugerencia de la consigna) |
| `%option noyywrap` | Al llegar a EOF no llama a `yywrap()`. Así no hace falta `-lfl` |

El bloque `%top{ #define _POSIX_C_SOURCE 200809L }` va al principio de `build/scanner.c`. El código que genera flex usa `fileno()` e `isatty()`, que son POSIX y no C estándar. Al compilar con `-std=c23 -pedantic-errors`, sin esa definición los headers del sistema no las declaran y la compilación falla.

### 3.2 Definiciones (ER con nombre)

Salen de la gramática léxica del TP2:

| Nombre | ER | Viene de |
|---|---|---|
| `digito` | `[0-9]` | dígito |
| `letra` | `[a-zA-Z]` | letra |
| `entero` | `{digito}+` | `entero: dígito \| entero dígito` |
| `exponente` | `[eE][+-]?{entero}` | `(e\|E)(+\|-)opt entero` |
| `fraccion` | `{entero}\.{entero}?\|{entero}?\.{entero}` | `entero . entero_opt \| entero_opt . entero` |
| `real` | `{entero}{exponente}\|{fraccion}{exponente}?` | `entero exponente \| fracción exponente_opt` |
| `ident` | `{letra}({letra}\|{digito})*` | identificador |
| `nosep` | `[^ \t\r\n+\-*/^=()]` | (auxiliar) un carácter que **no** separa lexemas |

flex expande `{nombre}` **entre paréntesis**, así que `{real}` se comporta como una unidad aunque adentro tenga `|`.

### 3.3 Reglas y desempate

flex aplica dos criterios cuando varias reglas emparejan:

1. gana el lexema **más largo** (*maximal munch*);
2. a igual largo, gana la regla **escrita primero**.

Por eso las reglas correctas van arriba y las de error abajo. Una regla de error sólo gana cuando su lexema es **más largo** que el que toma la regla correcta, o sea, cuando el lexema tiene caracteres de más.

| # | Patrón | Token / acción | Ejemplo |
|---|---|---|---|
| 1 | `{ident}` | `ID`, con `yylval.id = strdup(yytext)` | `a`, `x2` |
| 2 | `{entero}\|{real}` | `NUM`, con `sscanf(yytext, "%lf", &yylval.num)` | `13.25`, `2.37e-3`, `.5`, `2.` |
| 3 | `"+="` `"-="` `"*="` `"/="` | `MAS_IGUAL`… | |
| 4 | `[-+*/^=()]` | el carácter mismo (`'+'`, `'('`…) | |
| 5 | `\n` | `'\n'`: termina la línea | |
| 6 | `[ \t\r]+` | se descarta (`\r` admite archivos con fin de línea de Windows) | |
| 7 | `{letra}{nosep}+` | *Error léxico: identificador inválido* | `a#2.4` |
| 8 | `{real}{nosep}+` | *Error léxico REAL inválido* | `2.3.4a2.3` |
| 9 | `{entero}{nosep}+` | *Error léxico: constante inválida* | `12a3` |
| 10 | `{nosep}+` | *Error léxico: cadena desconocida* | `@@#;@` |

Cómo se resuelven algunos casos:

- `abc`: emparejan la 1, la 7 y la 10, todas con largo 3. Gana la **1**, que está primero.
- `2.37e-3`: la 2 toma los 7 caracteres. La 8 sólo llega a `2.37e`, porque el `-` es un separador. Gana la **2**.
- `2.3.4a2.3`: la 2 toma sólo `2.3`, mientras que la 8 toma los 9 caracteres. Gana la **8**.
- `2e3a`: la 8 y la 9 emparejan los 4 caracteres. Gana la **8** (REAL inválido), que está antes.
- `12a3`: el `12a3` completo no es un real, así que la 8 no lo toma entero. La 9 sí. Gana la **9**.
- `@@#;@`: sólo la 10 lo toma entero.
- `.` suelto: no es número, así que gana la 10 (cadena desconocida).

Con `nosep`, la regla de error toma **todo** el lexema mal formado hasta el próximo blanco u operador, y el mensaje muestra la cadena completa. La regla `{fracc}{inval}+` del ejemplo 07 de la cátedra cortaría `2.3.4a2.3` en `2.3.4` y `a2`.

Como todos los caracteres son o separadores (reglas 3 a 6) o `nosep` (regla 10), no hace falta una regla final `.`. Si se la agregara, flex avisaría que nunca puede aplicarse.

### 3.4 Errores léxicos: el token `LEXERR`

Al detectar un error, el scanner:

1. lo informa con `error_lexico(mensaje, yytext)` (en `calc.c`);
2. **devuelve `LEXERR`**, un token declarado en `parser.y` que ninguna regla usa.

Al recibir `LEXERR`, el parser tiene un error sintáctico seguro y se recupera con `linea: error '\n'`: descarta toda la línea (ver 7). Si el scanner simplemente ignorara el lexema inválido, `a = 3 @` se evaluaría como `a = 3` y la variable cambiaría de valor. Con `LEXERR` la línea no tiene ningún efecto.

### 3.5 `yytext` y `strdup`

`yytext` apunta al buffer interno de flex, que se pisa con el próximo token. Bison puede necesitar el nombre de un `ID` más tarde, por ejemplo en `a = ...`, cuando ya se leyó todo lo que sigue. Por eso el scanner guarda una **copia** con `strdup`, y el parser la libera con `free` cuando la termina de usar (ver 4.5).

---

## 4. El parser (`parser.y`)

### 4.1 Directivas

| Directiva | Efecto |
|---|---|
| `%code top { ... }` | Includes al principio de `build/parser.c` |
| `%code provides { void yyerror(...); }` | El prototipo va a `build/parser.h`, para los demás módulos |
| `%defines "build/parser.h"` | Genera el header en `build/` (equivale a `bison -d`) |
| `%output "build/parser.c"` | Nombre y carpeta del fuente generado (si no, `parser.tab.c`) |
| `%define parse.error verbose` | Mensajes del tipo `syntax error, unexpected '*', expecting NUM or ID or '-' or '('` |
| `%define lr.default-reduction consistent` | Ver 4.6 |
| `%define parse.lac full` | Ver 4.6 |
| `%union { double num; char *id; }` | Tipo del valor semántico (`YYSTYPE`) |
| `%token <num> NUM`, `%token <id> ID` | Tokens con valor |
| `%token MAS_IGUAL "+=" ...` | Asignaciones compuestas, con alias para los mensajes |
| `%token LEXERR` | Error léxico (ver 3.4) |
| `%type <num> expresion` | Toda expresión vale un `double` |
| `%destructor { free($$); } <id>` | Libera los `ID` que bison descarta al recuperarse de un error |

### 4.2 Gramática achatada

La gramática del TP2 tenía un no terminal por nivel de precedencia (`aditiva`, `término`, `factor`, `potencia`, `primaria`). La consigna pide **achatarla**: una sola regla `expresion` con todas las alternativas, y la precedencia y la asociatividad declaradas aparte.

```
sesion    : %empty
          | sesion linea                 { mostrar_prompt(); }
          ;
linea     : '\n'
          | expresion '\n'               { mostrar_resultado($1); }
          | error '\n'
          ;
expresion : expresion '+' expresion
          | expresion '-' expresion
          | expresion '*' expresion
          | expresion '/' expresion
          | expresion '^' expresion
          | '-' expresion  %prec NEG
          | '(' expresion ')'
          | NUM
          | ID
          | ID '='  expresion
          | ID "+=" expresion  |  ID "-=" expresion
          | ID "*=" expresion  |  ID "/=" expresion
          ;
```

`sesion` es recursiva a izquierda, como recomienda bison: reduce línea por línea en vez de apilar toda la sesión.

### 4.3 Precedencia y asociatividad

Se declaran **de menor a mayor**. Los símbolos de una misma línea tienen la misma precedencia.

```
%right '=' "+=" "-=" "*=" "/="     menor
%left  '+' '-'
%left  '*' '/'
%precedence NEG                    (menos unario)
%right '^'                         mayor
```

Cómo resuelve bison los conflictos desplazar/reducir: compara la precedencia de la **regla** (la de su último terminal, o la indicada con `%prec`) con la del **token siguiente**. Si la regla tiene más precedencia, reduce. Si tiene menos, desplaza. Si es igual, decide la asociatividad: `%left` reduce y `%right` desplaza.

| Entrada | Decisión | Resultado |
|---|---|---|
| `2+4*5` | tras `2+4`, viene `*` (mayor que `+`): desplaza | `2+(4*5)` = 22 |
| `7-2-1` | tras `7-2`, viene `-` (igual, `%left`): reduce | `(7-2)-1` = 4 |
| `2^3^2` | tras `2^3`, viene `^` (igual, `%right`): desplaza | `2^(3^2)` = 512 |
| `-2^2` | tras `-2`, viene `^` (mayor que `NEG`): desplaza | `-(2^2)` = -4 |
| `2*-3` | `NEG` tiene más precedencia que `*` | `2*(-3)` = -6 |
| `2^-3+2` | en `2 ^ -3`, el `-` arranca una `expresion` (unario); después, `+` tiene menos precedencia: reduce | `(2^(-3))+2` = 2.125 |
| `a = 3 + b*2` | tras `a = 3`, viene `+` (mayor que `=`): desplaza | `a = (3 + b*2)` |
| `a = b += 1` | el lado izquierdo de una asignación es siempre un `ID` | `a = (b += 1)` |

**`NEG`** es un token que el scanner nunca devuelve. Sólo da nombre a un nivel de precedencia, y `%prec NEG` se lo asigna a la regla del menos unario. Así el mismo `'-'` se comporta como resta (precedencia de `+`) o como cambio de signo (más que `*`, menos que `^`), como en la gramática del TP2.

**El exponente negativo** (`2^-3`): en la gramática del TP2, `potencia: primaria ^ potencia` no lo admitía. La ejecución de ejemplo de la cátedra sí lo acepta, y la gramática achatada lo permite naturalmente, porque después de `^` puede venir cualquier `expresion`.

**Sobre `%right` en las asignaciones**: como el lado izquierdo siempre es un `ID`, la asociatividad a derecha la impone la forma misma de la regla. Bison usa sólo la *precedencia* de `=` (la menor, para que `a = 3 + b` desplace el `+`). Por eso `bison -Wall` avisa "useless associativity". Es un aviso informativo, y sin `-Wall` no aparece. Se dejó `%right` porque documenta la asociatividad, como en la teoría.

El resultado no tiene **ningún conflicto**: bison no informa nada al generar el parser.

**Orden de los tokens y mensajes**: en `expecting ...`, bison lista los tokens en el orden en que aparecen en el archivo. `NUM` está declarado antes que `ID`, y `'-'` (en `%left`) aparece antes que `'('` (que recién aparece en las reglas). Por eso el mensaje es igual al de la cátedra: `expecting NUM or ID or '-' or '('`.

### 4.4 Acciones semánticas

- `$$` es el valor del lado izquierdo y `$1`, `$2`, `$3` los del lado derecho.
- `ID`: `valor_variable($1)` devuelve el valor de la variable y la autodeclara con 0 si no existía.
- `ID '=' expresion`: `asignar($1, $3)`. Su valor es el asignado, así que se puede encadenar (`a = b = 5`) y se imprime (`b = 2.3` muestra `2.3`).
- `ID "+=" expresion`: `asignar($1, valor_variable($1) + $3)`, y análogo para `-=`, `*=` y `/=`.
- `/` y `/=`: antes de dividir, `division_valida($3)`. Si falla, `YYERROR`.
- `^`: `potencia($1, $3, &$$)`. Si falla, `YYERROR`.
- `linea: expresion '\n'`: `mostrar_resultado($1)` imprime con `%g`.
- `sesion: sesion linea`: `mostrar_prompt()` imprime el prompt de la línea siguiente.

### 4.5 Memoria de los identificadores

Cada `ID` trae un `char *` creado con `strdup` en el scanner. Se libera en tres lugares:

1. **En la acción** que usa el `ID`, con `free($1)` después de usarlo.
2. **Antes de `YYERROR`** en `/=`. `YYERROR` **no** llama al destructor de los símbolos de la regla que se está reduciendo, así que hay que liberarlo a mano.
3. **Con `%destructor`**, cuando bison descarta un `ID` durante la recuperación de un error (por ejemplo, en `a 2 3`).

Se verificó con valgrind que no hay pérdidas (ver 9).

### 4.6 Que una línea con error no tenga efectos

Un parser LALR puede **reducir antes de detectar** que el token siguiente es inválido, y al reducir ejecuta la acción. Sin cuidado, `q = 3 @` o `a = 5 )` harían la asignación y recién después informarían el error. Hay dos causas, y se corrigen con dos directivas:

1. **Reducciones por defecto.** Para achicar las tablas, bison reduce en muchos estados sin mirar el token siguiente. Con `%define lr.default-reduction consistent`, eso sólo pasa en los estados con una única acción posible. Las reducciones que siguen a un `'\n'` son de ese tipo, así que en modo interactivo el resultado se muestra apenas se aprieta Enter, sin esperar la línea siguiente.
2. **Fusión de estados de LALR.** LALR fusiona estados con el mismo núcleo, y entonces `)` parece válido después de `a = 5` (lo sería dentro de `(a = 5)`). Con `%define parse.lac full` (*LookAhead Correction*), antes de reducir, bison simula en una pila auxiliar si el token siguiente se va a poder desplazar. Si no, informa el error en ese momento, sin ejecutar ninguna acción. De paso, la lista `expecting ...` sale más precisa.

Prueba: `q = 3 @` seguido de `q` muestra `0`, y `a = 5 )` seguido de `a` muestra `0`.

### 4.7 `yyerror`

Bison la llama con el mensaje ya armado. La implementación lo imprime en `stdout`, salvo cuando el token de lookahead (la variable global `yychar` del parser) es `LEXERR`: en ese caso, el error sintáctico es consecuencia de un error léxico que el scanner ya informó, y no hace falta un segundo mensaje.

---

## 5. Rutinas semánticas y diccionario (`calc.c` / `calc.h`)

La consigna pide agrupar acá las rutinas semánticas y el diccionario. `calc.h` es la interfaz pública y `calc.c` la implementación.

### 5.1 Diccionario

Es una lista simplemente enlazada de nodos `{ nombre, valor, sig }`, declarada `static` (vinculación interna). Así nadie fuera de `calc.c` puede tocarla directamente: sólo a través de las funciones de `calc.h`.

| Función | Qué hace |
|---|---|
| `buscar` (privada) | Búsqueda lineal con `strcmp` |
| `buscar_o_declarar` (privada) | Si no está, crea el nodo con `valor = 0` (**autodeclaración**) y lo inserta al principio de la lista. El nombre se copia con `strdup`, porque el parser libera el suyo |
| `valor_variable(nombre)` | Lee el valor. Autodeclara si hace falta |
| `asignar(nombre, valor)` | Escribe el valor. Autodeclara si hace falta. Devuelve el valor |
| `liberar_diccionario()` | Libera todos los nodos al terminar |

Una lista alcanza para la cantidad de variables de una sesión interactiva. Si hiciera falta, se podría reemplazar por una tabla hash sin tocar el parser, porque la interfaz es la misma.

### 5.2 Controles semánticos

| Función | Error que detecta | Mensaje |
|---|---|---|
| `division_valida(divisor)` | `x / 0`, `x /= 0` | `Error semántico: división por cero` |
| `potencia(base, exp, &res)` | `0 ^ negativo` (es `1/0`) | `Error semántico: división por cero` |
| | `negativo ^ no entero`, como `(-8)^0.5` (resultado complejo) | `Error semántico: potencia sin resultado real` |

Devuelven `false` cuando falla el control, después de informarlo. El parser responde con `YYERROR`.

### 5.3 Salida

- `mostrar_resultado`: `printf("%g\n")`, que da `22`, `7.6`, `0.00237` y `2.125`, como en `salida.txt`.
- `mostrar_prompt`: `printf("> ")` más `fflush(stdout)`. El prompt no termina en `\n`, y sin el `fflush` quedaría en el buffer: el usuario no lo vería antes de escribir.
- `error_lexico` y `error_semantico` imprimen en `stdout`, igual que los resultados. Así quedan intercalados en el orden correcto, como en `salida.txt`.

---

## 6. `main.c`

1. `mostrar_prompt()` imprime el primer `> `. Los siguientes los imprime el parser.
2. `yyparse()` analiza toda la entrada. Gracias a la recuperación de errores, devuelve 0 aun si hubo errores en algunas líneas.
3. `putchar('\n')` evita que el prompt de la consola quede pegado al último `> ` al salir.
4. `liberar_diccionario()` y `yylex_destroy()` (libera los buffers internos de flex, para que valgrind no informe memoria "still reachable").
5. Devuelve el resultado de `yyparse` como código de salida.

---

## 7. Manejo de errores

| Tipo | Quién lo detecta | Cómo se informa | Cómo se recupera |
|---|---|---|---|
| **Léxico** | Reglas de error de `scanner.l` | `error_lexico` | Devuelve `LEXERR`, lo que provoca un error sintáctico silencioso y la regla `error '\n'` descarta la línea |
| **Sintáctico** | `yyparse` | `yyerror`, con el mensaje *verbose* de bison | `linea: error '\n'` |
| **Semántico** | Acciones de `parser.y` (con `calc.c`) | `error_semantico` | `YYERROR` |

**La regla `error '\n'`.** Ante un error, bison:

1. llama a `yyerror` (salvo en `YYERROR`, que no lo hace ni incrementa `yynerrs`);
2. desapila estados hasta uno en el que se pueda desplazar el token especial `error`, que es el estado del principio de una `linea`;
3. descarta tokens de la entrada hasta encontrar el `'\n'`;
4. reduce `linea: error '\n'` y sigue con la línea siguiente.

El programa no termina con el primer error, como pide la consigna. Y **no se usa `yyerrok`**, como también pide la consigna (ver la limitación en 10).

**`YYERROR` para los errores semánticos.** La consigna pide usar `YYERROR` para dejar de analizar la línea con un error semántico. `YYERROR` inicia la misma recuperación, "como si" hubiera habido un error sintáctico, pero sin mensaje de bison. El mensaje lo da la rutina semántica.

---

## 8. El `makefile`

Sigue el estilo del ejemplo de la cátedra: los nombres de los archivos están escritos directamente, hay una regla por archivo y las dependencias se ponen a mano.

| Objetivo | Qué hace |
|---|---|
| `make` | Construye `build/calc` (es el primer objetivo) |
| `make run` | Construye y ejecuta en modo interactivo |
| `make test` | Corre `ejemplos/entrada.txt` y compara la salida con `ejemplos/salida.txt` (ver 9) |
| `make format` | `clang-format -i --style=Google main.c calc.c calc.h` |
| `make clean` | Borra la carpeta `build/` entera |

Detalles:

- **`CFLAGS = -g -O0 -Wall -Wextra -pedantic-errors -std=$(STD) -I. -Ibuild -c`** (con `STD = c23`). Son las opciones del ejemplo de la cátedra, más:
  - `-O0`: sin optimizar. Junto con `-g`, sirve para depurar con `gdb` o `valgrind`.
  - `-Wextra`: warnings adicionales.
  - Dos rutas de búsqueda de headers. `-Ibuild` hace que `main.c` encuentre `parser.h` y `scanner.h`, que se generan en `build/`. `-I.` hace que los fuentes generados en `build/` encuentren `calc.h`, que está en la raíz.

  Todo compila **sin warnings**, incluido el código que generan flex y bison.
- **Dependencias.** Cada `.o` lista su `.c` y todos los `.h` que incluye. Si cambia `calc.h`, se recompilan los cuatro `.o`. Si cambia `parser.y`, bison regenera `parser.c` y `parser.h`, y se recompila todo lo que incluye `parser.h`. Esto último es importante: si `scanner.o` no se recompilara, el scanner seguiría usando los números de token viejos. Si se agrega un `#include` en algún fuente, hay que agregar el header en su regla.
- **`build/parser.c build/parser.h: parser.y`** es una regla con dos objetivos: un solo `bison parser.y` produce ambos. Los nombres y la carpeta salen de las directivas de `parser.y`, por eso no hacen falta opciones. Lo mismo vale para flex con `scanner.l`.
- **`mkdir -p build`** crea la carpeta antes de escribir en ella. La `-p` hace que no falle si ya existe. Está en las reglas que pueden ejecutarse primero: las de bison y flex, y la de `calc.o`, que es la única que no depende de los archivos generados.
- **`-lm`** hace falta por `pow` y `floor` (`math.h`).
- **`make test`** usa `diff -Z`, que ignora los espacios al final de cada línea (ver 9). Si las salidas coinciden, imprime `OK`. Si no, muestra las diferencias y make termina con error.
- **`make format`** formatea sólo `main.c`, `calc.c` y `calc.h`. `scanner.l` y `parser.y` **no** se formatean: clang-format no entiende la sintaxis de flex y bison (`%%`, `%token`, reglas), y la rompería. Los archivos generados tampoco, porque se regeneran en cada compilación.
- **`.PHONY`** marca los objetivos que no son archivos, para que se ejecuten siempre.

---

## 9. Pruebas

**Ejemplos de la cátedra (carpeta `ejemplos/`).** Están copiados textualmente del material de la cátedra, que los transcribió de capturas de pantalla:

| Archivo | Qué es |
|---|---|
| `entrada.txt` | 17 líneas de prueba |
| `salida.txt` | Salida esperada de `./build/calc < ejemplos/entrada.txt` |
| `ejecución.txt` | Una sesión interactiva de ejemplo (no incluye la línea `12a3`) |

Resultados:

- **`make test`** corre la entrada y compara la salida con `salida.txt` usando `diff`. **Coinciden.** La comparación ignora los espacios al final de cada línea, porque hay una única diferencia byte a byte, y es de la transcripción: la última línea del archivo es `>`, mientras que el programa imprime el prompt `> ` con su espacio. En una captura de pantalla ese espacio no se ve.
- **`ejecución.txt`** se verificó tipeando cada entrada en una terminal simulada (un pseudo-terminal) y comparando la sesión completa: es **idéntica**. El resultado y el prompt aparecen apenas se aprieta Enter.

**Casos adicionales** (todos verificados):

| Entrada | Salida |
|---|---|
| `1/0` | `Error semántico: división por cero` |
| `x /= 0` | `Error semántico: división por cero` (x no cambia) |
| `0^-1` | `Error semántico: división por cero` |
| `(-8)^0.5` | `Error semántico: potencia sin resultado real` |
| `-2^2` | `-4` |
| `2^3^2` | `512` |
| `7-2-1`, `8/2/2` | `4`, `2` |
| `3 - -2`, `2*-3` | `5`, `-6` |
| `-(2+3)*2` | `-10` |
| `a = b = 5` | `5` (a y b valen 5) |
| `z += 2`, luego `z *= 3` | `2`, `6` (z se autodeclara con 0) |
| `1e3 + .5 + 2.` | `1002.5` |
| `2 + @ 3` | sólo `Error léxico: cadena desconocida: @` |
| `q = 3 @`, luego `q` | el error léxico, luego `0` (no se asignó) |
| `a = 5 )`, luego `a` | `syntax error, unexpected ')'`, luego `0` |
| `12#` | `Error léxico: constante inválida: 12#` |
| `ab.c` | `Error léxico: identificador inválido: ab.c` |
| línea vacía | sólo el prompt |

**Memoria.** `valgrind --leak-check=full --show-leak-kinds=all ./build/calc < ejemplos/entrada.txt` informa 0 pérdidas, 0 bloques "still reachable" y 0 errores, con `entrada.txt` y con los casos de arriba.

---

## 10. Limitaciones conocidas

- **Errores silenciados después de otro error (por no usar `yyerrok`).** Después de recuperarse de un error, bison no informa nuevos errores sintácticos hasta haber desplazado 3 tokens seguidos con éxito. La recuperación misma desplaza `error` y `'\n'`, así que si la línea siguiente tiene un error sintáctico **en sus dos primeros tokens** (por ejemplo `* 3` justo después de una línea errónea), esa línea igual se descarta, pero sin mensaje. `yyerrok` resolvería esto, pero la consigna prohíbe usarlo. Los errores léxicos y semánticos siempre se informan, porque no dependen de `yyerror`.
- **Última línea sin `'\n'`.** Si el archivo termina sin fin de línea, la última expresión da `syntax error, unexpected end of file`, porque la gramática exige que cada línea termine en `'\n'`. Lo mismo pasa si se aprieta Ctrl+D a mitad de una línea.
- **Precisión.** Los valores son `double`, con la precisión y el redondeo de punto flotante (por ejemplo, `0.1 + 0.2` da `0.3` con `%g`, pero internamente es `0.30000000000000004`).
