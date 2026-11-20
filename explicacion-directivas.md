# Tres líneas de `parser.y`: qué hacen y si son necesarias

```
%define lr.default-reduction consistent   (línea 16)
%define parse.lac full                    (línea 17)
%destructor { free($$); } <id>            (línea 31)
```

Para comprobar el efecto de cada una se compilaron cinco variantes de `parser.y`: la actual, sin `consistent`, sin LAC, sin ninguna de las dos y sin el `%destructor`. Las cinco pasan el test de la cátedra (`make test`), así que las diferencias sólo aparecen con entradas pensadas para cada línea.

## Lo necesario para entender las dos directivas

**Cuándo se ejecutan las acciones.** El parser va apilando tokens (desplazar) y, cuando lo que está arriba de la pila completa una regla, la reemplaza por su lado izquierdo (reducir). La acción entre llaves se ejecuta en el momento de reducir. En `ID '=' expresion { $$ = asignar($1, $3); ... }`, la asignación ocurre cuando bison reduce esa regla.

**El token de lookahead.** Para decidir si reduce o desplaza, bison mira el token siguiente sin consumirlo todavía. En `a = 5 +`, el `+` le indica que no tiene que reducir `a = 5` todavía, porque la suma va adentro de la asignación.

**El problema.** Si bison reduce `a = 5` antes de comprobar que el token siguiente es válido, la asignación se ejecuta. Cuando después detecta el error, la variable ya cambió. Esto puede pasar por dos motivos, y cada directiva corrige uno.

## `%define lr.default-reduction consistent` (línea 16)

**Qué hace.** Para achicar sus tablas, bison usa reducciones por defecto: en un estado donde la acción más común es reducir, reduce con cualquier token que no tenga una acción propia, aunque ese token sea inválido. El error se descubre más tarde, cuando ya se ejecutó la acción.

Con `consistent`, bison sólo usa reducciones por defecto en los estados donde la única acción posible es esa reducción. En los demás estados, un token inválido da error inmediatamente, antes de reducir.

**Resultado de la prueba.** Con `consistent` y sin LAC:

| Entrada, y después la variable | Sin ninguna de las dos | Sólo `consistent` |
|---|---|---|
| `q = 3 @`, luego `q` | **3** (asignó) | 0 |
| `b = 2 3`, luego `b` | **2** | 0 |
| `e = 7 e`, luego `e` | **7** | 0 |
| `a = 5 )`, luego `a` | **5** | **5** (sigue asignando) |
| `c = 1 + 2 )`, luego `c` | **3** | **3** |

Arregla los casos donde el token inválido (`@`, `3`, `e`) nunca puede ir después de una expresión. No arregla los casos con `)`: eso lo resuelve LAC.

**¿Es necesaria? No, en esta configuración.** Con `parse.lac full` activo, sacar esta línea no cambia nada: en 109 edge cases la salida, incluidos los mensajes de error, es idéntica. El modo interactivo también sigue mostrando el resultado al apretar Enter. LAC ya hace este control y algo más. Esta línea sólo sirve si se saca LAC.

## `%define parse.lac full` (línea 17)

**Qué hace.** Bison genera un parser LALR, y para que las tablas sean chicas, LALR fusiona estados parecidos. Por esa fusión, el estado que significa "terminé de leer `a = 5`" es el mismo dentro y fuera de un paréntesis. Como `(a = 5)` es válido, la tabla considera aceptable un `)` después de `a = 5` también cuando no hay ningún paréntesis abierto.

LAC (*LookAhead Correction*) agrega un control. Antes de ejecutar una reducción, bison la simula en una pila auxiliar y verifica que el token siguiente se vaya a poder desplazar realmente. Si no, informa el error ahí, sin ejecutar ninguna acción.

**Resultado de la prueba.** Sin LAC, aunque esté `consistent`:

| Entrada, y después la variable | Con LAC (versión actual) | Sin LAC |
|---|---|---|
| `a = 5 )`, luego `a` | 0 | **5** |
| `c = 1 + 2 )`, luego `c` | 0 | **3** |
| `m = 5 )`, luego `m` | 0 | **5** |

En los tres casos aparece el mensaje `syntax error, unexpected ')'`, pero sin LAC la variable igual cambia.

**¿Es necesaria? Sí,** si se quiere que una línea con error sintáctico no modifique variables. La consigna no lo exige explícitamente, pero sin LAC hay líneas que se informan como erróneas y a la vez asignan. LAC además hace más precisa la lista `expecting ...` de los mensajes, aunque en estas pruebas no apareció ninguna diferencia en eso.

## `%destructor { free($$); } <id>` (línea 31)

**Qué hace.** El scanner guarda el nombre de cada identificador en memoria dinámica (`yylval.id = strdup(yytext)`, línea 31 de `scanner.l`), y esa memoria hay que liberarla. En el camino normal, la liberan las acciones con `free($1)`, por ejemplo en `ID { $$ = valor_variable($1); free($1); }`.

Pero cuando hay un error, bison se recupera descartando símbolos: saca de la pila lo que había analizado de la línea y tira los tokens hasta el `\n`. Esos símbolos nunca llegan a una acción, así que nadie hace el `free`. El `%destructor` le indica a bison qué hacer con cada símbolo que descarta: `<id>` significa "todo símbolo cuyo valor es el campo `id` de la union", o sea, los `ID`, y `free($$)` libera su nombre.

**Resultado de valgrind (memcheck).** Con 8 líneas con errores que obligan a descartar identificadores: `a b`, `x y z`, `a 2`, `(a`, `a = b c`, `v @`, `w = q @` y `k (`.

| Versión | Resultado |
|---|---|
| Con `%destructor` (actual) | `in use at exit: 0 bytes`, **0 errores** |
| Sin `%destructor` | `26 bytes in 13 blocks are definitely lost`, **1 error** |

Valgrind muestra de dónde viene cada bloque perdido:

```
malloc → strdup → yylex (scanner.l:31) → yyparse → main (main.c:9)
```

Es la copia del nombre que hace el scanner. Cada bloque es el nombre de una variable que bison descartó sin liberar. Son pocos bytes por error, pero la pérdida crece con cada línea errónea de la sesión.

**¿Es necesaria? Sí,** para no perder memoria. El programa funciona igual sin ella, pero valgrind la marca como pérdida.

**Un caso que el `%destructor` no cubre.** Cuando la acción misma hace `YYERROR`, bison no llama al destructor de los símbolos de esa regla. Por eso en `ID "/=" expresion` (líneas 81 a 88) hay un `free($1)` antes del `YYERROR`.

## Resumen

| Línea | Efecto | ¿Necesaria? | Si se saca |
|---|---|---|---|
| `lr.default-reduction consistent` | Reduce por defecto sólo cuando no hay alternativa | **No, mientras esté LAC** | Nada cambia: 109 de 109 casos iguales |
| `parse.lac full` | Verifica el token siguiente antes de reducir | **Sí** | `a = 5 )` informa el error y además asigna `a = 5` |
| `%destructor { free($$); } <id>` | Libera los nombres que bison descarta en un error | **Sí** | Pérdida de memoria en cada línea con error (valgrind: *definitely lost*) |
