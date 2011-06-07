MPI_INCLUDE=/usr/include/mpich2/
INCLUDE = -I$(MPI_INCLUDE)

all: ztracempi.c
	gcc -shared -ldl -fPIC ztracempi.c -o ztracempi.so -lmpi $(INCLUDE)  
debug: ztracempi.c	
	gcc -shared -ldl -fPIC ztracempi.c -o ztracempi.so -lmpi -I/usr/include/openmpi/ -DDEBUG 
