kernel-fglrx-custom
===================

Script to download, configure, build, install a custom Linux kernel, with patch applied to allow building of AMD fglrx module.  Available from the Arch User Repository (AUR) as "kernel-fglrx-custom-git".

`kernel-fglrx-custom.sh` is installed to `/usr/share/kernel-fglrx-custom` if installed via Arch Linux PKGBUILD.

Since this script tinkers with GRUB, display drivers and kernels, look at the code and comments in the script to understand how to use it.  Don't rely on some summary from a forum or you'll might brick your operating system.
