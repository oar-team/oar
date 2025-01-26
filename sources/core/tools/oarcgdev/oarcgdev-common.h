#include <linux/bpf.h>

#define MAP_MAX_DEVS 128
#define MAP_NAME denymap
#define MAP_NAME_STR "denymap"

static inline __u64 make_denykey(__u16 type, __u16 major, __u32 minor) {
	__u64 denykey;
	/* major/minor encoding is reverse engineered from bits/sysmacros.h */
	denykey  = (((__u64) (major & 0x00000ffful)) <<  8);
	denykey |= (((__u64) (major & 0xfffff000ul)) << 32);
	denykey |= (((__u64) (minor & 0x000000fful)) <<  0);
	denykey |= (((__u64) (minor & 0xffffff00ul)) << 12);
	/* arbitrary choose to encode type on the 4 MSB (unused bits) */
	switch (type) {
	case BPF_DEVCG_DEV_BLOCK:
		denykey |= (0x1ul << 60);
		break;
	case BPF_DEVCG_DEV_CHAR:
		denykey |= (0x2ul << 60);
		break;
	default:
		break;
	}
	return denykey;
}
