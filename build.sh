#!/bin/bash

STYLE='\e[1;33m' # bold yellow
CLEAR='\e[0m'

if [ -f config ]; then
	source config
fi

RELEASE="${RELEASE:-"buster"}"

WORK_DIR="${WORK_DIR:-"."}"
if [ ! -d ${WORK_DIR} ]; then
	mkdir ${WORK_DIR}
fi

BOOTSTRAP_DIR="${WORK_DIR}/bootstrap"
ROOTFS_DIR="${WORK_DIR}/rootfs"

USERNAME="${USERNAME:-"pi"}"
PASSWORD="${PASSWORD:-"raspberry"}"
HOSTNAME="${HOSTNAME:-"raspberrypi"}"
LOCALE="${LOCALE:-"en_US.UTF-8"}"
TIMEZONE="${TIMEZONE:-"UTC"}"

PACKAGES+=" raspberrypi-bootloader raspberrypi-kernel libraspberrypi-bin libraspberrypi0 dosfstools fake-hwclock locales whiptail"

# Bootstrap
if [ "${SKIP_BOOTSTRAP}" == "1" ]; then
	echo -e "${STYLE}skipping bootstrap stage${CLEAR}"
else
	echo -e "${STYLE}bootstrap${CLEAR}"
	rm -rf "${BOOTSTRAP_DIR}"
	mkdir "${BOOTSTRAP_DIR}"
	qemu-debootstrap --arch armhf --components main,contrib,non-free --keyring files/raspbian.gpg ${RELEASE} ${BOOTSTRAP_DIR} http://raspbian.raspberrypi.org/raspbian
fi

# Rsync rootfs
echo -e "${STYLE}${BOOTSTRAP_DIR}/ copy to ${ROOTFS_DIR}/${CLEAR}"
rm -rf "${ROOTFS_DIR}"
rsync -aHAXx --stats -h "${BOOTSTRAP_DIR}/" "${ROOTFS_DIR}/"

# Packages
echo -e "${STYLE}apt config, update, upgrade and package install${CLEAR}"
install -v -m 644 files/sources.list "${ROOTFS_DIR}/etc/apt/sources.list"
sed -i "s/RELEASE/${RELEASE}/" "${ROOTFS_DIR}/etc/apt/sources.list"
install -v -m 644 files/99pdiffs "${ROOTFS_DIR}/etc/apt/apt.conf.d/"
install -v -m 644 files/99recommends "${ROOTFS_DIR}/etc/apt/apt.conf.d/"
chroot ${ROOTFS_DIR} apt-key add < files/raspbian.gpg.key
chroot ${ROOTFS_DIR} << EOF
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive
debconf-set-selections << SELEOF
locales locales/locales_to_be_generated multiselect ${LOCALE} UTF-8
locales locales/default_environment_locale select ${LOCALE}
SELEOF
apt-get update
apt-get dist-upgrade -y
apt-get install -y ${PACKAGES}
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF

# Start of configuration stage
echo -e "${STYLE}configuration${CLEAR}"

# User
chroot ${ROOTFS_DIR} << EOF
useradd -m -G sudo,video -s /usr/bin/zsh $USERNAME
echo "${USERNAME}:${PASSWORD}" | chpasswd
echo "root:root" | chpasswd
usermod --pass='*' root
EOF
install -v -m 644 -g 1000 -o 1000 files/zshrc "${ROOTFS_DIR}/home/${USERNAME}/.zshrc"
install -v -m 644 -g 1000 -o 1000 files/zshrc.local "${ROOTFS_DIR}/home/${USERNAME}/.zshrc.local"
sed -i "s/LOCALE/${LOCALE}/" "${ROOTFS_DIR}/home/${USERNAME}/.zshrc.local"

# Networking
echo "${HOSTNAME}" > "${ROOTFS_DIR}/etc/hostname"
echo "127.0.1.1	${HOSTNAME}" >> "${ROOTFS_DIR}/etc/hosts"
ln -sf /dev/null "${ROOTFS_DIR}/etc/systemd/network/99-default.link"

# Time Zone
chroot ${ROOTFS_DIR} << EOF
echo "${TIMEZONE}" > "/etc/timezone"
rm "/etc/localtime"
dpkg-reconfigure -f noninteractive tzdata
EOF

# Swap
#if [[ ${SWAPSIZE} -lt 100 ]]; then
#	SWAPSIZE="100"
#fi
#install -v -m 644 files/99-swappiness.conf "${ROOTFS_DIR}/etc/sysctl.d/"
#sed -i "s/#CONF_SWAPSIZE=/CONF_SWAPSIZE=${SWAPSIZE}/" "${ROOTFS_DIR}/etc/dphys-swapfile"

# Boot files
install -v -m 644 files/fstab "${ROOTFS_DIR}/etc/fstab"
install -v -m 644 files/cmdline.txt "${ROOTFS_DIR}/boot/"
install -v -m 644 files/config.txt "${ROOTFS_DIR}/boot/"

# Export
if [ ! "${SKIP_EXPORT}" == "1" ]; then
	./export.sh
else
	echo -e "${STYLE}skipping export stage${CLEAR}"
fi