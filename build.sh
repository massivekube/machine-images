#!/bin/bash
# Heavily inspired by https://github.com/mcrute/alpine-ec2-ami/blob/master/make_ami.sh

apt update
apt install e2fsprogs

mkfs.ext4 /dev/xvdf
mkdir /mnt/target
mount /dev/xvdf /mnt/target
e2label /dev/xvdf /

mkdir /mnt/target/proc
mkdir /mnt/target/dev
mkdir /mnt/target/sys

mount -t proc none /mnt/target/proc
mount --bind /dev /mnt/target/dev
mount --bind /sys /mnt/target/sys

wget -O /tmp/apk-tools.tar.gz http://dl-cdn.alpinelinux.org/alpine/v3.8/main/x86_64/apk-tools-static-2.10.0-r3.apk
tar -xf /tmp/apk-tools.tar.gz 

wget -O /tmp/alpine-keys.apk http://dl-cdn.alpinelinux.org/alpine/v3.8/main/x86_64/alpine-keys-2.1-r1.apk
./sbin/apk.static add --root /mnt/target /tmp/alpine-keys.apk --initdb --allow-untrusted

cat > /mnt/target/etc/apk/repositories <<-EOF
http://dl-cdn.alpinelinux.org/alpine/v3.8/main
EOF

install -Dm644 /etc/resolv.conf /mnt/target/etc/resolv.conf

./sbin/apk.static add --root /mnt/target --update-cache --initdb alpine-base

chroot /mnt/target apk add --no-cache --update linux-virt chrony e2fsprogs mkinitfs openssh sudo tzdata
chroot /mnt/target apk del ntpd
chroot /mnt/target apk add --no-cache --no-scripts syslinux

sed -Ei '/^tty\d/s/^/#/' /mnt/target/etc/inittab

chroot /mnt/target /sbin/mkinitfs $(basename $(find /mnt/target/lib/modules/* -maxdepth 0))

	sed -Ei -e "s|^[# ]*(root)=.*|\1=LABEL=/|" \
		-e "s|^[# ]*(default_kernel_opts)=.*|\1=\"console=ttyS0 console=tty0 audit=1 cgroup_enable=memory swapaccount=1\"|" \
		-e "s|^[# ]*(serial_port)=.*|\1=ttyS0|" \
		-e "s|^[# ]*(modules)=.*|\1=sd-mod,usb-storage,ext4|" \
		-e "s|^[# ]*(default)=.*|\1=virt|" \
		-e "s|^[# ]*(timeout)=.*|\1=1|" \
		/mnt/target/etc/update-extlinux.conf

chroot /mnt/target /sbin/extlinux --install /boot
chroot /mnt/target /sbin/update-extlinux --warn-only

cat > /mnt/target/etc/fstab <<-EOF
# <fs>     <mountpoint>  <type>  <opts>            <dump/pass>
LABEL=/    /             ext4    defaults          1 1
EOF

cat > /mnt/target/etc/network/interfaces <<-EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

chroot /mnt/target rc-update add sshd default
chroot /mnt/target rc-update add chronyd default
chroot /mnt/target rc-update add networking default

chroot /mnt/target rc-update add devfs sysinit
chroot /mnt/target rc-update add dmesg sysinit
chroot /mnt/target rc-update add mdev sysinit
chroot /mnt/target rc-update add hwdrivers sysinit

chroot /mnt/target rc-update add modules boot
chroot /mnt/target rc-update add hwclock boot
chroot /mnt/target rc-update add swap boot
chroot /mnt/target rc-update add hostname boot
chroot /mnt/target rc-update add sysctl boot
chroot /mnt/target rc-update add bootmisc boot
chroot /mnt/target rc-update add syslog boot
chroot /mnt/target rc-update add acpid boot

chroot /mnt/target rc-update add killprocs shutdown
chroot /mnt/target rc-update add savecache shutdown
chroot /mnt/target rc-update add mount-ro shutdown

# default config
cat > /mnt/target/etc/chrony/chrony.conf <<-EOF
server 169.254.169.123 prefer iburst
driftfile /var/lib/chrony/chrony.drift
rtcsync
EOF

## TEMPORARY HACK ##
sed -i '/%wheel .* NOPASSWD: .*/s/^# //' /mnt/target/etc/sudoers

chroot /mnt/target /usr/sbin/addgroup alpine
chroot /mnt/target /usr/sbin/adduser -h /home/alpine -s /bin/sh -G alpine -D alpine
chroot /mnt/target /usr/sbin/addgroup alpine wheel
chroot /mnt/target /usr/bin/passwd -u alpine

chroot /mnt/target mkdir /home/alpine/.ssh/

cp /tmp/assets/authorized_keys /mnt/target/home/alpine/.ssh/authorized_keys

chroot /mnt/target chown alpine:alpine -R /home/alpine/.ssh/
chroot /mnt/target chmod 0700 /home/alpine/.ssh/
chroot /mnt/target chmod 0600 /home/alpine/.ssh/authorized_keys

## TEMPORARY HACK ##

rm -f \
	/mnt/target/var/cache/apk/* \
	/mnt/target/etc/resolv.conf \
	/mnt/target/root/.ash_history \
	/mnt/target/etc/*-

umount \
	/mnt/target/dev \
	/mnt/target/proc \
	/mnt/target/sys

umount /mnt/target