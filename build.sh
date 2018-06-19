#!/bin/bash
# Heavily inspired by https://github.com/mcrute/alpine-ec2-ami/blob/master/make_ami.sh

set -e

apt update
apt install e2fsprogs

mkfs.ext4 /dev/xvdf
mkdir /mnt/target
mount /dev/xvdf /mnt/target
e2label /dev/xvdf /

mount -t proc none /mnt/target/proc
mount --bind /dev /mnt/target/dev
mount --bind /sys /mnt/target/sys

wget -O /tmp/apk-tools.tar.gz https://github.com/alpinelinux/apk-tools/releases/download/v2.8.2/apk-tools-2.8.2-x86_64-linux.tar.gz
tar -xf /tmp/apk-tools.tar.gz --strip-components=1 -C /usr/bin

wget -O /tmp/alpine-keys.apk http://dl-cdn.alpinelinux.org/alpine/v3.7/main/x86_64/alpine-keys-2.1-r1.apk
apk add --root /mnt/target /tmp/alpine-keys.apk --initdb --allow-untrusted

cat > /mnt/target/etc/apk/repositories <<-EOF
http://dl-cdn.alpinelinux.org/alpine/v3.7/main
EOF

install -Dm644 /etc/resolv.conf /mnt/target/etc/resolv.conf

apk add --root /mnt/target --update-cache --initdb alpine-base

chroot "/mnt/target" apk add --no-cache --update chrony e2fsprogs mkinitfs openssh sudo tzdata linux-vanilla
chroot "/mnt/target" apk add --no-cache --no-scripts syslinux

chroot "/mnt/target" /sbin/mkinitfs $(basename $(find /mnt/target/lib/modules/* -maxdepth 0))

sed -Ei -e "s|^[# ]*(root)=.*|\1=LABEL=/|" \
		-e "s|^[# ]*(default_kernel_opts)=.*|\1=\"console=ttyS0 console=tty0 audit=1 cgroup_enable=memory swapaccount=1\"|" \
		-e "s|^[# ]*(serial_port)=.*|\1=ttyS0|" \
		-e "s|^[# ]*(modules)=.*|\1=ext4|" \
		-e "s|^[# ]*(default)=.*|\1=vanilla|" \
		-e "s|^[# ]*(timeout)=.*|\1=0|" \
		/mnt/target/etc/update-extlinux.conf

chroot /mnt/target /sbin/extlinux --install /boot
chroot /mnt/target /sbin/update-extlinux --warn-only