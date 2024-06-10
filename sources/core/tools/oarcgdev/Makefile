all: test_dev_cgroup

test_dev_cgroup: dev_cgroup.o test_dev_cgroup.c
	gcc -g -O0 -rdynamic -Wall -Werror test_dev_cgroup.c -lelf -lz -lbpf -o test_dev_cgroup

dev_cgroup.o: dev_cgroup.c
	clang -I /usr/include/x86_64-linux-gnu/ -O2 -target bpf -c dev_cgroup.c -mcpu=v3 -o dev_cgroup.bpf.o

run: test_dev_cgroup
	sudo ./test_dev_cgroup
