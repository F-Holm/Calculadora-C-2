# Guía para la defensa oral del TP3: la calculadora

Esta guía está pensada para alguien que **no sabe flex, ni bison, ni la teoría de scanners y parsers**. Arranca desde cero, explica la teoría mínima necesaria y después recorre el TP archivo por archivo. Al final hay una lista de preguntas probables con sus respuestas.

Si tenés poco tiempo, leé las secciones 1, 2, 5, 6 y 10, y después la parte del código que te tocó defender (sección 11).

## Índice

1. [Qué hace el programa](#1-qué-hace-el-programa)
2. [La idea general: un compilador en etapas](#2-la-idea-general-un-compilador-en-etapas)
3. [Teoría del análisis léxico (scanner)](#3-teoría-del-análisis-léxico-scanner)
4. [Teoría del análisis sintáctico (parser)](#4-teoría-del-análisis-sintáctico-parser)
5. [Cómo se comunican el scanner y el parser](#5-cómo-se-comunican-el-scanner-y-el-parser)
6. [flex y `scanner.l`, línea por línea](#6-flex-y-scannerl-línea-por-línea)
7. [bison y `parser.y`, línea por línea](#7-bison-y-parsery-línea-por-línea)
8. [Las rutinas semánticas: `calc.c`, `calc.h` y `main.c`](#8-las-rutinas-semánticas-calcc-calch-y-mainc)
9. [Manejo de errores](#9-manejo-de-errores)
10. [Seguimiento completo de ejemplos](#10-seguimiento-completo-de-ejemplos)
11. [Qué tiene que saber cada integrante](#11-qué-tiene-que-saber-cada-integrante)
12. [El `makefile` y cómo se compila](#12-el-makefile-y-cómo-se-compila)
13. [Preguntas probables y respuestas](#13-preguntas-probables-y-respuestas)
14. [Glosario](#14-glosario)

---

## 1. Qué hace el programa

Es una **calculadora interactiva**. Muestra un prompt `> `, el usuario escribe una expresión y aprieta Enter, y el programa muestra el resultado:

```
> 2+4*5
22
> b = 2.3
2.3
> a = b += 1
3.3
> a
3.3
> 2^-3+2
2.125
> @@#;@
Error léxico: cadena desconocida: @@#;@
> 2 * * 3
syntax error, unexpected '*', expecting NUM or ID or '-' or '('
```

Lo que sabe hacer:

- **Números** enteros (`13`), con decimales (`13.25`, `.5`, `2.`) y con exponente (`2.37e-3`, que es 2,37 × 10⁻³).
- **Operadores**: `+`, `-`, `*`, `/`, `^` (potencia), el menos unario (`-x`) y paréntesis.
- **Variables**: nombres como `a` o `x2`. No hace falta declararlas: si se usan sin haberles asignado nada, valen 0.
- **Asignaciones**: `=`, `+=`, `-=`, `*=`, `/=`. Una asignación también es una expresión y devuelve el valor asignado, por eso `a = b += 1` funciona.
- **Errores**: informa errores léxicos (palabras mal formadas), sintácticos (palabras bien formadas pero en un orden que no tiene sentido) y semánticos (división por cero, potencias sin resultado real). Después de un error **sigue funcionando** con la línea siguiente.

---

## 2. La idea general: un compilador en etapas

Un compilador (o un intérprete, como esta calculadora) no procesa el texto de una sola vez. Lo hace en **etapas**, cada una con una responsabilidad:

```
  texto            tokens                   estructura           resultado
"a = 3 + b*2" ──► ID = NUM + ID * NUM ──► árbol / reducciones ──► 7.6
              SCANNER                  PARSER                RUTINAS SEMÁNTICAS
           (análisis léxico)      (análisis sintáctico)     (análisis semántico
               flex                     bison                 y evaluación, en C)
```

Una analogía con el castellano:

| Etapa | En castellano | En la calculadora |
|---|---|---|
| **Léxica** | ¿Las palabras existen? "gato" sí, "gxzq" no | ¿`2.37e-3` es un número válido? ¿`a#2.4` es un nombre válido? |
| **Sintáctica** | ¿Las palabras están bien ordenadas? "el gato come" sí, "come el el" no | ¿`2 + 3` está bien armado? ¿`2 * * 3` no? |
| **Semántica** | ¿Tiene sentido? "la piedra come" es gramatical pero raro | ¿`1/0` se puede calcular? |

En el TP:

- El **scanner** lo genera **flex** a partir de `scanner.l`. Es una función de C llamada `yylex()`.
- El **parser** lo genera **bison** a partir de `parser.y`. Es una función de C llamada `yyparse()`.
- Las **rutinas semánticas** están escritas a mano en `calc.c` (con su interfaz en `calc.h`).
- `main.c` arranca todo llamando a `yyparse()`.

**flex y bison son generadores de código.** No forman parte del programa final: se usan para *escribir* parte del programa. Uno les da una descripción de alto nivel (expresiones regulares, una gramática) y ellos producen un archivo `.c` con el scanner o el parser ya programado. Programar eso a mano sería largo y propenso a errores.

```
scanner.l ──flex──►  build/scanner.c + build/scanner.h
parser.y  ──bison──► build/parser.c  + build/parser.h

main.c + calc.c + build/scanner.c + build/parser.c ──clang──► build/calc (el ejecutable)
```

---

## 3. Teoría del análisis léxico (scanner)

### 3.1 Lexema, token y categoría léxica

- Un **lexema** es un pedazo concreto del texto de entrada: `2.37e-3`, `a`, `+=`.
- Un **token** es la *categoría* a la que pertenece ese lexema, a veces con un valor asociado: el lexema `2.37e-3` es el token `NUM` con valor `0.00237`; el lexema `a` es el token `ID` con valor `"a"`; el lexema `+=` es el token `MAS_IGUAL`, sin valor.

Al parser no le importa si el número era `2` o `2.37e-3`: para decidir si la frase está bien armada sólo necesita saber que "acá hay un número". El valor sólo importa después, para calcular.

El scanner **lee caracteres y produce tokens**. Además, **descarta** lo que no le interesa al parser (los espacios y tabulaciones).

### 3.2 Expresiones regulares

Cada categoría léxica se describe con una **expresión regular** (ER), que es una forma compacta de describir un conjunto de cadenas. La notación que usa flex:

| ER | Significa | Ejemplos que la cumplen |
|---|---|---|
| `abc` | exactamente "abc" | `abc` |
| `[0-9]` | un carácter del rango (un dígito) | `0`, `7` |
| `[a-zA-Z]` | una letra | `a`, `Q` |
| `[^ \t]` | cualquier carácter **excepto** espacio y tab | `x`, `#` |
| `x*` | cero o más `x` | ``, `x`, `xxx` |
| `x+` | una o más `x` | `x`, `xxx` |
| `x?` | `x` opcional (cero o una vez) | ``, `x` |
| `x\|y` | `x` o `y` | `x`, `y` |
| `(xy)+` | agrupa | `xy`, `xyxy` |
| `\.` | un punto literal (sin `\`, el `.` significa "cualquier carácter") | `.` |
| `{nombre}` | la ER definida antes con ese nombre | |

Por ejemplo, `[0-9]+` describe los enteros: uno o más dígitos.

### 3.3 Lenguajes regulares y autómatas

Los conjuntos de cadenas que se pueden describir con una ER se llaman **lenguajes regulares** (tipo 3 en la jerarquía de Chomsky). Todo lenguaje regular se puede reconocer con un **autómata finito**: una máquina con una cantidad fija de estados que lee de a un carácter y cambia de estado.

Eso es lo que hace flex por dentro: **convierte las ER en un autómata finito determinístico (AFD)** y genera una tabla de transiciones en C. Nosotros nunca vemos el autómata; escribimos las ER.

Ejemplo: un autómata para enteros (`[0-9]+`):

```
         dígito          dígito
  (q0) ─────────► ((q1)) ◄──┐
                     └──────┘
```

`q0` es el estado inicial y `q1` es de aceptación: si al terminar de leer el lexema estoy en `q1`, el lexema es un entero.

### 3.4 Por qué el léxico es regular y la sintaxis no

Las ER no pueden "contar". No hay ER que describa "tantos `(` como `)`", porque para eso hace falta memoria ilimitada (un autómata finito tiene una cantidad fija de estados). Por eso el balanceo de paréntesis y la estructura de las expresiones se dejan al parser, que usa una herramienta más potente: las gramáticas libres de contexto.

### 3.5 Cómo elige flex cuando varias ER coinciden

Esto es **clave** para entender el TP. Cuando el texto puede cortarse de varias maneras, flex aplica dos reglas:

1. **Gana el lexema más largo** (en inglés, *maximal munch* o "el mordisco más grande"). Si en la entrada está `+=`, gana la regla de `+=` (2 caracteres) y no la de `+` (1 carácter).
2. **Si empatan en largo, gana la regla escrita primero** en el archivo.

Gracias a esto, en el TP las reglas buenas van arriba y las de error abajo (ver 6.4).

---

## 4. Teoría del análisis sintáctico (parser)

### 4.1 Gramáticas libres de contexto

La estructura de las expresiones se describe con una **gramática libre de contexto** (GLC, tipo 2 en la jerarquía de Chomsky), escrita en notación BNF. Una gramática tiene:

- **Terminales**: los tokens que entrega el scanner (`NUM`, `ID`, `'+'`, `'\n'`…). Son las "hojas"; no se descomponen.
- **No terminales**: categorías sintácticas que se definen con reglas (`sesion`, `linea`, `expresion`).
- **Producciones** (reglas): dicen cómo se forma un no terminal. `expresion : expresion '+' expresion` significa "una expresión puede ser una expresión, un `+` y otra expresión".
- **Axioma** (símbolo inicial): el no terminal que representa la entrada completa. Acá es `sesion`.

Una gramática chiquita de ejemplo:

```
expresion : expresion '+' expresion
          | NUM
          ;
```

Dice que una expresión es un número, o dos expresiones sumadas. Como la regla se usa a sí misma (es **recursiva**), puede describir sumas de cualquier largo.

### 4.2 Derivaciones y árbol de análisis sintáctico

Para mostrar que `2 + 3` es una expresión, se parte del no terminal y se reemplaza usando las reglas hasta llegar a los tokens. Eso es una **derivación**:

```
expresion ⇒ expresion '+' expresion ⇒ NUM '+' expresion ⇒ NUM '+' NUM
```

Lo mismo se puede dibujar como un **árbol de análisis sintáctico** (árbol de derivación):

```
        expresion
       /    |    \
 expresion '+' expresion
     |            |
    NUM          NUM
    (2)          (3)
```

El trabajo del parser es, justamente, **encontrar ese árbol** (o decir que no existe, y entonces hay un error sintáctico).

### 4.3 Ambigüedad, precedencia y asociatividad

Una gramática es **ambigua** si alguna entrada tiene **dos árboles distintos**. Con la regla `expresion : expresion '+' expresion | expresion '*' expresion | NUM`, la entrada `2 + 4 * 5` tiene dos árboles:

```
     (2 + 4) * 5 = 30                  2 + (4 * 5) = 22
          E                                  E
        / | \                              / | \
       E  *  E                            E  +  E
     / | \   |                            |   / | \
    E  +  E  5                            2  E  *  E
    |     |                                  |     |
    2     4                                  4     5
```

Los dos son válidos para la gramática, pero el resultado es distinto. Para elegir el correcto hacen falta dos conceptos:

- **Precedencia**: qué operador "agarra" primero. `*` tiene más precedencia que `+`, así que `2+4*5` es `2+(4*5)`.
- **Asociatividad**: qué pasa con operadores de la misma precedencia.
  - `-` es **asociativo a izquierda**: `7-2-1` es `(7-2)-1 = 4`, no `7-(2-1) = 6`.
  - `^` es **asociativo a derecha**: `2^3^2` es `2^(3^2) = 512`, no `(2^3)^2 = 64`.
  - `=` es **asociativo a derecha**: `a = b = 5` es `a = (b = 5)`.

Hay dos formas de resolver la ambigüedad:

1. **Escribir la gramática con un no terminal por nivel de precedencia** (gramática "en niveles"). Era lo que se hizo en el TP2: `aditiva`, `término`, `factor`, `potencia`, `primaria`. La gramática deja de ser ambigua, pero es más larga.
2. **Dejar la gramática ambigua y "achatada"** (un solo no terminal `expresion`) y **declarar aparte** la precedencia y la asociatividad. Bison lo permite y es lo que **pide la consigna del TP3**. Es más corto y más legible.

### 4.4 Parsers ascendentes y descendentes

Hay dos grandes familias de parsers:

- **Descendentes** (top-down, LL): arrancan desde el axioma y van "bajando" hasta los tokens. Es el método del *descenso recursivo* (una función de C por no terminal). No soportan reglas recursivas a izquierda (`E : E '+' T`), porque la función se llamaría a sí misma infinitamente.
- **Ascendentes** (bottom-up, LR): arrancan desde los tokens y los van agrupando hacia arriba hasta llegar al axioma. **Bison genera parsers ascendentes**, de tipo **LALR(1)**. Soportan sin problema la recursión a izquierda (de hecho, la prefieren).

**LALR(1)** significa: *Look-Ahead LR* con **1 token de anticipación**. "LR" = lee la entrada de izquierda a derecha (*Left to right*) y construye una derivación por derecha (*Rightmost*) al revés. El "(1)" significa que para decidir qué hacer mira **un solo token por adelantado** (el *lookahead*).

### 4.5 Cómo funciona un parser LR: desplazar y reducir

El parser tiene una **pila** y lee tokens de a uno. En cada paso hace una de estas acciones:

- **Desplazar** (*shift*): pone el token siguiente en la pila.
- **Reducir** (*reduce*): si lo que está arriba de la pila coincide con el lado derecho de una regla, lo saca y pone en su lugar el no terminal del lado izquierdo. **Al reducir, ejecuta la acción en C asociada a esa regla** (ahí se hacen las cuentas).
- **Aceptar**: llegó al axioma y se terminó la entrada.
- **Error**: con el token siguiente no hay nada válido que hacer.

Ejemplo con `2 + 3` y la gramática chiquita de 4.1:

| Pila | Entrada que falta | Acción |
|---|---|---|
| | `NUM(2) + NUM(3)` | desplazar `NUM` |
| `NUM` | `+ NUM(3)` | reducir `expresion : NUM` → vale 2 |
| `expresion` | `+ NUM(3)` | desplazar `+` |
| `expresion +` | `NUM(3)` | desplazar `NUM` |
| `expresion + NUM` | | reducir `expresion : NUM` → vale 3 |
| `expresion + expresion` | | reducir `expresion : expresion '+' expresion` → vale 2+3 = 5 |
| `expresion` | | aceptar |

Bison precalcula, para cada **estado** del parser y cada token posible, qué acción hacer. Esa es la **tabla LALR(1)**, que va dentro de `build/parser.c`.

### 4.6 Conflictos y cómo los resuelve bison

Con una gramática ambigua, en algún momento el parser no sabe qué hacer. Por ejemplo, con `2 + 4 * 5`, cuando la pila tiene `expresion + expresion` y el próximo token es `*`:

- ¿**Reduce** `expresion + expresion` ahora? Eso calcularía `(2+4)*5`.
- ¿O **desplaza** el `*` y sigue? Eso calcularía `2+(4*5)`.

Eso es un **conflicto desplazar/reducir** (*shift/reduce*). Bison lo resuelve con las declaraciones de precedencia:

1. Compara la precedencia de la **regla** que podría reducir (es la del último terminal de la regla; en este caso, la de `+`) con la del **token siguiente** (`*`).
2. Si el token siguiente tiene **más** precedencia, **desplaza**. Si tiene **menos**, **reduce**.
3. Si tienen **la misma**, decide la asociatividad: `%left` → reduce (agrupa a izquierda); `%right` → desplaza (agrupa a derecha).

En el ejemplo, `*` tiene más precedencia que `+`, así que desplaza y el resultado es 22.

Si no se declarara ninguna precedencia, bison avisaría "conflicts: N shift/reduce" y elegiría desplazar siempre, lo que daría resultados incorrectos. **En el TP, bison no informa ningún conflicto**: todos están resueltos por las declaraciones.

### 4.7 Acciones semánticas y valores semánticos

Cada símbolo de la pila puede llevar un **valor semántico**: un `NUM` lleva su `double`, un `ID` lleva el nombre, una `expresion` lleva el resultado calculado hasta ahí. En bison:

- `$1`, `$2`, `$3`… son los valores de los símbolos del lado derecho de la regla, en orden.
- `$$` es el valor que va a tener el lado izquierdo después de reducir.

```
expresion : expresion '+' expresion   { $$ = $1 + $3; }
//              $1      $2     $3
```

`$2` sería el `'+'`, que no tiene valor. Así, al reducir, la expresión de la izquierda pasa a valer la suma de las dos de la derecha. Como las reducciones ocurren de abajo hacia arriba en el árbol, **el cálculo se hace "solo"** mientras se analiza: esto se llama **traducción dirigida por la sintaxis**.

---

## 5. Cómo se comunican el scanner y el parser

**El parser es el que manda.** `main` llama a `yyparse()`, y `yyparse()` llama a `yylex()` cada vez que necesita un token nuevo:

```
main()
  └─► yyparse()  (bison)
        ├─► yylex()  (flex)  → devuelve el código del token
        │                      y deja el valor en la variable global yylval
        ├─► desplaza / reduce según la tabla
        └─► al reducir, ejecuta la acción (que llama a funciones de calc.c)
```

Los elementos de la comunicación:

| Elemento | Qué es | Quién lo define | Quién lo usa |
|---|---|---|---|
| `yylex()` | Función que devuelve el próximo token (un `int`) | flex (`scanner.c`) | bison |
| Códigos de token (`NUM`, `ID`, `MAS_IGUAL`…) | Números enteros. Los de un carácter (`'+'`, `'\n'`) usan su código ASCII; los con nombre, números a partir de 258 | bison (`parser.h`) | flex los devuelve |
| `yylval` | Variable global donde el scanner deja el **valor** del token | bison (`parser.h`, tipo `YYSTYPE` según el `%union`) | flex la escribe, bison la lee |
| `yytext` | Puntero al texto del lexema recién reconocido | flex | las acciones de flex |
| Fin de la entrada | `yylex()` devuelve 0 | flex | bison entiende "se terminó" |

Por eso los headers están cruzados: `scanner.l` incluye `parser.h` (para saber cuánto vale `NUM` y qué es `yylval`), y `parser.y` incluye `scanner.h` (para saber que existe `yylex`).

Ejemplo: para la línea `a = b += 1`, las llamadas sucesivas a `yylex()` devuelven:

| Lexema | Token devuelto | `yylval` |
|---|---|---|
| `a` | `ID` | `.id = "a"` |
| `=` | `'='` | — |
| `b` | `ID` | `.id = "b"` |
| `+=` | `MAS_IGUAL` | — |
| `1` | `NUM` | `.num = 1.0` |
| (Enter) | `'\n'` | — |

Los espacios no aparecen: el scanner los descarta.

---

## 6. flex y `scanner.l`, línea por línea

### 6.1 Estructura de un archivo de flex

Un archivo `.l` tiene **tres secciones separadas por `%%`**:

```
definiciones   (opciones, código C para el principio, ER con nombre)
%%
reglas         (patrón   { acción en C })
%%
código C del usuario   (en este TP está vacío)
```

Cada **regla** es una ER y una acción. Cuando flex reconoce un lexema con esa ER, ejecuta la acción. Si la acción hace `return X`, `yylex()` devuelve `X` al parser. Si no hace `return`, flex sigue leyendo (así se descartan los espacios).

### 6.2 Sección de definiciones

```c
%top{
#define _POSIX_C_SOURCE 200809L
}
```

`%top` pone ese código **al principio de todo** del `scanner.c` generado. El código que genera flex usa `fileno()` e `isatty()`, que son funciones POSIX, no del C estándar. Como compilamos con `-std=c23 -pedantic-errors`, sin este `#define` los headers del sistema no las declaran y la compilación falla.

```c
%{
#include <stdio.h>
#include <string.h>

#include "calc.h"
#include "parser.h"
%}
```

Lo que está entre `%{` y `%}` se copia tal cual al `.c`. `string.h` es por `strdup`, `calc.h` por `error_lexico`, `parser.h` por los códigos de token y `yylval`.

```
%option header-file="build/scanner.h"   genera scanner.h (para que bison conozca yylex)
%option outfile="build/scanner.c"       nombre del .c generado (si no, sería lex.yy.c)
%option noinput                         no genera la función input() (no la usamos)
%option nounput                         no genera yyunput() (no la usamos)
%option noyywrap                        al llegar al fin de la entrada, termina
```

- `noinput` y `nounput` evitan el warning "función definida pero no usada".
- `noyywrap`: sin esta opción, al llegar al fin del archivo flex llamaría a una función `yywrap()` para preguntar si hay otro archivo, y habría que definirla o enlazar con `-lfl`.
- Gracias a estas opciones, flex se ejecuta **sin parámetros**: `flex scanner.l`.

**Las definiciones (ER con nombre)** salen de la gramática léxica del TP2:

```
digito      [0-9]
letra       [a-zA-Z]
entero      {digito}+
exponente   [eE][+-]?{entero}
fraccion    {entero}\.{entero}?|{entero}?\.{entero}
real        {entero}{exponente}|{fraccion}{exponente}?
ident       {letra}({letra}|{digito})*
nosep       [^ \t\r\n+\-*/^=()]
```

| Nombre | Se lee como | Ejemplos |
|---|---|---|
| `entero` | uno o más dígitos | `0`, `13` |
| `exponente` | `e` o `E`, signo opcional, entero | `e3`, `E-3`, `e+10` |
| `fraccion` | entero, punto y entero opcional; **o** entero opcional, punto y entero | `2.5`, `2.`, `.5` (pero no `.` solo) |
| `real` | entero con exponente, **o** fracción con exponente opcional | `1e3`, `2.37e-3`, `13.25` |
| `ident` | una letra seguida de letras o dígitos | `a`, `x2`, `abc` |
| `nosep` | un carácter que **no separa** lexemas: todo menos blancos, fin de línea y operadores | `a`, `5`, `.`, `#`, `@` |

`nosep` es una definición auxiliar que se usa sólo para detectar errores (ver 6.4). La idea es que los lexemas se separan por blancos u operadores; todo lo que esté pegado forma una sola "palabra".

### 6.3 Reglas de los tokens válidos

```c
{ident}             { yylval.id = strdup(yytext); return ID; }
```

Un identificador. Guarda **una copia** del nombre (`strdup`) en `yylval.id` y devuelve `ID`. Hace falta copiar porque `yytext` apunta a un buffer interno de flex que se pisa cuando se lee el token siguiente, y el parser puede necesitar el nombre más tarde (en `a = 3 + 4`, el nombre `a` se usa recién cuando se terminó de leer toda la línea). La copia la libera el parser con `free`.

```c
{entero}|{real}     { sscanf(yytext, "%lf", &yylval.num); return NUM; }
```

Un número. `sscanf` con `%lf` convierte el texto a `double` (entiende decimales y exponentes) y lo deja en `yylval.num`.

```c
"+="                { return MAS_IGUAL; }
"-="                { return MENOS_IGUAL; }
"*="                { return POR_IGUAL; }
"/="                { return DIV_IGUAL; }
```

Las asignaciones compuestas. Por la regla del lexema más largo, `+=` gana sobre `+` seguido de `=`.

```c
[-+*/^=()]          { return yytext[0]; }
```

Los operadores de un carácter. Se devuelve el **propio carácter** como código de token (`'+'` es el número 43 en ASCII). Bison acepta caracteres entre comillas simples como tokens, y así no hace falta inventarles nombres. El `-` va primero dentro de los corchetes para que no se interprete como un rango.

```c
\n                  { return '\n'; }
```

El fin de línea **es un token**, porque la gramática es "por líneas": cada línea es una expresión que hay que calcular e imprimir.

```c
[ \t\r]+            ;
```

Espacios, tabulaciones y `\r` (el fin de línea de Windows es `\r\n`): se descartan. La acción vacía no hace `return`, así que flex sigue leyendo.

### 6.4 Reglas de los errores léxicos

```c
{letra}{nosep}+     { error_lexico("Error léxico: identificador inválido", yytext); return LEXERR; }
{real}{nosep}+      { error_lexico("Error léxico REAL inválido", yytext);           return LEXERR; }
{entero}{nosep}+    { error_lexico("Error léxico: constante inválida", yytext);     return LEXERR; }
{nosep}+            { error_lexico("Error léxico: cadena desconocida", yytext);     return LEXERR; }
```

La idea: **"algo que empieza como X pero tiene caracteres de más pegados"**.

- Empieza con letra y sigue con cosas que no separan → identificador inválido (`a#2.4`).
- Empieza con un real y sigue → REAL inválido (`2.3.4a2.3`).
- Empieza con un entero y sigue → constante inválida (`12a3`).
- Cualquier otra cosa pegada → cadena desconocida (`@@#;@`).

**¿Por qué no "se comen" a los lexemas válidos?** Por las dos reglas de flex (3.5). Las reglas de error están **abajo**, así que sólo ganan cuando reconocen un lexema **más largo** que la regla válida. Casos:

| Entrada | Qué reconoce cada regla | Gana | Por qué |
|---|---|---|---|
| `abc` | `{ident}`: 3; identificador inválido: 3; cadena desconocida: 3 | `{ident}` → `ID` | Empate, gana la escrita primero |
| `2.37e-3` | `NUM`: 7 (todo); REAL inválido: `2.37e` = 5 (el `-` separa) | `NUM` | Más largo |
| `a#2.4` | `{ident}`: `a` = 1; identificador inválido: 5 | identificador inválido | Más largo |
| `2.3.4a2.3` | `NUM`: `2.3` = 3; REAL inválido: 9; constante inválida: 9; cadena desconocida: 9 | REAL inválido | Más largo; entre los de 9, la escrita primero |
| `12a3` | `NUM`: `12` = 2; REAL inválido: no aplica (`12` no es real); constante inválida: 4 | constante inválida | Más largo |
| `@@#;@` | sólo cadena desconocida: 5 | cadena desconocida | Es la única |
| `.` solo | no es número; cadena desconocida: 1 | cadena desconocida | Es la única |

Como todo carácter es separador (blancos, operadores, `\n`) o `nosep`, **cualquier entrada** cae en alguna regla. Por eso no hace falta la típica regla final `.` ("cualquier otro carácter").

**`LEXERR`**: después de informar el error, el scanner **devuelve el token `LEXERR`**, que está declarado en `parser.y` pero no aparece en ninguna regla de la gramática. El parser, al recibirlo, tiene un error sintáctico seguro y descarta la línea entera (ver 9.2). Si el scanner simplemente ignorara el lexema inválido, `a = 3 @` se ejecutaría como `a = 3` y la variable cambiaría.

---

## 7. bison y `parser.y`, línea por línea

### 7.1 Estructura de un archivo de bison

Igual que flex, tiene **tres secciones separadas por `%%`**:

```
declaraciones   (código C, opciones, tokens, tipos, precedencias)
%%
gramática       (reglas con sus acciones en C)
%%
código C del usuario   (acá está yyerror)
```

Las reglas se escriben así:

```
no_terminal
    : alternativa1   { acción }
    | alternativa2   { acción }
    ;
```

### 7.2 Directivas

```c
%code top {
#include <stdio.h>
#include <stdlib.h>
#include "calc.h"
#include "scanner.h"
}
```

Código que va al principio del `parser.c` generado. `stdlib.h` es por `free`, `scanner.h` por `yylex`.

```c
%code provides {
void yyerror(const char *mensaje);
}
```

Pone el prototipo de `yyerror` en `parser.h`, para que quede declarado.

```
%defines "build/parser.h"           genera el header con los tokens y yylval (equivale a bison -d)
%output "build/parser.c"            nombre del .c generado
%define parse.error verbose         mensajes detallados: "unexpected '*', expecting NUM or ID ..."
%define lr.default-reduction consistent   ver 9.4
%define parse.lac full                    ver 9.4
```

Sin `parse.error verbose`, el mensaje sería sólo `syntax error`. Gracias a `%defines` y `%output`, bison se ejecuta **sin parámetros**: `bison parser.y`.

### 7.3 Tipos de valores: `%union`, `%token`, `%type`

```c
%union {
  double num;
  char *id;
}
```

Define el tipo de los valores semánticos (`YYSTYPE`, el tipo de `yylval` y de los `$$`, `$1`…). Es una `union` de C: cada valor es **o** un `double` **o** un `char *`. Los números usan `num` y los identificadores usan `id`.

```c
%token <num> NUM          un número; su valor es un double (campo num)
%token <id>  ID           un identificador; su valor es el nombre (campo id)
%token MAS_IGUAL "+=" MENOS_IGUAL "-=" POR_IGUAL "*=" DIV_IGUAL "/="
%token LEXERR             token de error léxico, no se usa en ninguna regla
%type <num> expresion     toda expresión vale un double
```

- `%token` declara los tokens **con nombre**. Bison les asigna un número y los pone en `parser.h`; el scanner los usa para el `return`.
- El `<num>` o `<id>` indica qué campo de la `%union` usa ese símbolo. Así, en `$$ = $1 + $3`, bison sabe que son `double`.
- `"+="` es un **alias**: permite escribir `"+="` en las reglas en lugar de `MAS_IGUAL`, y hace que los mensajes de error muestren `"+="` en lugar del nombre interno.
- Los tokens de un carácter (`'+'`, `'\n'`…) no se declaran: se usan directamente.

```c
%destructor { free($$); } <id>
```

Cuando bison **descarta** un símbolo de tipo `<id>` durante la recuperación de un error, ejecuta `free` sobre él. Así no se pierde memoria del `strdup` del scanner (ver 7.6).

### 7.4 Precedencia y asociatividad

```
%right '=' "+=" "-=" "*=" "/="     ← menor precedencia
%left '+' '-'
%left '*' '/'
%precedence NEG
%right '^'                         ← mayor precedencia
```

- Se declaran **de menor a mayor**: cada línea tiene más precedencia que la anterior.
- Los operadores de la misma línea tienen la misma precedencia.
- `%left` = asociativo a izquierda; `%right` = a derecha; `%precedence` = sólo precedencia, sin asociatividad.

Cómo se resuelven los casos importantes (con el mecanismo de 4.6):

| Entrada | Situación | Decisión | Resultado |
|---|---|---|---|
| `2+4*5` | pila `E + E`, viene `*` (más que `+`) | desplaza | `2+(4*5)` = 22 |
| `(2+4)*5` | el paréntesis fuerza la agrupación | | 30 |
| `7-2-1` | pila `E - E`, viene `-` (igual, `%left`) | reduce | `(7-2)-1` = 4 |
| `2^3^2` | pila `E ^ E`, viene `^` (igual, `%right`) | desplaza | `2^(3^2)` = 512 |
| `2^3*2` | pila `E ^ E`, viene `*` (menos que `^`) | reduce | `(2^3)*2` = 16 |
| `-2^2` | pila `- E`, viene `^` (más que `NEG`) | desplaza | `-(2^2)` = -4 |
| `2*-3` | después del `*`, el `-` sólo puede ser unario | | `2*(-3)` = -6 |
| `2^-3+2` | `-3` es unario; después viene `+` (menos que todo lo anterior) | reduce | `(2^(-3))+2` = 2.125 |
| `a = 3 + b*2` | pila `ID = E`, viene `+` (más que `=`) | desplaza | `a = (3 + b*2)` = 7.6 |

**`NEG` y el menos unario.** El mismo símbolo `-` se usa para restar (`5 - 3`) y para cambiar de signo (`-3`), y tienen precedencias distintas: el cambio de signo tiene más que `*` pero menos que `^`. `NEG` es un **token ficticio**: el scanner nunca lo devuelve; sólo sirve para darle nombre a un nivel de precedencia. En la regla `'-' expresion %prec NEG`, el `%prec NEG` le dice a bison: "esta regla no tiene la precedencia de `-` (su último terminal), sino la de `NEG`".

**¿Por qué el unario está por debajo de `^`?** Por convención matemática: `-2²` es `-(2²) = -4`. Es lo que definía la gramática del TP2.

**¿Por qué `=` tiene la menor precedencia?** Para que en `a = 3 + 4` primero se calcule todo lo de la derecha y después se asigne.

### 7.5 La gramática

```
sesion
    : %empty
    | sesion linea              { mostrar_prompt(); }
    ;
```

Una **sesión** (toda la entrada) es vacía, o una sesión seguida de una línea. O sea, una secuencia de cero o más líneas. Es **recursiva a izquierda**, como recomienda bison para parsers LR: así reduce cada línea apenas termina, sin acumular toda la entrada en la pila. Cada vez que se completa una línea, se imprime el prompt `> ` de la siguiente. (El primer prompt lo imprime `main`.)

```
linea
    : '\n'                                         línea vacía: no hace nada
    | expresion '\n'            { mostrar_resultado($1); }   imprime el resultado
    | error '\n'                                   recuperación de errores (ver 9)
    ;
```

`error` es un **token especial de bison** que representa "cualquier cosa mal formada". La regla `error '\n'` significa: "si hay un error en una línea, descartá todo hasta el fin de línea y seguí".

```
expresion
    : expresion '+' expresion   { $$ = $1 + $3; }
    | expresion '-' expresion   { $$ = $1 - $3; }
    | expresion '*' expresion   { $$ = $1 * $3; }
    | expresion '/' expresion   { if (!division_valida($3)) YYERROR;
                                  $$ = $1 / $3; }
    | expresion '^' expresion   { if (!potencia($1, $3, &$$)) YYERROR; }
    | '-' expresion %prec NEG   { $$ = -$2; }
    | '(' expresion ')'         { $$ = $2; }
    | NUM                       { $$ = $1; }
    | ID                        { $$ = valor_variable($1); free($1); }
    | ID '=' expresion          { $$ = asignar($1, $3); free($1); }
    | ID "+=" expresion         { $$ = asignar($1, valor_variable($1) + $3); free($1); }
    | ID "-=" expresion         { ... - ... }
    | ID "*=" expresion         { ... * ... }
    | ID "/=" expresion         { if (!division_valida($3)) { free($1); YYERROR; }
                                  $$ = asignar($1, valor_variable($1) / $3); free($1); }
    ;
```

Esta es la **gramática achatada**: un solo no terminal `expresion` con todas las alternativas. Es ambigua, y las declaraciones de 7.4 resuelven la ambigüedad.

Qué hace cada acción:

- **Aritmética**: `$$ = $1 + $3`, etc. El resultado de la subexpresión queda en `$$`.
- **División**: antes de dividir, `division_valida($3)` verifica que el divisor no sea 0. Si lo es, informa el error y `YYERROR` corta el análisis de la línea (ver 9.3).
- **Potencia**: `potencia` verifica los casos inválidos y, si todo está bien, deja el resultado en `$$` (por eso recibe `&$$`, un puntero).
- **Menos unario**: `$$ = -$2` (el `$1` es el `'-'`).
- **Paréntesis**: el valor es el de la expresión de adentro (`$2`). No hay que hacer nada más: los paréntesis ya forzaron la agrupación en el árbol.
- **`NUM`**: el valor es el número que dejó el scanner en `yylval.num`.
- **`ID`**: `valor_variable` busca la variable en el diccionario (y si no existe, la crea con 0). Después se libera la copia del nombre.
- **Asignación**: `asignar` guarda el valor y lo **devuelve**, así que la asignación vale lo asignado. Eso permite `a = b = 5` y que `b = 2.3` imprima `2.3`.
- **Asignaciones compuestas**: `a += x` es `a = a + x`.

**¿Por qué el lado izquierdo de la asignación es `ID` y no `expresion`?** Porque sólo se puede asignar a una variable: `3 = 4` o `(a+b) = 4` no tienen sentido. Así, la gramática misma los rechaza como error sintáctico.

**¿Cómo distingue `a` (usar la variable) de `a = 5` (asignar)?** Después de leer el `ID`, mira el token siguiente (el *lookahead*): si es `=` o `+=`…, desplaza y sigue con la asignación; si es otra cosa, reduce `expresion : ID`. Es la "(1)" de LALR(1).

### 7.6 Memoria de los identificadores

Cada `ID` llega con un `char *` creado con `strdup` en el scanner, que hay que liberar exactamente una vez. Se libera en tres lugares:

1. **En la acción** que usa el `ID`, con `free($1)` después de usarlo.
2. **Antes de `YYERROR` en `/=`**. Cuando una acción llama a `YYERROR`, bison **no** llama al `%destructor` de los símbolos de esa regla, así que hay que liberarlo a mano.
3. **Con `%destructor`**, cuando bison descarta un `ID` mientras se recupera de un error. Por ejemplo, en `a 2 3`, el `ID` `a` queda en la pila y se descarta al recuperarse.

### 7.7 `yyerror`

```c
void yyerror(const char *mensaje) {
  if (yychar == LEXERR) return;
  printf("%s\n", mensaje);
}
```

Bison llama a `yyerror` cuando encuentra un error sintáctico, con el mensaje ya armado (`syntax error, unexpected '*', expecting ...`). La función lo imprime.

La excepción: `yychar` es una variable global de bison que tiene el **token que causó el error** (el lookahead). Si es `LEXERR`, el error sintáctico es sólo consecuencia de un error léxico que el scanner **ya informó**, y no se imprime un segundo mensaje.

---

## 8. Las rutinas semánticas: `calc.c`, `calc.h` y `main.c`

### 8.1 `calc.h`

Es la **interfaz**: declara las funciones que el parser y el scanner pueden usar. `calc.c` es la **implementación**. El `#ifndef CALC_H_INCLUDED` evita que el header se procese dos veces si se incluye más de una vez.

### 8.2 El diccionario de variables

Las variables se guardan en una **lista simplemente enlazada**:

```c
typedef struct Simbolo {
  char* nombre;
  double valor;
  struct Simbolo* sig;
} Simbolo;

static Simbolo* diccionario = NULL;
```

`static` hace que la lista sólo sea visible dentro de `calc.c`: el resto del programa no la puede tocar directamente, sólo a través de las funciones (encapsulamiento).

| Función | Qué hace |
|---|---|
| `buscar(nombre)` | Recorre la lista comparando nombres con `strcmp`. Devuelve el nodo o `NULL`. (`static`, interna) |
| `buscar_o_declarar(nombre)` | Si la variable existe, la devuelve. Si no, crea un nodo con valor 0 y lo agrega **al principio** de la lista. Si `malloc` o `strdup` fallan, termina el programa. (`static`, interna) |
| `valor_variable(nombre)` | Devuelve el valor (autodeclarando con 0 si hace falta) |
| `asignar(nombre, valor)` | Guarda el valor (autodeclarando si hace falta) y lo devuelve |
| `liberar_diccionario()` | Libera todos los nodos al terminar |

**Autodeclaración**: no hay una instrucción para declarar variables. Una variable "nace" la primera vez que se usa, con valor 0. Por eso, en el ejemplo, `a` al principio imprime `0`.

El diccionario guarda **su propia copia** del nombre (`strdup` en `buscar_o_declarar`), independiente de la copia que trae el token `ID`. Por eso el parser puede hacer `free($1)` sin romper el diccionario.

**¿Por qué una lista y no una tabla hash?** Porque una calculadora maneja pocas variables, y una lista es simple y suficiente. La búsqueda es O(n), pero con n chico no importa.

### 8.3 Los controles semánticos

```c
bool division_valida(double divisor)
```

Si el divisor es 0, informa `Error semántico: división por cero` y devuelve `false`. Se usa en `/` y `/=`.

```c
bool potencia(double base, double exponente, double* resultado)
```

Dos casos inválidos:

- **Base 0 con exponente negativo**: `0^-1` = 1/0¹, una división por cero.
- **Base negativa con exponente no entero**: `(-8)^0.5` = √-8, que no tiene resultado real (sería un número complejo). `exponente != floor(exponente)` detecta que el exponente tiene parte decimal.

Si no hay error, calcula con `pow` (de `math.h`, por eso se enlaza con `-lm`) y deja el resultado en `*resultado`. Recibe un puntero porque necesita devolver dos cosas: si salió bien (el `bool`) y el resultado.

Ojo: `-8^0.5` **no** es error, porque por precedencia es `-(8^0.5) = -2.83`. Para que dé error hay que escribir `(-8)^0.5`.

### 8.4 Funciones de salida

| Función | Imprime |
|---|---|
| `mostrar_prompt()` | `> ` y hace `fflush(stdout)` para que aparezca enseguida, aunque no haya `\n` |
| `mostrar_resultado(v)` | el valor con `%g`, que usa la notación más corta (`22`, no `22.000000`; `0.00237`) |
| `error_lexico(msj, lexema)` | `mensaje: lexema` |
| `error_semantico(msj)` | `Error semántico: mensaje` |

Están todas en `calc.c` para que los formatos de salida estén en un solo lugar.

### 8.5 `main.c`

```c
int main(void) {
  mostrar_prompt();          // el primer "> " (los siguientes los imprime el parser)
  int resultado = yyparse(); // analiza TODA la entrada, hasta el fin de archivo
  putchar('\n');             // para que la consola no quede pegada al último "> "
  liberar_diccionario();     // libera la memoria de las variables
  yylex_destroy();           // libera los buffers internos de flex
  return resultado;          // 0 si terminó bien
}
```

`yyparse()` no vuelve hasta que se termina la entrada (Ctrl+D en la terminal, o el fin del archivo redirigido). Gracias a la recuperación de errores, devuelve 0 aunque haya habido errores en algunas líneas.

La entrada se lee de `stdin`, así que el programa anda igual en modo interactivo (`./build/calc`) o con un archivo (`./build/calc < ejemplos/entrada.txt`). En el segundo caso no aparece el eco de lo que se tipea, y por eso `salida.txt` tiene `> 22` en una sola línea.

---

## 9. Manejo de errores

### 9.1 Resumen

| Tipo | Ejemplo | Quién lo detecta | Mensaje | Cómo se recupera |
|---|---|---|---|---|
| **Léxico** | `@@#;@`, `12a3` | el scanner (reglas de error) | `error_lexico` | devuelve `LEXERR` → error sintáctico silencioso → `error '\n'` descarta la línea |
| **Sintáctico** | `2 * * 3` | el parser (no hay acción válida en la tabla) | `yyerror` (mensaje de bison) | `error '\n'` descarta la línea |
| **Semántico** | `1/0`, `(-8)^0.5` | las acciones del parser, usando `calc.c` | `error_semantico` | `YYERROR` → `error '\n'` descarta la línea |

En los tres casos: **se informa el error, se descarta la línea completa, y el programa sigue con la línea siguiente**. Una línea con error no tiene ningún efecto (no asigna nada).

### 9.2 La recuperación con `error '\n'`

Cuando el parser encuentra un error:

1. Llama a `yyerror` con el mensaje.
2. **Saca estados de la pila** hasta llegar a uno donde se pueda desplazar el token especial `error`. Ese estado es el del principio de una `linea` (porque `linea : error '\n'` es la única regla con `error`).
3. Desplaza `error`.
4. **Descarta tokens** de la entrada hasta encontrar un `'\n'`.
5. Desplaza el `'\n'`, reduce `linea : error '\n'`, y como `sesion : sesion linea` se reduce, imprime el prompt. Sigue normalmente.

La consigna pide **no usar `yyerrok`**. `yyerrok` es una macro que le dice a bison "ya me recuperé, volvé a informar errores normalmente". Sin ella, después de un error bison no informa nuevos errores sintácticos hasta haber desplazado 3 tokens con éxito (ver 13, limitaciones).

### 9.3 `YYERROR` para los errores semánticos

`YYERROR` es una macro de bison que, desde una acción, **inicia la recuperación de errores como si hubiera habido un error sintáctico**, pero **sin llamar a `yyerror`** (el mensaje ya lo dio `error_semantico`). La consigna pide usarla.

Ejemplo con `x = 1/0`: al reducir `expresion '/' expresion`, `division_valida(0)` informa el error y devuelve `false`, la acción hace `YYERROR`, el parser se recupera con `error '\n'` y **nunca llega a reducir** `ID '=' expresion`, así que `x` no se asigna.

### 9.4 Que una línea con error no tenga efectos: `lr.default-reduction` y `parse.lac`

Un parser LALR puede **reducir antes de darse cuenta** de que el token siguiente es un error, y al reducir ejecuta la acción. Sin cuidado, `q = 3 @` haría la asignación `q = 3` y recién después informaría el error. Hay dos causas, y cada directiva corrige una:

1. **Reducciones por defecto.** Para que las tablas sean más chicas, bison normalmente reduce en muchos estados **sin mirar** el token siguiente. `%define lr.default-reduction consistent` hace que eso sólo pase cuando hay una única acción posible. Así el parser mira el token siguiente antes de reducir, y detecta el error antes de ejecutar la acción.
2. **Fusión de estados de LALR.** LALR "fusiona" estados parecidos para tener menos estados, y por eso a veces cree que un token es válido cuando no lo es (por ejemplo, `)` después de `a = 5` parece válido, porque lo sería dentro de `(a = 5)`). `%define parse.lac full` (*LookAhead Correction*) hace que, antes de reducir, bison **simule** si el token siguiente se va a poder desplazar. Si no, informa el error en ese momento, sin ejecutar ninguna acción. Además, la lista `expecting ...` de los mensajes sale más precisa.

Prueba: `q = 3 @` y después `q` muestra `0`; `a = 5 )` y después `a` muestra `0`.

---

## 10. Seguimiento completo de ejemplos

### 10.1 `2+4*5`

**Scanner**: `NUM(2)` `'+'` `NUM(4)` `'*'` `NUM(5)` `'\n'`

**Parser** (la pila arranca con `sesion`, ya reducida de `%empty`):

| Pila | Lookahead | Acción |
|---|---|---|
| `sesion` | `NUM(2)` | desplazar |
| `sesion NUM` | `'+'` | reducir `expresion : NUM` → `$$ = 2` |
| `sesion E(2)` | `'+'` | desplazar |
| `sesion E(2) +` | `NUM(4)` | desplazar |
| `sesion E(2) + NUM` | `'*'` | reducir `expresion : NUM` → 4 |
| `sesion E(2) + E(4)` | `'*'` | **conflicto**: `*` > `+` → desplazar |
| `sesion E(2) + E(4) *` | `NUM(5)` | desplazar |
| `sesion E(2) + E(4) * NUM` | `'\n'` | reducir `expresion : NUM` → 5 |
| `sesion E(2) + E(4) * E(5)` | `'\n'` | reducir `E * E` → 20 |
| `sesion E(2) + E(20)` | `'\n'` | reducir `E + E` → 22 |
| `sesion E(22)` | `'\n'` | desplazar |
| `sesion E(22) '\n'` | | reducir `linea : expresion '\n'` → **imprime `22`** |
| `sesion linea` | | reducir `sesion : sesion linea` → **imprime `> `** |
| `sesion` | (siguiente línea) | … |

### 10.2 `a = b += 1` (con `b` = 2.3)

**Scanner**: `ID("a")` `'='` `ID("b")` `"+="` `NUM(1)` `'\n'`

Árbol:

```
          expresion  ← asignar("a", 3.3) = 3.3
         /    |    \
       ID    '='   expresion  ← asignar("b", 2.3 + 1) = 3.3
      "a"         /    |    \
                ID   "+="   expresion  ← 1
               "b"            |
                             NUM(1)
```

Primero se reduce lo de más abajo: `NUM` → 1; después `b += 1` → b pasa a valer 3.3 y la expresión vale 3.3; después `a = 3.3`. Se imprime `3.3`. Después, `a` y `b` muestran `3.3`.

### 10.3 `@@#;@` (error léxico)

1. El scanner reconoce `@@#;@` con `{nosep}+` (cadena desconocida), imprime `Error léxico: cadena desconocida: @@#;@` y devuelve `LEXERR`.
2. El parser no tiene ninguna acción para `LEXERR`: error sintáctico. Llama a `yyerror`, pero como `yychar == LEXERR`, no imprime nada.
3. Recuperación: desplaza `error`, descarta `LEXERR`, encuentra `'\n'`, reduce `linea : error '\n'`, imprime el prompt.

### 10.4 `2 * * 3` (error sintáctico)

1. Scanner: `NUM(2)` `'*'` `'*'` `NUM(3)` `'\n'`. Todos los tokens son válidos.
2. Parser: después de `E *`, espera el comienzo de una expresión. Llega otro `'*'`: no hay acción válida.
3. `yyerror` imprime `syntax error, unexpected '*', expecting NUM or ID or '-' or '('`. Esa lista son los tokens con los que puede empezar una expresión.
4. Recuperación: saca `E *` de la pila, desplaza `error`, descarta `'*'` y `NUM(3)`, encuentra `'\n'`.

### 10.5 `x = 1/0` (error semántico)

1. Scanner: `ID("x")` `'='` `NUM(1)` `'/'` `NUM(0)` `'\n'`.
2. Al reducir `expresion '/' expresion`, `division_valida(0)` imprime `Error semántico: división por cero`, y la acción hace `YYERROR`.
3. Recuperación: se descartan `ID '='` de la pila (el `%destructor` libera el `"x"`) y el `'\n'` cierra la línea. `x` nunca se asigna.

### 10.6 La salida completa del ejemplo de la cátedra

Con `make test` se corre `ejemplos/entrada.txt` y se compara con `ejemplos/salida.txt`. Coinciden. Explicación de cada línea:

| Entrada | Salida | Por qué |
|---|---|---|
| `2+4*5` | `22` | precedencia de `*` sobre `+` |
| `(2+4)*5` | `30` | paréntesis |
| `a` | `0` | autodeclaración con 0 |
| `b = 2.3` | `2.3` | la asignación devuelve el valor |
| `a = 3 + b*2` | `7.6` | `=` tiene la menor precedencia |
| `a = b += 1` | `3.3` | asignaciones encadenadas, asociatividad a derecha |
| `a` / `b` | `3.3` / `3.3` | quedaron asignadas |
| `@@#;@` | cadena desconocida | `{nosep}+` |
| `13.25` | `13.25` | real con fracción |
| `2.37e-3` | `0.00237` | real con exponente; `%g` |
| `12a3` | constante inválida | `{entero}{nosep}+` |
| `a#2.4` | identificador inválido | `{letra}{nosep}+` |
| `2.3.4a2.3` | REAL inválido | `{real}{nosep}+` |
| `2 * * 3` | syntax error | dos operadores seguidos |
| `2^3*2` | `16` | `^` más que `*` |
| `2^-3+2` | `2.125` | menos unario en el exponente; 1/8 + 2 |
| (fin) | `> ` | el último prompt, y `main` imprime `\n` |

---

## 11. Qué tiene que saber cada integrante

Según `división-del-trabajo.md`. Además de su parte, **todos** deberían poder explicar las secciones 2 y 5 (qué hace cada etapa y cómo se comunican), porque es lo más probable que pregunten.

| Persona | Parte | Leer | Lo que seguro te preguntan |
|---|---|---|---|
| 1 | `scanner.l` 1–49: directivas, ER, tokens válidos | 3, 6.1–6.3 | Qué es un token; qué es una ER; cómo se lee `fraccion` y `real`; para qué es cada `%option`; por qué `strdup`; qué es `yylval`; por qué `\n` es un token; por qué se devuelve `yytext[0]` |
| 2 | `scanner.l` 50–72: errores léxicos; `calc.c` 77–90: salida | 3.5, 6.4, 8.4, 10.3 | Cómo desempata flex (más largo, después el primero); qué es `nosep`; por qué las reglas de error van al final; para qué sirve `LEXERR`; por qué `fflush`; qué hace `%g` |
| 3 | `parser.y` 1–37: directivas, `%union`, tokens, precedencia | 4.3, 4.6, 7.2–7.4 | Qué es `%union`; qué significan `<num>`, `<id>`; qué es un alias; cómo resuelve bison un conflicto; menor a mayor; `%left` vs `%right`; qué es `NEG` y `%prec`; `parse.error verbose` |
| 4 | `parser.y` 39–67 y 91–96: `sesion`, `linea`, aritmética, `yyerror` | 4.5, 4.7, 7.5, 7.7, 9.2, 10.1 | Qué es `$$`/`$1`; qué es desplazar/reducir; por qué recursiva a izquierda; qué es el token `error` y cómo funciona la recuperación; por qué no `yyerrok`; qué es `yychar` y por qué se compara con `LEXERR` |
| 5 | `parser.y` 68–89: asignaciones; `calc.c` 56–75: controles | 7.5 (asignaciones), 7.6, 8.3, 9.3, 9.4, 10.2, 10.5 | Por qué el lado izquierdo es `ID`; cómo distingue `a` de `a = 5`; por qué la asignación devuelve el valor; qué hace `YYERROR`; por qué el `free` antes de `YYERROR`; los dos casos de error de la potencia; por qué `potencia` recibe un puntero |
| 6 | `calc.c` 1–54: diccionario; `calc.h` | 8.1, 8.2 | Por qué lista enlazada; por qué `static`; qué es la autodeclaración; por qué el diccionario hace su propio `strdup`; cómo se libera la memoria; qué hace el `#ifndef` |
| 7 | `main.c`, `makefile`, `.gitignore`, `readme.md`, ejemplos | 2, 8.5, 12, 10.6 | Qué genera flex y qué genera bison; orden de compilación; por qué `-lm`; por qué `parser.h` es dependencia de `scanner.o`; qué hace `make test` y por qué `diff -Z`; qué hace `yylex_destroy` |

---

## 12. El `makefile` y cómo se compila

### 12.1 Herramientas

Hacen falta `flex`, `bison`, `clang` y `make`. En Ubuntu/WSL:

```sh
sudo apt install build-essential flex bison clang clang-format
```

### 12.2 Comandos

```sh
make                                  # compila: genera build/calc
./build/calc                          # modo interactivo (Ctrl+D para salir)
./build/calc < ejemplos/entrada.txt   # con un archivo de entrada
make test                             # compara la salida con ejemplos/salida.txt
make run                              # compila y ejecuta
make format                           # da formato estilo Google a los .c y .h
make clean                            # borra build/
```

### 12.3 Qué hace `make` paso a paso

```
1. bison parser.y   → build/parser.c, build/parser.h
2. flex scanner.l   → build/scanner.c, build/scanner.h
3. clang -c main.c, calc.c, build/parser.c, build/scanner.c → build/*.o
4. clang build/*.o -o build/calc -lm
```

Cada regla del makefile dice "este archivo se hace a partir de estos otros, con este comando". `make` sólo rehace lo que cambió (compara fechas de modificación).

Detalles que pueden preguntar:

- **`CFLAGS`**: `-g` (información para depurar), `-O0` (sin optimizar), `-Wall -Wextra` (todos los warnings), `-pedantic-errors -std=c23` (C23 estricto), `-I. -Ibuild` (dónde buscar los `.h`: en la raíz está `calc.h`, en `build/` están `parser.h` y `scanner.h`), `-c` (compilar sin enlazar). Compila **sin warnings**, incluido el código generado.
- **`-lm`**: enlaza la biblioteca matemática, por `pow` y `floor`.
- **`build/parser.c build/parser.h: parser.y`**: una regla con dos objetivos, porque un solo `bison parser.y` genera los dos.
- **Por qué `scanner.o` depende de `parser.h`**: si cambia la gramática y bison renumera los tokens, el scanner tiene que recompilarse; si no, devolvería números de token viejos.
- **`mkdir -p build`**: crea la carpeta si no existe (`-p` = no falla si ya existe).
- **`make test`**: `./build/calc < ejemplos/entrada.txt | diff -Z ejemplos/salida.txt -` compara la salida con la esperada. `-Z` ignora espacios al final de las líneas, porque en `salida.txt` (transcripto de una captura) la última línea es `>` y el programa imprime `> ` con espacio. Si coinciden, imprime `OK`.
- **`make format`** no formatea `scanner.l` ni `parser.y`, porque clang-format no entiende la sintaxis de flex/bison y los rompería.
- **`.PHONY`**: marca los objetivos que no son archivos (`run`, `test`, `format`, `clean`), para que se ejecuten siempre.
- Todo lo generado va a `build/`, que está en `.gitignore`: no se sube al repositorio porque se regenera al compilar.

---

## 13. Preguntas probables y respuestas

### Teoría

**¿Qué diferencia hay entre un scanner y un parser?**
El scanner agrupa caracteres en tokens (análisis léxico) y trabaja con expresiones regulares, que equivalen a autómatas finitos. El parser verifica que los tokens formen frases válidas según una gramática libre de contexto (análisis sintáctico) y usa un autómata con pila.

**¿Por qué no se hace todo con expresiones regulares?**
Porque las ER no pueden describir estructuras anidadas como paréntesis balanceados: harían falta infinitos estados. Para eso hace falta una gramática libre de contexto.

**¿Por qué no se hace todo con la gramática?**
Se podría, pero sería más lento y más complicado. Separar el léxico simplifica la gramática (trabaja con `NUM` en vez de con dígitos, sin preocuparse por los espacios) y los autómatas finitos son muy eficientes.

**¿Qué es un token? ¿Y un lexema?**
El lexema es el texto concreto (`2.37e-3`); el token es su categoría (`NUM`), opcionalmente con un valor (0.00237).

**¿Qué tipo de parser genera bison?**
Ascendente (bottom-up), LALR(1): lee de izquierda a derecha, construye la derivación por derecha en orden inverso, y decide mirando un token por adelantado.

**¿Qué es un conflicto desplazar/reducir?**
Una situación donde, con la pila y el token siguiente, el parser podría tanto desplazar el token como reducir una regla. Aparecen en gramáticas ambiguas. En el TP los resuelven las declaraciones de precedencia y asociatividad.

**¿La gramática del TP es ambigua?**
Sí, a propósito: es la gramática "achatada" que pide la consigna. `2+4*5` tiene dos árboles posibles. Bison elige el correcto gracias a `%left`, `%right` y `%precedence`, y no informa ningún conflicto.

**¿Qué diferencia hay con la gramática del TP2?**
La del TP2 tenía un no terminal por nivel de precedencia (`aditiva`, `término`, `factor`…), y la precedencia estaba "metida" en la estructura de la gramática. En el TP3 hay un solo no terminal y la precedencia se declara aparte. Además, la del TP2 no permitía `2^-3`, y esta sí (como pide el ejemplo de la cátedra).

**¿Por qué la recursión a izquierda en `sesion`?**
En un parser LR, la recursión a izquierda permite reducir cada línea apenas termina, con la pila de tamaño constante. Con recursión a derecha, el parser apilaría todas las líneas antes de reducir. (En un parser descendente sería al revés: la recursión a izquierda produce un bucle infinito.)

**¿Qué es la traducción dirigida por la sintaxis?**
Asociar acciones a las reglas de la gramática para que el resultado (acá, el valor numérico) se calcule mientras se analiza. Cada vez que se reduce una regla, se ejecuta su acción.

### flex

**¿Qué pasa si dos reglas coinciden con el mismo texto?**
Gana la que reconoce el lexema más largo; si empatan, la que está escrita primero.

**¿Por qué las reglas de error están al final?**
Para que en caso de empate ganen las reglas válidas. Una regla de error sólo gana si reconoce más caracteres que la válida, o sea, cuando hay caracteres de más pegados.

**¿Para qué sirve `yylval`?**
Para pasarle al parser el valor del token (el número o el nombre). El código de retorno de `yylex()` sólo dice qué token es.

**¿Por qué `strdup(yytext)` y no `yytext` directo?**
Porque `yytext` apunta a un buffer de flex que se reutiliza para el token siguiente. El parser puede necesitar el nombre después de que flex ya leyó más tokens.

**¿Qué hace `noyywrap`?**
Evita que flex llame a `yywrap()` al llegar al fin del archivo. Así no hay que definirla ni enlazar con `-lfl`.

**¿Por qué `%top` con `_POSIX_C_SOURCE`?**
El código que genera flex usa `fileno` e `isatty`, que son POSIX. Con `-std=c23` estricto, los headers no las declaran salvo que se defina esa macro antes de cualquier `#include`, y `%top` es lo único que va antes de todo.

### bison

**¿Qué es `%union`?**
El tipo de los valores semánticos. Como algunos tokens llevan un `double` y otros un `char *`, se usa una `union` de C.

**¿Qué es `$$`? ¿Y `$1`?**
`$$` es el valor del no terminal de la izquierda (el resultado de la regla); `$1`, `$2`… son los valores de los símbolos de la derecha.

**¿Qué hace `%prec NEG`?**
Le asigna a la regla del menos unario la precedencia de `NEG` en lugar de la de `-`. Así el mismo símbolo `-` tiene una precedencia como resta y otra como cambio de signo.

**¿Por qué `-2^2` da -4 y no 4?**
Porque `^` tiene más precedencia que `NEG`: es `-(2^2)`. Es la convención matemática.

**¿Por qué `2^3^2` da 512?**
Porque `^` es `%right` (asociativo a derecha): `2^(3^2) = 2^9`.

**¿Qué es el token `error`?**
Un token especial de bison que representa una porción mal formada de la entrada. En `linea : error '\n'` indica dónde y cómo recuperarse: se descarta todo hasta el fin de línea.

**¿Qué hace `YYERROR`?**
Desde una acción, inicia la recuperación de errores como si hubiera un error sintáctico, pero sin llamar a `yyerror`. Se usa para los errores semánticos.

**¿Qué es `yyerrok` y por qué no se usa?**
Una macro que hace que bison vuelva a informar errores inmediatamente después de recuperarse. La consigna pide no usarla.

**¿Por qué `yyerror` compara `yychar` con `LEXERR`?**
Para no imprimir dos mensajes por el mismo error: si el token que causó el error sintáctico es `LEXERR`, el scanner ya informó el error léxico.

**¿Para qué es `%destructor`?**
Para liberar la memoria de los `ID` que bison descarta durante la recuperación de errores, que ninguna acción llegó a liberar.

**¿Para qué son `lr.default-reduction consistent` y `parse.lac full`?**
Para que el parser detecte el error **antes** de ejecutar acciones de la línea errónea. Sin ellas, `q = 3 @` podría asignar `q = 3` antes de notar el error (ver 9.4).

### Diseño y C

**¿Qué pasa si uso una variable que nunca asigné?**
Vale 0: se autodeclara al primer uso.

**¿Dónde se guardan las variables?**
En una lista enlazada en `calc.c`, declarada `static` para que sólo se acceda a través de las funciones de `calc.h`.

**¿Qué errores semánticos detecta?**
División por cero (`/`, `/=`, y `0^` negativo) y potencia de base negativa con exponente no entero.

**¿El programa termina con el primer error?**
No. Informa el error, descarta la línea y sigue con la siguiente, como pide la consigna.

**¿Hay pérdidas de memoria?**
No: se verificó con `valgrind`. Se libera la copia de cada `ID` (en la acción, antes de `YYERROR` o con `%destructor`), el diccionario con `liberar_diccionario` y los buffers de flex con `yylex_destroy`.

### Limitaciones conocidas (conviene mencionarlas si preguntan)

- **Errores silenciados por no usar `yyerrok`.** Después de un error, bison no informa otro error sintáctico hasta desplazar 3 tokens seguidos. Si la línea siguiente a un error tiene un error sintáctico en sus dos primeros tokens (por ejemplo `* 3`), se descarta igual, pero sin mensaje. Los errores léxicos y semánticos siempre se informan.
- **Última línea sin Enter.** Si la entrada termina sin `\n`, la última línea da `syntax error, unexpected end of file`, porque la gramática exige que cada línea termine en `'\n'`.
- **Precisión de punto flotante.** Se usa `double`, así que hay errores de redondeo internos (`0.1 + 0.2` es `0.30000000000000004`, aunque `%g` muestra `0.3`). Los números muy grandes dan `inf`.

---

## 14. Glosario

| Término | Significado |
|---|---|
| **Acción semántica** | Código C asociado a una regla; se ejecuta al reducir |
| **AFD** | Autómata finito determinístico: lo que flex construye a partir de las ER |
| **Ambigüedad** | Una entrada con más de un árbol de derivación posible |
| **Asociatividad** | Cómo se agrupan operadores de igual precedencia (izquierda o derecha) |
| **Axioma** | Símbolo inicial de la gramática (`sesion`) |
| **BNF** | Notación para escribir gramáticas (`a : b c \| d`) |
| **Conflicto** | Situación en la que el parser tiene dos acciones posibles |
| **Desplazar (shift)** | Poner el token siguiente en la pila |
| **ER** | Expresión regular |
| **Gramática achatada** | Gramática con un solo no terminal para todas las expresiones, con la precedencia declarada aparte |
| **GLC** | Gramática libre de contexto |
| **LALR(1)** | Tipo de parser ascendente que genera bison, con un token de anticipación |
| **LAC** | *LookAhead Correction*: verifica el lookahead antes de reducir |
| **Lexema** | El texto concreto de un token |
| **Lookahead** | El token siguiente, que el parser mira para decidir |
| **Maximal munch** | La regla de flex de quedarse con el lexema más largo |
| **No terminal** | Símbolo que se define con reglas (`expresion`) |
| **Precedencia** | Qué operador se agrupa primero |
| **Reducir (reduce)** | Reemplazar en la pila el lado derecho de una regla por su lado izquierdo |
| **Terminal** | Token; símbolo que no se descompone |
| **Token** | Categoría léxica (`NUM`, `ID`, `'+'`) |
| **`yylex`** | La función del scanner (la genera flex) |
| **`yyparse`** | La función del parser (la genera bison) |
| **`yylval`** | Variable donde el scanner deja el valor del token |
| **`yytext`** | Texto del lexema actual |
| **`yychar`** | Token de lookahead actual del parser |
| **`YYERROR`** | Macro para provocar un error desde una acción |
