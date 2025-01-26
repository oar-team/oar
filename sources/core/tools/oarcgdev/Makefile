all: oarcgdev

oarcgdev.c: oarcgdev.c.in
	sed -e 's/%%OARDIR%%/./' oarcgdev.c.in > oarcgdev.c

oarcgdev: oarcgdev.bpf oarcgdev.c
	gcc -g -O0 -rdynamic -Wall -Werror oarcgdev.c -lelf -lz -lbpf -o oarcgdev

oarcgdev.bpf: oarcgdev-ebpf.c
	#Need -g so that the map gets declared
	#https://lists.iovisor.org/g/iovisor-dev/topic/reading_pinned_maps_in_ebpf/76194102
	clang -I /usr/include/*-linux-gnu/ -O2 -target bpf -c oarcgdev-ebpf.c -mcpu=v3 -g -o oarcgdev.bpf

clean:
	rm oarcgdev oarcgdev.bpf
