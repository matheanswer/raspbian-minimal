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
IMG_FILE_BOOT="${IMG_NAME}-$(date +%Y-%m-%d)-BOOT.img"
IMG_FILE_ROOT="${IMG_NAME}-$(date +%Y-%m-%d)-ROOT.img"

# Image
echo -e "${STYLE}building image file${CLEAR}"
rm -f ${IMG_FILE_BOOT} ${IMG_FILE_ROOT}  
ROOTFS_SIZE=$(du -BM -s ${ROOTFS_DIR}/ | cut -f 1 | sed "s/M//")
IMG_SIZE=$((${ROOTFS_SIZE} + 200))
truncate -s "${IMG_SIZE}M" "${IMG_FILE_ROOT}"
truncate -s "$((${BOOT_SIZE}+10))M" "${IMG_FILE_BOOT}"

sfdisk "${IMG_FILE_BOOT}" --label dos << EOF
,${BOOT_SIZE}M,c
EOF
sfdisk "${IMG_FILE_ROOT}" --label dos << EOF
;
EOF

LOOP_DEV_BOOT=$(losetup -f)
losetup -P ${LOOP_DEV_BOOT} ${IMG_FILE_BOOT}

LOOP_DEV_ROOT=$(losetup -f)
losetup -P ${LOOP_DEV_ROOT} ${IMG_FILE_ROOT}

# only needed in docker #######################################################
#mknod "${LOOP_DEV_BOOT}p1" b 259 0
#mknod "${LOOP_DEV_ROOT}p1" b 259 0
# only needed in docker #######################################################

mkfs.vfat -F 32 -n BOOT "${LOOP_DEV_BOOT}p1"
mkfs.ext4 "${LOOP_DEV_ROOT}p1"

rm -rf ${BOOT_MNT} ${ROOT_MNT}
mkdir ${BOOT_MNT} ${ROOT_MNT}

mount "${LOOP_DEV_BOOT}p1" ${BOOT_MNT}
mount "${LOOP_DEV_ROOT}p1" ${ROOT_MNT}

# Copy
echo -e "${STYLE}copying boot and root filesystem${CLEAR}"
rsync -rtx --stats -h "${ROOTFS_DIR}/boot/" "${BOOT_MNT}/"
rsync -aHAXx --stats -h --exclude /var/cache/apt/archives --exclude /boot "${ROOTFS_DIR}/" "${ROOT_MNT}/"
mkdir "${ROOT_MNT}/boot"

BOOT_PARTUUID="$(lsblk -dno PARTUUID ${LOOP_DEV_BOOT}p1)"
ROOT_PARTUUID="$(lsblk -dno PARTUUID ${LOOP_DEV_ROOT}p1)"

sed -i "s/BOOTDEV/PARTUUID=${BOOT_PARTUUID}/" "${ROOT_MNT}/etc/fstab"
sed -i "s/ROOTDEV/PARTUUID=${ROOT_PARTUUID}/" "${ROOT_MNT}/etc/fstab"
sed -i "s/ROOTDEV/PARTUUID=${ROOT_PARTUUID}/" "${BOOT_MNT}/cmdline.txt"

sync
umount ${BOOT_MNT} ${ROOT_MNT}
rm -rf ${BOOT_MNT} ${ROOT_MNT}

losetup -d ${LOOP_DEV_ROOT}
losetup -d ${LOOP_DEV_BOOT}

# only needed in docker #######################################################
#rm -rf "${LOOP_DEV_ROOT}p1" "${LOOP_DEV_BOOT}p1"
# only needed in docker #######################################################

# Compress
if [ ! "${SKIP_COMPRESS}" == "1" ]; then
	echo -e "${STYLE}compressing with xz${CLEAR}"
	rm -f ${IMG_FILE_BOOT}.xz
	xz -zkvT 0 ${IMG_FILE_BOOT}
	rm -f ${IMG_FILE_ROOT}.xz
	xz -zkvT 0 ${IMG_FILE_ROOT}
else
	echo -e "${STYLE}skipping compression${CLEAR}"
fi