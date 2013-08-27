#!/bin/bash

# The kernel version number
VERSION=3.4.59
# The kernel flavour (e.g. lts, arch, lowlatency, etc)
FLAVOUR=mark

# The kernel source should be extracted to:
#   /usr/src/linux-$VERSION-$FLAVOUR
#
# Copy this script to that folder, make it your working directory then execute
# this script.  Alternatively, modify the SRCDIR variable.
#
# Hence the VERSION and FLAVOUR can actually be anything you want, as long as
# the above path is valid and points to the kernel source.
#
# The output of the build is located in:
#   /usr/src/linux-$VERSION-$FLAVOUR/$OUTDIR
#
# I have three operating systems (Arch / Ubuntu / Windows 2003) across two SSDs
# so I stuck a grub boot partition on each SSD to provide me with:
#  a) a backup bootloader should an Ubuntu update (predictably) screw one up
#  b) the ability to pull a disk and boot it straight away in another PC easily
#
# The boot partitions are mounted in /boot and /boot2, so this script will
# put a vmlinuz*, initrd*.img, and grub/grub.cfg on on BOTH boot partitions.
# Other people may want to remove the lines containing "/boot2/" near the end
# of this script.
#
# The script MAY be able to download the kernel source and prepare it, but this
# has NOT been tested at all and in all probability probably won't work.

KERNELSOURCEURL="https://www.kernel.org/pub/linux/kernel/v3.0/linux-$VERSION.tar.xz"

# The source directory (default: current working directory)
SRCDIR="$PWD"

# The subdirectory that the build should output to
OUTDIR="_build"

# The maximum number of concurrent jobs MAKE can run
JOBS=16

# Force (-f / --force) option skips all prompts
if [ "$1" == "-f" ] || [ "$1" == "--force" ]
then	FORCE=1
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
	then	local line
		CURRENTOPERATION="$1"
		echo -n "Press <ENTER> to $1..."
		read line
	else	start "$1"
	fi
}

# Notifies the user that an operation failed and asks whether to continue or to abort
function failed {
	echo 'Operation "'"$CURRENTOPERATION"'" failed with code '"$?"
	if [ -z "$FORCE" ]
	then	while true
		do	echo -n "Continue or open subshell (y/n/s)? "
			local line
			read line
			[ "$line" == "y" ] || [ "$line" == "Y" ] && return 0
			[ "$line" == "n" ] || [ "$line" == "N" ] && exit
			[ "$line" == "s" ] || [ "$line" == "S" ] && bash
		done
	fi
}

# Download a kernel source if we don't have one in the current directory
if [ ! -e "Kbuild" ]
then	start "download kernel source"
	curl "$KERNELSOURCEURL" | tar xJ || failed
	ln -s "$PWD/linux-$VERSION" "/usr/src/linux-$VERSION-$FLAVOUR" || failed
	SRCDIR="/usr/src/linux-$VERSION-$FLAVOUR"
	cp "$0" "$SRCDIR/"
fi

# Move into the source directory
pushd "$SRCDIR"
trap 'popd' exit

# Create output directory if it doesn't exist
if [ ! -d "$OUTDIR" ]
then	start "create output directory"
	mkdir "$OUTDIR" || failed
fi

# Backup config file before running clean
if [ -e "$OUTDIR/.config" ]
then	start "make backup of last configuration"
	cp "$OUTDIR/.config" "./CONFIG" || failed
fi

# Clean the build directory
start "clean build directory"
make distclean O="$OUTDIR" || failed

# Restore config file if exists, otherwise read from kernel
if [ -e "CONFIG" ]
then	start "restore configuration"
	cp CONFIG "$OUTDIR/.config" || failed
else	start "get current kernel's configuration"
	zcat /proc/config.gz > "$OUTDIR/.config" || failed
fi

# Configuring kernel
start "configure kernel"
make menuconfig O="$OUTDIR" || failed

# Making kernel
start "build kernel"
make all O="$OUTDIR" --jobs=$JOBS || failed

# Making modules
start "build modules"
make modules O="$OUTDIR" --jobs=$JOBS || failed

# Installing modules
start "install modules"
make modules_install O="$OUTDIR" --jobs=$JOBS || failed

# AMD Radeon patch (required for catalyst build script, called by catalyst-hook, called by mkinitcpio)
start "apply radeon patch"
echo "#define COMPAT_ALLOC_USER_SPACE arch_compat_alloc_user_space" >> "$SRCDIR/_build/arch/x86/include/generated/asm/compat.h"
if [ -e "$SRCDIR/_build/arch/x86/include/asm" ]
then	rm "$SRCDIR/_build/arch/x86/include/asm" || failed
fi
ln -s "$SRCDIR/_build/arch/x86/include/generated/asm" "$SRCDIR/_build/arch/x86/include/asm" || failed

# Creating initramfs
start "create initramfs"
mkinitcpio -g "$OUTDIR/initramfs.img" -z cat -k $VERSION-$FLAVOUR || failed

# Installing kernel
start "install kernel"
cp "$OUTDIR/arch/x86/boot/bzImage" /boot/vmlinuz-$FLAVOUR || failed
cp "$OUTDIR/arch/x86/boot/bzImage" /boot2/vmlinuz-$FLAVOUR

# Installing initrd
start "install initramfs"
cp "$OUTDIR/initramfs.img" /boot/initramfs-$FLAVOUR.img || failed
cp "$OUTDIR/initramfs.img" /boot2/initramfs-$FLAVOUR.img

# Updating grub
start "generate grub.cfg"
grub-mkconfig -o /boot/grub/grub.cfg || failed
grub-mkconfig -o /boot2/grub/grub.cfg
