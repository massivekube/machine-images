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