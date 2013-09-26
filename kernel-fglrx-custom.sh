#!/bin/bash

# kernel-fglrx-custom.sh
#
# Kernel build script to enable use of old Radeons on newer (but not
# quite _really new_) kernels.
#
# Mark K Cowan, mark@battlesnake.co.uk
#
# https://github.com/battlesnake/kernel-fglrx-custom

# The kernel version number
VERSION=3.11.1
# The kernel flavour (e.g. lts, arch, lowlatency, etc)
FLAVOUR=fglrx

# For now, run as root.  I trust the kernel developers to produce safe,
# virus-free, bug-free makefiles.  They are a clever bunch of people
# after all.  Since building as root is a cardinal sin to some, someone
# else can modify this to do the appropriate chrooting and sudo stuff,
# if they so desire.
#
# Untested features:
#  + Kernel version != 3.4.59
#  + Filenames/paths containing spaces
#  + Auto-downloading kernel
#  + Auto-moving script to download folder
#
# The kernel source should be extracted to:
#   /usr/src/linux-$VERSION-$FLAVOUR
# Alternatively, be a nice guinea pig and test the automatic download by
# running this script from any folder you can write to, after setting the
# VERSION variable to the kernel that you want to auto-download.
#
# If you aren't a guinea pig, copy this script to the kernel source folder,
# make it your working directory then execute this script.  Alternatively,
# modify the SRCDIR variable.
#
# The VERSION and FLAVOUR can actually be anything you want, as long as
# the above path is valid and points to the kernel source.  Otherwise, the
# VERSION must be a valid kernel.org version number, for the untested automatic
# download to be able to find a source.
#
# The output of the build is located in:
#  $SRCDIR/$OUTDIR if SRCDIR has been modified.
# which by default would be:
#   /usr/src/linux-$VERSION-$FLAVOUR/$OUTDIR
# if you extracted a kernel source to that folder, set it as the working
# directory and ran the script from it.
#
# Note regarding the purpose of the commented "boot" lines at the end:
#   I have three operating systems (Arch / Ubuntu / Windows 2003) across two
# SSDs so I stuck a grub boot partition on each SSD to provide me with:
#  a) a backup bootloader should an Ubuntu update (predictably) screw one up
#  b) the ability to pull a disk and boot it straight away in another PC easily
# The boot partitions are mounted in /boot and /boot2, so this script will
# put a vmlinuz*, initrd*.img, and grub/grub.cfg on on BOTH boot partitions.
# Other people may want to remove the lines containing "/boot2/" near the end
# of this script for clarity.
#
# The script MAY be able to download the kernel source and prepare it, but this
# has NOT been tested at all.

# URL of kernel source - not used if a source is found in $PWD/
KERNELSOURCEURL="https://www.kernel.org/pub/linux/kernel/v3.0/linux-$VERSION.tar.xz"

# The source directory (default: current working directory)
SRCDIR="$PWD"

# The subdirectory of SRCDIR that the build should output to
OUTDIR="build"

# The maximum number of concurrent jobs MAKE can run
# Set to 16, the kernel builds in <2minutes on my 5.1GHz i7-2700k
JOBS=16

# Force (-f / --force) option skips all prompts
if [ "$1" == "-f" ] || [ "$1" == "--force" ]
then
	FORCE=1
fi

CURRENTOPERATION=

# Notifies the user that an operation is starting
function start {
	CURRENTOPERATION="$1"
	echo "Operation: $1"
}

# Pauses for user confirmation unless force option is specified
function pause {
	if [ -z "$FORCE" ]
	then
		local line
		CURRENTOPERATION="$1"
		echo -n "Press <ENTER> to $1..."
		read line
	else
		start "$1"
	fi
}

# Notifies the user that an operation failed and asks whether to continue or to abort
function failed {
	echo 'Operation "'"$CURRENTOPERATION"'" failed with code '"$?"
	if [ -z "$FORCE" ]
	then
		while true
		do
			echo -n "Continue or open subshell (y/n/s)? "
			local line
			read line
			[ "$line" == "y" ] || [ "$line" == "Y" ] && return 0
			[ "$line" == "n" ] || [ "$line" == "N" ] && exit
			[ "$line" == "s" ] || [ "$line" == "S" ] && bash
		done
	fi
}

function makelink {
	if [ -s "$2" ]
	then
		rm "$2"
	fi
	ln -s "$1" "$2" || failed
}

