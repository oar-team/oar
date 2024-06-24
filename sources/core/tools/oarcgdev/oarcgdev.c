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

#include <linux/limits.h>
#include <unistd.h>
#include <sys/mount.h>
#include <sys/stat.h>

#define clean_errno() (errno == 0 ? "None" : strerror(errno))
#define log_err(MSG, ...) fprintf(stderr, "(%s:%d: errno: %s) " MSG "\n", \
	__FILE__, __LINE__, clean_errno(), ##__VA_ARGS__)

/*
 * Usage: oarcgdev <bpffs_path> <cgroup_path> <dev> [<dev> [<dev> [...]]]
 * Where dev is in the form: devtype:major:minor
 */
int main(int argc, char **argv)
{
	struct bpf_object *obj;
	struct bpf_program *prog;
	int error = EXIT_FAILURE;
	int cgroup_fd, cgroup_procs_fd;
	__u64 denykeys[32];
	int extra_prog_load_log_flags = 0;

	if (argc < 4) {
		fprintf(stderr, "Error: %s requires at least 3 parameters\n", argv[0]);
		return error;
	}
	const char* bpffs_path = argv[1];
	const char* cgroup_path = argv[2];
	printf("bpffs: %s, cgroup: %s\n", bpffs_path, cgroup_path);


	for (int i = 0; i < (argc - 3); i++) {
		struct stat s;
		if (stat(argv[i + 3], &s) == -1) {
			fprintf(stderr, "Error: invalid device definition %s\n", argv[i + 3]);
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
			fprintf(stderr, "Error: %s is not a block or a character device, other are not supported\n", argv[i]);
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

	obj = bpf_object__open_file(DEV_CGROUP_PROG, &opts);
	if (!obj) {
		printf("Failed to open BPF object\n");
		return -errno;
	}

	prog = bpf_object__next_program(obj, NULL);
	if (!prog) {
		printf("Failed to get BPF program\n");
		return -ENOENT;
	}

	bpf_program__set_type(prog, BPF_PROG_TYPE_CGROUP_DEVICE);
	if ((error = bpf_object__load(obj))) {
		printf("Failed to load BPF program\n");
		bpf_object__close(obj);
		return(error);
	}

	if ((error = bpf_program__pin(prog, bpffs_path)) < 0 ) {
		printf("Failed to pin BPF program\n");
		bpf_object__close(obj);
		return(error);
	}

	struct bpf_map *denymap;

	//bpf_map_create(BPF_MAP_TYPE_HASH, "denymap", 
	if (!(denymap = bpf_object__find_map_by_name(obj, "denymap"))) {
		printf("Failed to find BPF map\n");
		bpf_object__close(obj);
		return -ENOENT;
	}

	__u8 denyvalue = 0;
	for (int i = 0; i < (argc - 3); i++) {
		if (bpf_map__update_elem(denymap, &denykeys[i], sizeof(denykeys[i]), &denyvalue, sizeof(denyvalue), BPF_ANY)) {
			printf("Failed to write in map\n");
			return -EINVAL;
		}
	}

	char cgroup_procs_path[PATH_MAX + 1];
	pid_t pid = getpid();

	cgroup_fd = open(cgroup_path, O_RDONLY);
	if (cgroup_fd < 0) {
		fprintf(stderr, "Failed to open cgroup\n");
		return cgroup_fd;
	}

	snprintf(cgroup_procs_path, sizeof(cgroup_procs_path),
		 "%s/cgroup.procs", cgroup_path);

	cgroup_procs_fd = open(cgroup_procs_path, O_WRONLY);
	if (cgroup_procs_fd < 0) {
		fprintf(stderr, "Failed to open cgroup procs\n");
		return cgroup_procs_fd;
	}

	if (dprintf(cgroup_procs_fd, "%d\n", pid) < 0) {
		fprintf(stderr, "Failed to joining cgroup\n");
		return -EINVAL;
	}

	close(cgroup_procs_fd);

	/* Attach bpf program */
	if (bpf_prog_attach(bpf_program__fd(prog), cgroup_fd, BPF_CGROUP_DEVICE, 0)) {
		printf("Failed to attach DEV_CGROUP program");
		return -EINVAL;
	}

	system("nvidia-smi");
	error = 0;

	return error;
}
