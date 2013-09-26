kernel-fglrx-custom
===================

This script's actions:
	Download kernel tarball if not found
	Extract kernel tarball if source folder not found
	Symlink source/build folders to /lib/modules/, /usr/src/
	Apply kernel source patches specified in PATCH= variable (e.g. Brain**** scheduler)
	Clean the kernel source tree
	Copy a local .config file into the source tree, or the currently running kernel's config if a local .config isn't found
	Launch menuconfig
	Build the kernel (using parallel make jobs)
	Apply patch to headers which is required for fglrx
	Build initrd image via mkinitcpio
	Install initrd/vmlinuz
	Update grub via grub-mkconfig

The included BFS [by Con Kolivas] patches are taken from http://ck.kolivas.org/patches/bfs/
	
This package is available from the Arch User Repository (AUR) as "kernel-fglrx-custom-git".

`kernel-fglrx-custom.sh` is installed to `/usr/share/kernel-fglrx-custom` if installed via Arch Linux PKGBUILD.

Since this script tinkers with GRUB, display drivers and kernels, look at the code and comments in the script to understand how to use it.  Don't rely on some summary from a forum or you'll probably brick your operating system.

Running the "./makeit" script may suffice for the lazy among you who just want to get your amazing legacy GPUs working again.
