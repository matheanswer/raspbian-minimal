This project is a very basic rewrite of pi-gen, the tool used to create the official Raspbian images https://github.com/RPi-Distro/pi-gen 

The goal is to build a vey minimal Raspbian image (no bluetooth or wifi) to better suit my needs.

It is intended to run as on debian based linux distributions only.
```
sudo ./build.sh
```
Dependencies:
coreutils qemu-user-statitc debootstrap zip dosfstools rsync

Pi-gen dependencies:
quilt parted coreutils qemu-user-static debootstrap zerofree zip dosfstools libcap2-bin bsdtar grep rsync xz-utils curl xxd file git kmod bc
