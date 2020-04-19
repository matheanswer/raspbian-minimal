This project is a very basic rewrite of pi-gen, the tool used to create the official Raspbian images https://github.com/RPi-Distro/pi-gen 

The goal is to build a minimal Raspbian image to better suit my needs.

Dependencies:
```
coreutils qemu-user-static debootstrap dosfstools rsync xz-utils
```
Confirmed to work on debian buster i386 only:
```
sudo ./build.sh
```