/* Copyright (c) 2017 Facebook
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of version 2 of the GNU General Public
 * License as published by the Free Software Foundation.
 */

#include <linux/bpf.h>
#include <linux/version.h>
#include <bpf/bpf_helpers.h>

struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__uint(max_entries, 8);
	__type(key, __u64);
	__type(value, __u8);
} denymap SEC(".maps");

SEC("cgroup/dev")
int bpf_prog1(struct bpf_cgroup_dev_ctx *ctx)
{
	short type = ctx->access_type & 0xFFFF;
	short access = ctx->access_type >> 16;
	char fmt[] = "  %d:%d    \n";

	switch (type) {
	case BPF_DEVCG_DEV_BLOCK:
		fmt[0] = 'b';
		break;
	case BPF_DEVCG_DEV_CHAR:
		fmt[0] = 'c';
		break;
	default:
		fmt[0] = '?';
		break;
	}

	if (access & BPF_DEVCG_ACC_READ)
		fmt[8] = 'r';

	if (access & BPF_DEVCG_ACC_WRITE)
		fmt[9] = 'w';

	if (access & BPF_DEVCG_ACC_MKNOD)
		fmt[10] = 'm';

	bpf_trace_printk(fmt, sizeof(fmt), ctx->major, ctx->minor);

//	if (type == BPF_DEVCG_DEV_CHAR && ctx->minor == 1 && ctx->major == 195)
//		return 0;
	__u64 key = ((__u64) ctx->minor) + (((__u64) ctx->major) << 32);
	if (type == BPF_DEVCG_DEV_CHAR && bpf_map_lookup_elem(&denymap, &key))
		return 0;
	return 1;
}

char _license[] SEC("license") = "GPL";
