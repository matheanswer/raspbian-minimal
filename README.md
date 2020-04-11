pi-gen is the tool used to create the raspberrypi.org Raspbian images
https://github.com/RPi-Distro/pi-gen

This project is a very basic rewrite of pi-gen, with the goal of building
a minimal Raspbian image to better suit my needs.

It is intended to run on Debian i386 only
Dependencies for original pi-gen :
quilt parted coreutils qemu-user-static debootstrap zerofree zip dosfstools libcap2-bin bsdtar grep rsync xz-utils curl xxd file git kmod bc

Packages this script actually uses :
coreutils? qemu-user-statitc debootstrap zip dosfstools 

Run build.sh as root