# Download a kernel source if we don't have one in the current directory
# Symlink it to the recommended target directory
# Copy this script to that directory
if [ ! -e "Kbuild" ]
then
	start "download kernel source"
	KERNELARCHIVE="linux-$VERSION.tar.${KERNELSOURCEURL##*.}"
	if [ ! -e "$KERNELARCHIVE" ]
	then
		curl "$KERNELSOURCEURL" > "$KERNELARCHIVE" || failed
	fi
	tar xa "$KERNELARCHIVE" || failed
	SRCDIR="/usr/src/linux-$VERSION-$FLAVOUR"
	start "link local source folder [$PWD/linux-$VERSION] to [$SRCDIR]"
	makelink "$PWD/linux-$VERSION" "$SRCDIR"
	MODDIR="/lib/modules/$VERSION-$FLAVOUR"
	mkdir "$MODDIR"
	makelink "$SRCDIR" "$MODDIR/source"
	makelink "$SRCDIR/$OUTDIR" "$MODDIR/build"
	cp "$0" "$SRCDIR/"
fi

# Move into the source directory
pushd "$SRCDIR"
trap 'popd' exit

# Create output directory if it doesn't exist
if [ ! -d "$OUTDIR" ]
then
	start "create output directory"
	mkdir "$OUTDIR" || failed
fi

# Backup config file before running clean
if [ -e "$OUTDIR/.config" ]
then
	start "make backup of last configuration"
	cp "$OUTDIR/.config" "./CONFIG" || failed
fi

# Clean the build directory
start "clean build directory"
make distclean O="$OUTDIR" || failed

# Restore config file if exists, otherwise read from kernel
if [ -e "CONFIG" ]
then
	start "restore configuration"
	cp CONFIG "$OUTDIR/.config" || failed
else
	start "get current kernel's configuration"
	zcat /proc/config.gz > "$OUTDIR/.config" || failed
fi

# Configuring kernel
start "configure kernel"
make menuconfig O="$OUTDIR" || failed

# Making kernel
start "build kernel"
KCFLAGS="-O3 -mtune=native -march=native -pipe" KPPCFLAGS="$KCFLAGS" make all O="$OUTDIR" --jobs=$JOBS || failed

# Making modules
start "build modules"
make modules O="$OUTDIR" --jobs=$JOBS || failed

# Installing modules
start "install modules"
make modules_install O="$OUTDIR" --jobs=$JOBS || failed

# AMD Radeon patch (required for catalyst build script, called by catalyst-hook, called by mkinitcpio)
start "apply radeon patch"
echo "#define COMPAT_ALLOC_USER_SPACE arch_compat_alloc_user_space" >> "$SRCDIR/$OUTDIR/arch/x86/include/generated/asm/compat.h"
if [ -e "$SRCDIR/$OUTDIR/arch/x86/include/asm" ]
then
	rm "$SRCDIR/$OUTDIR/arch/x86/include/asm" || failed
fi
ln -s "$SRCDIR/$OUTDIR/arch/x86/include/generated/asm" "$SRCDIR/$OUTDIR/arch/x86/include/asm" || failed

# Creating initramfs (don't compress, we're loading off an SSD)
start "create initramfs"
mkinitcpio -g "$OUTDIR/initramfs.img" -z cat -k $VERSION-$FLAVOUR || failed

# Installing kernel
start "install kernel"
cp "$OUTDIR/arch/x86/boot/bzImage" /boot/vmlinuz-$FLAVOUR || failed
#cp "$OUTDIR/arch/x86/boot/bzImage" /boot2/vmlinuz-$FLAVOUR

# Installing initrd
start "install initramfs"
cp "$OUTDIR/initramfs.img" /boot/initramfs-$FLAVOUR.img || failed
#cp "$OUTDIR/initramfs.img" /boot2/initramfs-$FLAVOUR.img

# Updating grub
start "generate grub.cfg"
grub-mkconfig -o /boot/grub/grub.cfg || failed
#grub-mkconfig -o /boot2/grub/grub.cfg

# Reboot and we have working AMD drivers on an old Radon with a new kernel!
echo "If all went well, then please reboot and choose the custom kernel in GRUB for"
echo "the update to take effect.  If the new kernel refuses to boot, then reboot,"
echo "choose your old kernel, then have a fun debugging session."
