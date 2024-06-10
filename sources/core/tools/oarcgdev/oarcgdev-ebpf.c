#include <linux/bpf.h>
#include <linux/version.h>
#include <bpf/bpf_helpers.h>
#include "oarcgdev-common.h"

struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__uint(max_entries, MAP_MAX_DEVS);
	__type(key, __u64);
	__type(value, __u8);
} MAP_NAME SEC(".maps");

SEC("cgroup/dev")
int oarcgdev(struct bpf_cgroup_dev_ctx *ctx)
{
	short type = ctx->access_type & 0xffff;
#ifdef TEST
	short access = ctx->access_type >> 16;
	char fmt[] = "  %d:%d     %s";

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
#else
    char fmt[] = "  %d:%d  ";
#endif

	__u64 denykey = make_denykey(type, ctx->major, ctx->minor);

	if (bpf_map_lookup_elem(&denymap, &denykey)) {
		bpf_trace_printk(fmt, sizeof(fmt), ctx->major, ctx->minor, "DENY");
		return 0;
	}
#ifdef TEST
	bpf_trace_printk(fmt, sizeof(fmt), ctx->major, ctx->minor, "ALLOW");
#endif
	return 1;
}

char _license[] SEC("license") = "GPL";
