#!/bin/bash

adduser pneyron sudo

cat <<'EOF' | debconf-set-selections
kexec-tools	kexec-tools/load_kexec	boolean	true
kexec-tools	kexec-tools/use_grub_config	boolean	true
EOF

apt install --yes libbpf-dev clang make bash-completion kexec-tools nvidia-kernel-dkms bpftool

reboot
