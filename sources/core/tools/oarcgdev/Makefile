all: oarcgdev

oarcgdev: oarcgdev-ebpf.o oarcgdev.c
	gcc -DTEST -g -O0 -rdynamic -Wall -Werror oarcgdev.c -lelf -lz -lbpf -o oarcgdev

oarcgdev-ebpf.o: oarcgdev-ebpf.c
	clang -I /usr/include/*-linux-gnu/ -O2 -target bpf -c oarcgdev-ebpf.c -mcpu=v3 -g -o oarcgdev-ebpf.o

clean:
	rm oarcgdev oarcgdev-ebpf.o


run: clean oarcgdev
	@echo 'Please run `sudo cat /sys/kernel/debug/tracing/trace_pipe` to see output of the BPF programs.'
	@echo ========================
	sudo find /sys/fs/cgroup/ -depth -name "oar*" -print -exec sudo rmdir {} \;
	sudo find /sys/fs/bpf -name oar-user-jobid -print -exec sudo rm {} \;
	@echo ========================
	sudo busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager StartUnit ss oar-user-jobid.slice fail
	sudo busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager SetUnitProperties 'sba(sv)' oar-user-jobid.slice 1 1 AllowedCPUs ay 1 6
	@echo ========================
	sudo ./oarcgdev /sys/fs/cgroup/oar.slice/oar-user.slice/oar-user-jobid.slice /dev/nvidia1 /dev/nvidia3
	@echo ========================
	sudo busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager StartUnit ss oar-user-jobid-taskid.slice fail
	sudo busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager SetUnitProperties 'sba(sv)' oar-user-jobid-taskid.slice 1 1 AllowedCPUs ay 1 1
	@echo ========================
	sudo ./oarcgdev /sys/fs/cgroup/oar.slice/oar-user.slice/oar-user-jobid.slice/oar-user-jobid-taskid.slice /dev/nvidia1 /dev/nvidia3 /dev/nvidia0
