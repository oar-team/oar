all: test_dev_cgroup

test_dev_cgroup: dev_cgroup.o test_dev_cgroup.c
	gcc -g -O0 -rdynamic -Wall -Werror test_dev_cgroup.c -lelf -lz -lbpf -o test_dev_cgroup

dev_cgroup.o: dev_cgroup.c
	clang -I /usr/include/*-linux-gnu/ -O2 -target bpf -c dev_cgroup.c -mcpu=v3 -g -o dev_cgroup.o

run: test_dev_cgroup
	@echo ========================
	sudo ls -l /sys/fs/bpf
	sudo rm -f /sys/fs/bpf/toto42
	@echo ========================
	sudo ./test_dev_cgroup
	@echo ========================
	sudo ls -l /sys/fs/bpf
	sudo rm -fv /sys/fs/bpf/toto42
