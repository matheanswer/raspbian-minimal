#!/bin/bash

if [ -f config ]; then
	source config
fi

# Image creation
rm -rf ${IMG_FILE} ${IMG_FILE%.img}.zip
ROOTFS_SIZE=$(du -BM -s ${ROOTFS_DIR}/ | cut -f 1 | sed "s/M//")
IMG_SIZE=$((${BOOT_SIZE} + ${ROOTFS_SIZE} + 10))
truncate -s "${IMG_SIZE}M" "${IMG_FILE}"

sfdisk "${IMG_FILE}" --label dos << EOF
,${BOOT_SIZE}M,c
;
EOF

LOOP_DEV=$(losetup -f)
losetup -P ${LOOP_DEV} ${IMG_FILE}

mkfs.vfat -F 32 -n BOOT "${LOOP_DEV}p1"
mkfs.ext4 "${LOOP_DEV}p2"

rm -rf boot root
mkdir boot root

mount "${LOOP_DEV}p1" boot
mount "${LOOP_DEV}p2" root

rsync -rtx "${ROOTFS_DIR}/boot/" boot/
rsync -aHAXx --exclude /var/cache/apt/archives --exclude /boot "${ROOTFS_DIR}/" root/
mkdir root/boot

BOOT_PARTUUID="$(lsblk -dno PARTUUID ${LOOP_DEV}p1)"
ROOT_PARTUUID="$(lsblk -dno PARTUUID ${LOOP_DEV}p2)"

sed -i "s/BOOTDEV/PARTUUID=${BOOT_PARTUUID}/" root/etc/fstab
sed -i "s/ROOTDEV/PARTUUID=${ROOT_PARTUUID}/" root/etc/fstab
sed -i "s/ROOTDEV/PARTUUID=${ROOT_PARTUUID}/" boot/cmdline.txt

sync
umount boot root
rm -rf boot root
losetup -d ${LOOP_DEV}

#zip ${IMG_FILE%.img}.zip ${IMG_FILE}
#xz -zkT 0 ${IMG_FILE}
xz -k ${IMG_FILE}
