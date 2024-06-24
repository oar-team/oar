// SPDX-License-Identifier: GPL-2.0-only
/* Copyright (c) 2017 Facebook
 */

#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <assert.h>
#include <sys/time.h>

#include <linux/bpf.h>
#include <bpf/bpf.h>
#include <bpf/libbpf.h>
#include <sys/sysmacros.h>

//#include "cgroup_helpers.h"
//#include "testing_helpers.h"

#include "oarcgdev-common.h"

#define DEV_CGROUP_PROG "./oarcgdev-ebpf.o"

#define TEST_CGROUP "/test-bpf-based-device-cgroup/"

#define DEV_DELIM ":"

/* cgroup_helpers */
#include <sched.h>
#include <linux/limits.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/mount.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <ftw.h>

#define clean_errno() (errno == 0 ? "None" : strerror(errno))
#define log_err(MSG, ...) fprintf(stderr, "(%s:%d: errno: %s) " MSG "\n", \
	__FILE__, __LINE__, clean_errno(), ##__VA_ARGS__)

#define WALK_FD_LIMIT			16

#define CGROUP_MOUNT_PATH		"/mnt"
#define CGROUP_MOUNT_DFLT		"/sys/fs/cgroup"
#define CGROUP_WORK_DIR			"/cgroup-test-work-dir"

#define format_cgroup_path_pid(buf, path, pid) \
	snprintf(buf, sizeof(buf), "%s%s%d%s", CGROUP_MOUNT_PATH, \
	CGROUP_WORK_DIR, pid, path)

#define format_cgroup_path(buf, path) \
	format_cgroup_path_pid(buf, path, getpid())

/**
 * create_and_get_cgroup() - Create a cgroup, relative to workdir, and get the FD
 * @relative_path: The cgroup path, relative to the workdir, to join
 *
 * This function creates a cgroup under the top level workdir and returns the
 * file descriptor. It is idempotent.
 *
 * On success, it returns the file descriptor. On failure it returns -1.
 * If there is a failure, it prints the error to stderr.
 */
int create_and_get_cgroup(const char *relative_path)
{
	char cgroup_path[PATH_MAX + 1];
	int fd;

	format_cgroup_path(cgroup_path, relative_path);
	if (mkdir(cgroup_path, 0777) && errno != EEXIST) {
		log_err("mkdiring cgroup %s .. %s", relative_path, cgroup_path);
		return -1;
	}

	fd = open(cgroup_path, O_RDONLY);
	if (fd < 0) {
		log_err("Opening Cgroup");
		return -1;
	}

	return fd;
}

static int __enable_controllers(const char *cgroup_path, const char *controllers)
{
	char path[PATH_MAX + 1];
	char enable[PATH_MAX + 1];
	char *c, *c2;
	int fd, cfd;
	ssize_t len;

	/* If not controllers are passed, enable all available controllers */
	if (!controllers) {
		snprintf(path, sizeof(path), "%s/cgroup.controllers",
			 cgroup_path);
		fd = open(path, O_RDONLY);
		if (fd < 0) {
			log_err("Opening cgroup.controllers: %s", path);
			return 1;
		}
		len = read(fd, enable, sizeof(enable) - 1);
		if (len < 0) {
			close(fd);
			log_err("Reading cgroup.controllers: %s", path);
			return 1;
		} else if (len == 0) { /* No controllers to enable */
			close(fd);
			return 0;
		}
		enable[len] = 0;
		close(fd);
	} else {
		strncpy(enable, controllers, sizeof(enable));
	}

	snprintf(path, sizeof(path), "%s/cgroup.subtree_control", cgroup_path);
	cfd = open(path, O_RDWR);
	if (cfd < 0) {
		log_err("Opening cgroup.subtree_control: %s", path);
		return 1;
	}

	for (c = strtok_r(enable, " ", &c2); c; c = strtok_r(NULL, " ", &c2)) {
		if (dprintf(cfd, "+%s\n", c) <= 0) {
			log_err("Enabling controller %s: %s", c, path);
			close(cfd);
			return 1;
		}
	}
	close(cfd);
	return 0;
}


static int nftwfunc(const char *filename, const struct stat *statptr,
		    int fileflags, struct FTW *pfwt)
{
	if ((fileflags & FTW_D) && rmdir(filename))
		log_err("Removing cgroup: %s", filename);
	return 0;
}

static int join_cgroup_from_top(const char *cgroup_path)
{
	char cgroup_procs_path[PATH_MAX + 1];
	pid_t pid = getpid();
	int fd, rc = 0;

	snprintf(cgroup_procs_path, sizeof(cgroup_procs_path),
		 "%s/cgroup.procs", cgroup_path);

	fd = open(cgroup_procs_path, O_WRONLY);
	if (fd < 0) {
		log_err("Opening Cgroup Procs: %s", cgroup_procs_path);
		return 1;
	}

	if (dprintf(fd, "%d\n", pid) < 0) {
		log_err("Joining Cgroup");
		rc = 1;
	}

	close(fd);
	return rc;
}

/**
 * join_cgroup() - Join a cgroup
 * @relative_path: The cgroup path, relative to the workdir, to join
 *
 * This function expects a cgroup to already be created, relative to the cgroup
 * work dir, and it joins it. For example, passing "/my-cgroup" as the path
 * would actually put the calling process into the cgroup
 * "/cgroup-test-work-dir/my-cgroup"
 *
 * On success, it returns 0, otherwise on failure it returns 1.
 */
int join_cgroup(const char *relative_path)
{
	char cgroup_path[PATH_MAX + 1];

	format_cgroup_path(cgroup_path, relative_path);
	return join_cgroup_from_top(cgroup_path);
}

