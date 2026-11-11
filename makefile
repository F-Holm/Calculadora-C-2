CC = clang
STD = c23
CFLAGS = -g -O0 -Wall -Wextra -pedantic-errors -std=$(STD) -I. -Ibuild -c

.PHONY: run test format clean

build/calc: build/main.o build/calc.o build/parser.o build/scanner.o
	$(CC) $^ -o $@ -lm

build/main.o: main.c calc.h build/parser.h build/scanner.h
	$(CC) $(CFLAGS) $< -o $@

build/calc.o: calc.c calc.h
	mkdir -p build
	$(CC) $(CFLAGS) $< -o $@

build/parser.o: build/parser.c build/parser.h build/scanner.h calc.h
	$(CC) $(CFLAGS) $< -o $@

build/scanner.o: build/scanner.c build/scanner.h build/parser.h calc.h
	$(CC) $(CFLAGS) $< -o $@

build/parser.c build/parser.h: parser.y
	mkdir -p build
	bison parser.y

build/scanner.c build/scanner.h: scanner.l
	mkdir -p build
	flex scanner.l

run: build/calc
	./build/calc

test: build/calc
	./build/calc < ejemplos/entrada.txt | diff -Z ejemplos/salida.txt - && echo OK

format:
	clang-format -i --style=Google main.c calc.c calc.h

clean:
	rm -rf build
