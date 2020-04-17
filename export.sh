#!/bin/bash

STYLE='\e[1;33m' # bold yellow
CLEAR='\e[0m'

if [ -f config ]; then
	source config
fi

ROOTFS_DIR="${ROOTFS_DIR:-"rootfs"}"
BOOT_SIZE="${BOOT_SIZE:-"100"}"
IMG_NAME="${IMG_NAME:-"raspbian-minimal"}"
IMG_FILE="${IMG_NAME}-$(date +%Y-%m-%d).img"

# Image creation
echo -e "${STYLE}building image${CLEAR}"
rm -f ${IMG_FILE} 
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

echo -e "${STYLE}copying boot and root filesystem${CLEAR}"
rsync -rtx --stats -h "${ROOTFS_DIR}/boot/" boot/
rsync -aHAXx --stats -h --exclude /var/cache/apt/archives --exclude /boot "${ROOTFS_DIR}/" root/
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

if [ ! "${SKIP_COMPRESS}" == "1" ]; then
	echo -e "${STYLE}compressing with xz${CLEAR}"
	rm -f ${IMG_FILE}.xz
	xz -zkvT 0 ${IMG_FILE}
else
	echo -e "${STYLE}skipping compression${CLEAR}"
fi