/**
 * cleanup_cgroup_environment() - Cleanup Cgroup Testing Environment
 *
 * This is an idempotent function to delete all temporary cgroups that
 * have been created during the test, including the cgroup testing work
 * directory.
 *
 * At call time, it moves the calling process to the root cgroup, and then
 * runs the deletion process. It is idempotent, and should not fail, unless
 * a process is lingering.
 *
 * On failure, it will print an error to stderr, and try to continue.
 */
void cleanup_cgroup_environment(void)
{
	char cgroup_workdir[PATH_MAX + 1];

	format_cgroup_path(cgroup_workdir, "");
	join_cgroup_from_top(CGROUP_MOUNT_PATH);
	nftw(cgroup_workdir, nftwfunc, WALK_FD_LIMIT, FTW_DEPTH | FTW_MOUNT);
}
/**
 * setup_cgroup_environment() - Setup the cgroup environment
 *
 * After calling this function, cleanup_cgroup_environment should be called
 * once testing is complete.
 *
 * This function will print an error to stderr and return 1 if it is unable
 * to setup the cgroup environment. If setup is successful, 0 is returned.
 */
int setup_cgroup_environment(void)
{
	char cgroup_workdir[PATH_MAX - 24];

	format_cgroup_path(cgroup_workdir, "");

	if (unshare(CLONE_NEWNS)) {
		log_err("unshare");
		return 1;
	}

	if (mount("none", "/", NULL, MS_REC | MS_PRIVATE, NULL)) {
		log_err("mount fakeroot");
		return 1;
	}

	if (mount("none", CGROUP_MOUNT_PATH, "cgroup2", 0, NULL) && errno != EBUSY) {
		log_err("mount cgroup2");
		return 1;
	}

	/* Cleanup existing failed runs, now that the environment is setup */
	cleanup_cgroup_environment();

	if (mkdir(cgroup_workdir, 0777) && errno != EEXIST) {
		log_err("mkdir cgroup work dir");
		return 1;
	}

	/* Enable all available controllers to increase test coverage */
	if (__enable_controllers(CGROUP_MOUNT_PATH, NULL) ||
	    __enable_controllers(cgroup_workdir, NULL))
		return 1;

	return 0;
}

int cgroup_setup_and_join(const char *path) {
	int cg_fd;

	if (setup_cgroup_environment()) {
		fprintf(stderr, "Failed to setup cgroup environment\n");
		return -EINVAL;
	}

	cg_fd = create_and_get_cgroup(path);
	if (cg_fd < 0) {
		fprintf(stderr, "Failed to create test cgroup\n");
		cleanup_cgroup_environment();
		return cg_fd;
	}

	if (join_cgroup(path)) {
		fprintf(stderr, "Failed to join cgroup\n");
		cleanup_cgroup_environment();
		return -EINVAL;
	}
	return cg_fd;
}

/* cgroup_helpers */

/*
 * Usage: oarcgdev <bpffs_filename> <cgroup_path> <dev> [<dev> [<dev> [...]]]
 * Where dev is in the form: devtype:major:minor
 */
int main(int argc, char **argv)
{
	struct bpf_object *obj;
	int error = EXIT_FAILURE;
	int prog_fd, denymap_fd, cgroup_fd;
	__u64 denykeys[32];
	int extra_prog_load_log_flags = 0;

	if (argc < 4) {
		fprintf(stderr, "Error: %s requires at least 3 parameters\n", argv[0]);
		return error;
	}
	const char* bpffs_filename = argv[1];
	const char* cgroup_path = argv[2];
	printf("bpffs: %s, cgroup: %s\n", bpffs_filename, cgroup_path);


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
			fprintf(stderr, "Error: %s is not a char device, other are not supported\n", argv[i]);
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
	struct bpf_program *prog;

	obj = bpf_object__open_file(DEV_CGROUP_PROG, &opts);
	if (!obj) {
		printf("Failed to open program\n");
		return -errno;
	}

	prog = bpf_object__next_program(obj, NULL);
	if (!prog) {
		printf("Failed to get program\n");
		return -ENOENT;
	}

	bpf_program__set_type(prog, BPF_PROG_TYPE_CGROUP_DEVICE);
	if ((error = bpf_object__load(obj))) {
		printf("Failed to load program\n");
		bpf_object__close(obj);
		return(error);
	}

	if ((error = bpf_program__pin(prog, "/sys/fs/bpf/toto42")) < 0 ) {
		printf("Failed to pin program\n");
		bpf_object__close(obj);
		return(error);
	}

	prog_fd = bpf_program__fd(prog);

	struct bpf_map *map;

	if (!(map = bpf_object__find_map_by_name(obj, "denymap"))) {
		printf("Failed to find map\n");
		bpf_object__close(obj);
		return -ENOENT;
	}

	denymap_fd = bpf_map__fd(map);

	__u8 denyvalue = 0;
	for (int i = 0; i < (argc - 3); i++) {
		if (bpf_map_update_elem(denymap_fd, &denykeys[i], &denyvalue, 0)) {
			printf("Failed to write in map\n");
			goto out;
		}
	}

	cgroup_fd = cgroup_setup_and_join(TEST_CGROUP);
	if (cgroup_fd < 0) {
		printf("Failed to create test cgroup\n");
		goto out;
	}

	/* Attach bpf program */
	if (bpf_prog_attach(prog_fd, cgroup_fd, BPF_CGROUP_DEVICE, 0)) {
		printf("Failed to attach DEV_CGROUP program");
		goto err;
	}

	system("nvidia-smi");
	error = 0;

err:
	cleanup_cgroup_environment();

out:
	return error;
}
