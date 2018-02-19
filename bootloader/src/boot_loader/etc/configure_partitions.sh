#!/bin/bash
################################################################################
# This script generates a script to partition the system
################################################################################

# TODO
# This needs to be fixed as we are not optimally laying out the disk
# There are also situations that require force that should be automatic

MIN_DISK_SIZE=16G
BOOT_PART=500M
BOOTIMAGE_PART=6G

################################################################################

set -e
cd

export PATH=$PWD:$PATH
. autoinit.settings || exit 2
. libbashbyte || exit 2

################################################################################

# Remove /dev if present in disk
disk=$(echo $1 | sed 's/\///g' | sed 's/dev//g')
[[ $disk ]] || { echo "Usage: disk" 1>&2; exit 2; }

devdisk="/dev/${disk}"
[ -b $devdisk ] || { echo "Device $devdisk is not a block device" 1>&2; exit 3; }

sectors=$(cat /sys/block/${disk}/size)
physical_block_size=$(cat /sys/block/${disk}/queue/physical_block_size)
size=$(expr $sectors \* $physical_block_size)

### Validate disk size ###
disk_size="$(expr $sectors \* $physical_block_size)B"
min_size=$(to_bytes_nosign $MIN_DISK_SIZE)

echo "Disk size is $(to_logical_size_unit $disk_size)" 1>&2

[ $size -lt $min_size ] && {
   echo "Less then minimal required size of $(to_logical_size_unit $MIN_DISK_SIZE)" 1>&2
   exit 1
}

echo "Meets minimal required size of $(to_logical_size_unit $MIN_DISK_SIZE)" 1>&2

boot_size=$(to_megabytes_nosign $BOOT_PART)
bootimage_size=$(to_megabytes_nosign $BOOTIMAGE_PART)
bootimage_start=$(expr $boot_size + 1)
persist_start=$(expr $bootimage_start + $bootimage_size + 1)

cat > install_partitions.sh <<EOF
#!/bin/bash
set -e

wipefs -f -a $devdisk
parted -s $devdisk mklabel msdos
  
parted -a optimal $devdisk mkpart primary 0% ${boot_size}M
parted -a optimal $devdisk mkpart primary ${bootimage_start}M ${bootimage_size}M
parted -a optimal $devdisk mkpart primary ${persist_start}M 100%
parted -s $devdisk toggle 1 boot

mkfs.ext4 -F ${devdisk}1
mkfs.ext4 -L $BOOTIMAGE_LABEL -F ${devdisk}2
mkfs.ext4 -L $PERSIST_LABEL ${devdisk}3

echo "Installing boot loader"
bash install_bootloader.sh $devdisk

sync
sync
EOF

echo "The file install_partitions.sh has been generated. Review it and then execute it"

chmod +x install_partitions.sh

################################################################################
