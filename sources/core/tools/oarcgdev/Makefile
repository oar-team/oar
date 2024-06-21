all: oarcgdev

oarcgdev: oarcgdev-ebpf.o oarcgdev.c
	gcc -g -O0 -rdynamic -Wall -Werror oarcgdev.c -lelf -lz -lbpf -o oarcgdev

oarcgdev-ebpf.o: oarcgdev-ebpf.c
	clang -I /usr/include/*-linux-gnu/ -O2 -target bpf -c oarcgdev-ebpf.c -mcpu=v3 -g -o oarcgdev-ebpf.o

clean:
	rm oarcgdev oarcgdev-ebpf.o


run: oarcgdev
	@echo 'Please run `sudo cat /sys/kernel/debug/tracing/trace_pipe` to see output of the BPF programs.'
	@echo ========================
	sudo ls -l /sys/fs/bpf
	sudo rm -f /sys/fs/bpf/toto42
	@echo ========================
	sudo ./oarcgdev arg1 arg2 /dev/nvidia1 /dev/nvidia3
	@echo ========================
	sudo ls -l /sys/fs/bpf
	sudo rm -fv /sys/fs/bpf/toto42
	@echo ========================
