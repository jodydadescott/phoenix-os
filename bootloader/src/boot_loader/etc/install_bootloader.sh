#!/bin/bash
################################################################################
# This installer does the following
# 1) Creates 3 partitions (boot, bootimage, persist)
# 2) Installs grub2 to part 1 (boot)
# 3) Formats part 2 (bootimage, /bootimage) with EXT4
# 4) Formats part 3 (persist, /mnt/flash]) with EXT4
################################################################################

set -e

export PATH=$PWD:$PATH
. autoinit.settings || exit 2

################################################################################

# Remove /dev if present in disk
disk=$(echo $1 | sed 's/\///g' | sed 's/dev//g')
[[ $disk ]] || { echo "Usage: disk" 1>&2; exit 2; }

devdisk="/dev/${disk}"
[ -b $devdisk ] || { echo "Device $devdisk is not a block device" 1>&2; exit 3; }

mkdir -p /boot

umount /boot 2>&1 >> /dev/null ||:
mount ${devdisk}1 /boot

grub2-install $devdisk

cp -r isolinux /boot

### Generate kernel boot arg
# Get any args from the kernel boot command that match console* and
# append them to the new kernel boot string

for arg in $(cat /proc/cmdline | tr ";" "\n"); do
   [[ "$arg" =~ console.* ]] && boot_opts+=" $arg "
done

echo "set default='boot'" > /boot/grub2/grub.cfg
echo "set timeout=3" >> /boot/grub2/grub.cfg
echo "menuentry 'boot' {" >> /boot/grub2/grub.cfg
echo "   set root=(hd0,msdos1)" >> /boot/grub2/grub.cfg
echo "   linux /isolinux/vmlinuz $boot_opts" >> /boot/grub2/grub.cfg
echo "   initrd /isolinux/initrd" >> /boot/grub2/grub.cfg
echo "}" >> /boot/grub2/grub.cfg

sync
sync
umount /boot

echo "You will now need to reboot"

################################################################################
