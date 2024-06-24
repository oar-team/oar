// SPDX-License-Identifier: GPL-2.0-only
/* Copyright (c) 2017 Facebook
 */

#define _GNU_SOURCE

#include <stdlib.h>
#include <errno.h>
#include <assert.h>

#include <bpf/bpf.h>
#include <bpf/libbpf.h>
#include <sys/sysmacros.h>

#include "oarcgdev-common.h"

#define DEV_CGROUP_PROG "./oarcgdev-ebpf.o"
#define ARGS_FIRST_DEV 2

#include <linux/limits.h>
#include <unistd.h>
#include <sys/mount.h>
#include <sys/stat.h>

#define clean_errno() (errno == 0 ? "None" : strerror(errno))
#define log_err(MSG, ...) fprintf(stderr, "(%s:%d: errno: %s) " MSG "\n", \
	__FILE__, __LINE__, clean_errno(), ##__VA_ARGS__)

/*
 * Usage: oarcgdev <cgroup_path> <dev> [<dev> [<dev> [...]]]
 * Where dev is in the form: devtype:major:minor
 */
int main(int argc, char **argv)
{
	struct bpf_object *obj;
	struct bpf_program *prog;
	int error = EXIT_FAILURE;
	int cgroup_fd;
	__u64 denykeys[MAP_MAX_DEVS];
	int extra_prog_load_log_flags = 0;

	if (argc < ARGS_FIRST_DEV + 1) {
		log_err("Program requires at least %d parameters\n", ARGS_FIRST_DEV);
		return error;
	}
	const char* cgroup_path = argv[1];


	for (int i = 0; i < (argc - ARGS_FIRST_DEV); i++) {
		struct stat s;
		if (stat(argv[i + ARGS_FIRST_DEV], &s) == -1) {
			log_err("%s is not a valid device\n", argv[i + ARGS_FIRST_DEV]);
			return error;
		}
		__u16 type;
		switch (s.st_mode & S_IFMT) {
		case S_IFBLK:
			type = BPF_DEVCG_DEV_BLOCK;
			break;
		case S_IFCHR:
			type = BPF_DEVCG_DEV_CHAR;
			break;
		default:
			log_err("%s is not a block or a character device, other are not supported\n", argv[i + ARGS_FIRST_DEV]);
			return error;
		}
		denykeys[i] = make_denykey(type, major(s.st_rdev), minor(s.st_rdev));
		/* sanity check: make sure our device encoding respects Linux's one */
		assert((denykeys[i] & ~(0xful << 60)) == s.st_rdev);
	}

	/* Use libbpf 1.0 API mode */
	libbpf_set_strict_mode(LIBBPF_STRICT_ALL);

	LIBBPF_OPTS(bpf_object_open_opts, opts,
		.kernel_log_level = extra_prog_load_log_flags,
	);

	if (!(obj = bpf_object__open_file(DEV_CGROUP_PROG, &opts))) {
		log_err("Failed to open BPF object");
		return -errno;
	}

	if (!(prog = bpf_object__next_program(obj, NULL))) {
		log_err("Failed to extract BPF program");
		return -errno;
	}

	bpf_program__set_type(prog, BPF_PROG_TYPE_CGROUP_DEVICE);
	if ((error = bpf_object__load(obj))) {
		log_err("Failed to load BPF program");
		error = -errno;
		bpf_object__close(obj);
		return error;
	}

	struct bpf_map *denymap;
	if (!(denymap = bpf_object__find_map_by_name(obj, MAP_NAME_STR))) {
		log_err("Failed to find BPF map");
		error = -errno;
		bpf_object__close(obj);
		return error;
	}

	__u8 denyvalue = 0;
	for (int i = 0; i < (argc - ARGS_FIRST_DEV); i++) {
		if (bpf_map__update_elem(denymap, &denykeys[i], sizeof(denykeys[i]), &denyvalue, sizeof(denyvalue), BPF_ANY)) {
			log_err("Failed to write in BPF map");
			error = -errno;
			bpf_object__close(obj);
			return error;
		}
	}

	cgroup_fd = open(cgroup_path, O_RDONLY);
	if (cgroup_fd < 0) {
		log_err("Failed to open cgroup");
		error = -errno;
		bpf_object__close(obj);
		return error;
	}

	if (bpf_prog_attach(bpf_program__fd(prog), cgroup_fd, BPF_CGROUP_DEVICE, BPF_F_ALLOW_MULTI)) {
		log_err("Failed to attach DEV_CGROUP program");
		error = -errno;
		bpf_object__close(obj);
		return error;
	}

#ifdef TEST
	char cgroup_procs_path[PATH_MAX + 1];
	pid_t pid = getpid();

	snprintf(cgroup_procs_path, sizeof(cgroup_procs_path),
		 "%s/cgroup.procs", cgroup_path);

	int cgroup_procs_fd = open(cgroup_procs_path, O_WRONLY);
	if (cgroup_procs_fd < 0) {
		log_err("Failed to open cgroup procs");
		error = -errno;
		bpf_object__close(obj);
		return error;
	}

	if (dprintf(cgroup_procs_fd, "%d\n", pid) < 0) {
		log_err("Failed to joining process to cgroup");
		error = -errno;
		bpf_object__close(obj);
		return error;
	}

	close(cgroup_procs_fd);
	system("nvidia-smi");
#endif
	error = 0;
	return error;
}
