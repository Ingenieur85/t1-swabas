CC = gcc
AS = as
CFLAGS = -g -no-pie
LFLAGS = -lm


EXECS = main main16b

# Alvo padrão para compilar todos os executáveis
all: $(EXECS)

main: main.o memalloc.o
	$(CC) $(CFLAGS) $(LFLAGS) -o main main.o memalloc.o

main16b: main16b.o memalloc.o
	$(CC) $(CFLAGS) $(LFLAGS) -o main16b main16b.o memalloc.o

memalloc.o: memalloc.s 
	$(AS) -c memalloc.s -o memalloc.o

main.o: main.c memalloc.h
	$(CC) $(CFLAGS) -c main.c -o main.o

main16b.o: main16b.c memalloc.h
	$(CC) $(CFLAGS) -c main16b.c -o main16b.o

clean:
	rm -rf ./*.o

purge:
	rm -rf ./*.o
	rm -rf $(EXECS)

