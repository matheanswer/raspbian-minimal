#!/bin/bash

# pi-gen is the tool used to create the raspberrypi.org Raspbian images
# https://github.com/RPi-Distro/pi-gen

# This project is a very basic rewrite of pi-gen, with the goal of building
# a minimal Raspbian image to better suit my needs.

# It is intended to run on Debian i386 only
# Dependencies for original pi-gen :
# quilt parted coreutils qemu-user-static debootstrap zerofree zip dosfstools libcap2-bin bsdtar grep rsync xz-utils curl xxd file git kmod bc

# Packages this script actually uses :
# coreutils? qemu-user-statitc debootstrap zip dosfstools 

# Execute script as root

RELEASE="buster"

USERNAME="pi"
PASSWORD="raspberry"

HOSTNAME="raspberrypi"
LOCALE="en_US.UTF-8"
TIMEZONE="Europe/Paris"

PACKAGES="raspberrypi-bootloader raspberrypi-kernel"    # Bootloader and kernel
PACKAGES+=" libraspberrypi-bin libraspberrypi0"         # Video driver
PACKAGES+=" dphys-swapfile fake-hwclock dosfstools"     # Hardware utilities
PACKAGES+=" btrfs-progs sudo dhcpcd5 whiptail" 
PACKAGES+=" ssh ssh-import-id ca-certificates curl git"
PACKAGES+=" vim zsh neofetch"
#PACKAGES+=" glances steamlink kodi"

IMG_FILE="raspbian-minimal-$(date +%Y-%m-%d).img"

BOOT_SIZE=100 # MB

ROOTFS_DIR="rootfs"

rm -rf "${ROOTFS_DIR}"
mkdir "${ROOTFS_DIR}"

# Bootstrap
qemu-debootstrap --arch armhf --components main,contrib,non-free --keyring files/raspberrypi.gpg ${RELEASE} ${ROOTFS_DIR} http://raspbian.raspberrypi.org/raspbian

# Package manager
install -m 644 files/50raspberrypi "${ROOTFS_DIR}/etc/apt/apt.conf.d/"
install -m 644 files/90recommends "${ROOTFS_DIR}/etc/apt/apt.conf.d/"

chroot ${ROOTFS_DIR} apt-key add < files/raspberrypi.gpg.key
chroot ${ROOTFS_DIR} << EOF
echo "deb http://raspbian.raspberrypi.org/raspbian ${RELEASE} main contrib non-free rpi" > /etc/apt/sources.list
echo "deb http://archive.raspberrypi.org/debian ${RELEASE} main" > /etc/apt/sources.list.d/raspberrypi.list
apt-get update
EOF

# Locales (generating en_US.UTF-8 prevents warnings)
chroot ${ROOTFS_DIR} << EOF
debconf-set-selections << SELEOF
locales locales/locales_to_be_generated multiselect ${LOCALE} UTF-8, en_US.UTF-8 UTF-8
locales locales/default_environment_locale select ${LOCALE}
SELEOF
apt-get install -y locales
EOF     

# Packages
chroot ${ROOTFS_DIR} << EOF
apt-get dist-upgrade -y
apt-get install -y ${PACKAGES}
EOF

# Networking
echo "${HOSTNAME}" > "${ROOTFS_DIR}/etc/hostname"
echo "127.0.1.1	${HOSTNAME}" >> "${ROOTFS_DIR}/etc/hosts"
ln -sf /dev/null "${ROOTFS_DIR}/etc/systemd/network/99-default.link"

# User
chroot ${ROOTFS_DIR} << EOF
useradd -m -G sudo,video $USERNAME
echo "${USERNAME}:${PASSWORD}" | chpasswd
echo "root:root" | chpasswd
usermod --pass='*' root
EOF

# Time Zone
chroot ${ROOTFS_DIR} << EOF
echo "${TIMEZONE}" > "/etc/timezone"
rm "/etc/localtime"
dpkg-reconfigure -f noninteractive tzdata
EOF

# Boot files
install -v -m 644 files/fstab "${ROOTFS_DIR}/etc/fstab"
install -m 644 files/cmdline.txt "${ROOTFS_DIR}/boot/"
install -m 644 files/config.txt "${ROOTFS_DIR}/boot/"

# Image creation
ROOTFS_SIZE=$(du -BM -s ${ROOTFS_DIR}/ | cut -f 1 | sed "s/M//")
IMG_SIZE=$((${BOOT_SIZE} + ${ROOTFS_SIZE}))
truncate -s "${IMG_SIZE}M" "${IMG_FILE}"

sfdisk "${IMG_FILE}" --label dos << EOF
,${BOOT_SIZE}M,c
;
EOF

LOOP_DEV=$(losetup -f)
losetup ${LOOP_DEV} ${IMG_FILE}

mkfs.vfat -F 32 -n BOOT "${LOOP_DEV}p1"
mkfs.ext4 "${LOOP_DEV}p2"

rm -rf boot root
mkdir boot root

mount "${LOOP_DEV}p1" boot
mount "${LOOP_DEV}p2" root

cp ${ROOTFS_DIR}/* root
mv root/boot/* boot

#should explore rsync, probably more "elegant"
#rsync -rtx "${ROOTFS_DIR}/boot/" boot/
#rsync -aHAXx --exclude /boot "${ROOTFS_DIR}/" root/
#mkdir root/boot

BOOT_PARTUUID="$(lsblk -dno PARTUUID ${LOOP_DEV}p1)"
ROOT_PARTUUID="$(lsblk -dno PARTUUID ${LOOP_DEV}p2)"

sed -i "s/BOOTDEV/PARTUUID=${BOOT_PARTUUID}/" root/etc/fstab
sed -i "s/ROOTDEV/PARTUUID=${ROOT_PARTUUID}/" root/etc/fstab
sed -i "s/ROOTDEV/PARTUUID=${ROOT_PARTUUID}/" boot/cmdline.txt

sync
umount boot root
rm -rf boot root
losetup -d ${LOOP_DEV}

zip ${IMG_FILE%.img}.zip ${IMG_FILE}

