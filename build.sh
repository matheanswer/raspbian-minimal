#!/bin/bash

STYLE='\e[1;33m' # bold yellow
CLEAR='\e[0m'

if [ -f config ]; then
	source config
fi

RELEASE="buster"

BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-"bootstrap"}"
ROOTFS_DIR="${ROOTFS_DIR:-"rootfs"}"

USERNAME="${USERNAME:-"pi"}"
PASSWORD="${PASSWORD:-"raspberry"}"
HOSTNAME="${HOSTNAME:-"raspberrypi"}"
LOCALE="${LOCALE:-"en_US.UTF-8"}"
TIMEZONE="${TIMEZONE:-"UTC"}"
USER_SHELL="${USER_SHELL:-"bash"}"

# Bootstrap
if [ ! "${SKIP_BOOTSTRAP}" == "1" ]; then
	echo -e "${STYLE}bootstrap${CLEAR}"
	rm -rf "${BOOTSTRAP_DIR}"
	mkdir "${BOOTSTRAP_DIR}"
	qemu-debootstrap --arch armhf --components main,contrib,non-free --keyring files/raspberrypi.gpg ${RELEASE} ${BOOTSTRAP_DIR} http://raspbian.raspberrypi.org/raspbian
else
	echo -e "${STYLE}skipping bootstrap stage${CLEAR}"
fi

# Rsync rootfs
echo -e "${STYLE}copying bootstrap${CLEAR}"
rm -rf "${ROOTFS_DIR}"
rsync -aHAXx --stats -h "${BOOTSTRAP_DIR}/" "${ROOTFS_DIR}/"

# Package manager
echo -e "${STYLE}apt configuration${CLEAR}"
install -v -m 644 files/50raspberrypi "${ROOTFS_DIR}/etc/apt/apt.conf.d/"
install -v -m 644 files/90recommends "${ROOTFS_DIR}/etc/apt/apt.conf.d/"
chroot ${ROOTFS_DIR} apt-key add < files/raspberrypi.gpg.key
chroot ${ROOTFS_DIR} << EOF
echo "deb http://raspbian.raspberrypi.org/raspbian ${RELEASE} main contrib non-free rpi" > /etc/apt/sources.list
echo "deb http://archive.raspberrypi.org/debian ${RELEASE} main" > /etc/apt/sources.list.d/raspberrypi.list
apt-get update
EOF

# Locales
# always generating en_US.UTF-8 seems to prevent warnings
echo -e "${STYLE}locales${CLEAR}"
chroot ${ROOTFS_DIR} << EOF
debconf-set-selections << SELEOF
locales locales/locales_to_be_generated multiselect ${LOCALE} UTF-8, en_US.UTF-8 UTF-8
locales locales/default_environment_locale select ${LOCALE}
SELEOF
DEBIAN_FRONTEND=noninteractive apt-get install -y locales
EOF

# Packages 
echo -e "${STYLE}packages${CLEAR}"
chroot ${ROOTFS_DIR} << EOF
export DEBIAN_FRONTEND=noninteractive
apt-get dist-upgrade -y
apt-get install -y ${PACKAGES}
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF

# User
echo -e "${STYLE}user${CLEAR}"
chroot ${ROOTFS_DIR} << EOF
useradd -m -G sudo,video -s /usr/bin/zsh $USERNAME
echo "${USERNAME}:${PASSWORD}" | chpasswd
echo "root:root" | chpasswd
usermod --pass='*' root
EOF
if [ "${USER_SHELL}" == "zsh" ]; then
	install -v -m 644 -g 1000 -o 1000 files/grml-zshrc "${ROOTFS_DIR}/home/${USERNAME}/.zshrc"
fi

# Networking
echo -e "${STYLE}networking${CLEAR}"
echo "${HOSTNAME}" > "${ROOTFS_DIR}/etc/hostname"
echo "127.0.1.1	${HOSTNAME}" >> "${ROOTFS_DIR}/etc/hosts"
ln -sf /dev/null "${ROOTFS_DIR}/etc/systemd/network/99-default.link"

# Time Zone
echo -e "${STYLE}time zone${CLEAR}"
chroot ${ROOTFS_DIR} << EOF
echo "${TIMEZONE}" > "/etc/timezone"
rm "/etc/localtime"
dpkg-reconfigure -f noninteractive tzdata
EOF

# Boot files
echo -e "${STYLE}boot files${CLEAR}"
install -v -m 644 files/fstab "${ROOTFS_DIR}/etc/fstab"
install -v -m 644 files/cmdline.txt "${ROOTFS_DIR}/boot/"
install -v -m 644 files/config.txt "${ROOTFS_DIR}/boot/"

# Export
if [ ! "${SKIP_EXPORT}" == "1" ]; then
	./export.sh
else
	echo -e "${STYLE}skipping export stage${CLEAR}"
fi