all: ztracempi.c
	gcc -shared -ldl -fPIC ztracempi.c -o ztracempi.so -lmpi -I/usr/include/openmpi/ 
debug: ztracempi.c	
	gcc -shared -ldl -fPIC ztracempi.c -o ztracempi.so -lmpi -I/usr/include/openmpi/ -DDEBUG 
