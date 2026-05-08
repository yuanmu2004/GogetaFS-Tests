CFLAGS := -O3

TARGETS := to_MiB_s replay aging_system

all: ${TARGETS}

helper/mt19937ar.o: helper/mt19937ar.c helper/mt19937ar.h
	gcc -c helper/mt19937ar.c -O3 -o $@

helper/lcg.o: helper/lcg.c helper/lcg.h
	gcc -c helper/lcg.c -O3 -o $@

helper/map.o: helper/map.c helper/map.h
	gcc -c helper/map.c -O3 -o $@

replay: helper/replay.c helper/mt19937ar.o helper/lcg.o helper/map.o 
	gcc $^ -O3 -g -o $@ -lpthread

aging_system: helper/aging_system.c helper/mt19937ar.o
	gcc $^ -O3 -o $@

	
%: helper/%.c
	gcc $^ -O3 -o $@

%: helper/%.cpp
	g++ $^ -O3 -o $@

clean:
	rm ${TARGETS}

.PHONY: all clean
