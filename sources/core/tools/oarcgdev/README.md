oarcgdev
========

A simple tool to deny access to some devices in a cgroup (v2).  Use eBPF to
insert a program into the kernel to deny access to devices.  oarcgdev is the
userland program that defines and shares a device black list with the
oarcgdev.bpf kernel program.  oarcgdev.bpf receives access requests to devices
by process running in the cgroup, and denies when the device match against the
black list.

Usage:
------

oarcgdev <cgroup path> <dev path> [<dev path> [...]]

Debug:
------

The actions of oarcgdev are traced and shown using
```
cat /sys/kernel/debug/tracing/trace_pipe
```
