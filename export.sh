#!/bin/bash

STYLE='\e[1;33m' # bold yellow
CLEAR='\e[0m'

if [ -f config ]; then
	source config
fi

WORK_DIR="${WORK_DIR:-"."}"
ROOTFS_DIR="${WORK_DIR}/rootfs"
BOOT_MNT="${WORK_DIR}/boot_mnt"
ROOT_MNT="${WORK_DIR}/root_mnt"

BOOT_SIZE="${BOOT_SIZE:-"100"}"
IMG_NAME="${IMG_NAME:-"raspbian-minimal"}"
IMG_FILE="${IMG_NAME}-$(date +%Y-%m-%d).img"

# Image
echo -e "${STYLE}building image file${CLEAR}"
rm -f ${IMG_FILE} 
ROOTFS_SIZE=$(du -BM -s ${ROOTFS_DIR}/ | cut -f 1 | sed "s/M//")
IMG_SIZE=$((${BOOT_SIZE} + ${ROOTFS_SIZE} + 100))
truncate -s "${IMG_SIZE}M" "${IMG_FILE}"

sfdisk "${IMG_FILE}" --label dos << EOF
,${BOOT_SIZE}M,c
;
EOF

LOOP_DEV=$(losetup -f)
losetup -P ${LOOP_DEV} ${IMG_FILE}

# only needed in docker #######################################################
#mknod "${LOOP_DEV}p1" b 259 0
#mknod "${LOOP_DEV}p2" b 259 1
# only needed in docker #######################################################

mkfs.vfat -F 32 -n BOOT "${LOOP_DEV}p1"
mkfs.ext4 "${LOOP_DEV}p2"

rm -rf ${BOOT_MNT} ${ROOT_MNT}
mkdir ${BOOT_MNT} ${ROOT_MNT}

mount "${LOOP_DEV}p1" ${BOOT_MNT}
mount "${LOOP_DEV}p2" ${ROOT_MNT}

# Copy
echo -e "${STYLE}copying boot and root filesystem${CLEAR}"
rsync -rtx --stats -h "${ROOTFS_DIR}/boot/" "${BOOT_MNT}/"
rsync -aHAXx --stats -h --exclude /var/cache/apt/archives --exclude /boot "${ROOTFS_DIR}/" "${ROOT_MNT}/"
mkdir "${ROOT_MNT}/boot"

BOOT_PARTUUID="$(lsblk -dno PARTUUID ${LOOP_DEV}p1)"
ROOT_PARTUUID="$(lsblk -dno PARTUUID ${LOOP_DEV}p2)"

sed -i "s/BOOTDEV/PARTUUID=${BOOT_PARTUUID}/" "${ROOT_MNT}/etc/fstab"
sed -i "s/ROOTDEV/PARTUUID=${ROOT_PARTUUID}/" "${ROOT_MNT}/etc/fstab"
sed -i "s/ROOTDEV/PARTUUID=${ROOT_PARTUUID}/" "${BOOT_MNT}/cmdline.txt"

sync
umount ${BOOT_MNT} ${ROOT_MNT}
rm -rf ${BOOT_MNT} ${ROOT_MNT}

losetup -d ${LOOP_DEV}

# only needed in docker #######################################################
#rm -rf "${LOOP_DEV}p*"
# only needed in docker #######################################################

# Compress
if [ ! "${SKIP_COMPRESS}" == "1" ]; then
	echo -e "${STYLE}compressing with xz${CLEAR}"
	rm -f ${IMG_FILE}.xz
	xz -zkvT 0 ${IMG_FILE}
else
	echo -e "${STYLE}skipping compression${CLEAR}"
fi