#!/bin/bash

################################################################################

set -e

function _main() {
   cd /builddir/src
   _prep
   _kernel
   _initrd
   _docker
   _user
   _dist
}

################################################################################

function _kernel() {
   # We expect one kernel in /usr/lib/modules. If there is more then one
   # then we do not know which one to use.
   kernel_count=$(/bin/ls -1 /usr/lib/modules | wc -l)
   [ $kernel_count -eq 1 ] || { echo "More than one kernel"; return 3; }
   KVER=$(/bin/ls -1 /usr/lib/modules)
}

function _prep() {

   rm -rf /etc/ssh/*key*
   cat hosts > /etc/hosts
   cat /dev/null > /etc/resolv.conf
   cat /dev/null > /etc/fstab
   rm -rf /var/lib/gssproxy
   mkdir -p /var/lib/gssproxy

   rm -rf /usr/share/aconfig
   cp -r share /usr/share/aconfig

   cat sudoers > /etc/sudoers

   cp /usr/bin/vim /usr/bin/vi

   rm -rf /var/mail; mkdir -p /var/mail/root
   rm -rf /var/spool/mail; mkdir -p /var/spool/mail/root
   install -m 0755 aconfig /usr/bin
}

function _build_initrd() {
   # Dont call this from main. Its called by _initrd if necessary
   [[ $KVER ]] || return 2
   modules+=" base "
   # modules+=" network "
   # modules+=" dmsquash-live pollcdrom "

   drivers+=" sr_mod sd_mod cdrom =ata sym53c8xx aic7xxx ehci_hcd uhci_hcd "
   drivers+=" ohci_hcd usb_storage usbhid uas firewire-sbp2 firewire-ohci "
   drivers+=" sbp2 ohci1394 mmc_block sdhci sdhci-pci pata_pcmcia mptsas "
   drivers+=" udf virtio_blk virtio_pci virtio_scsi virtio_net virtio_mmio "
   drivers+=" virtio_balloon virtio-rng "

   filesystems+=" vfat msdos isofs "
   filesystems+=" ext4 xfs "

   dracut --kver $KVER \
       --force \
       --no-hostonly \
       --add "$modules" \
       --add-drivers "$drivers" \
       --filesystems "$filesystems" /boot/initrd
}

function _initrd() {
   [[ $KVER ]] || return 2
   install -m 0755 boot0 /
   [ -f /boot/initrd ] && { echo "using prebuilt initrd"; } ||
      { echo "initrd build required"; _build_initrd; }
   mv /boot /boot.tmp
   mkdir /boot
   mv /boot.tmp/initrd /boot
   rm -rf /boot.tmp
   kernel_file=/usr/lib/modules/${KVER}/vmlinuz
   cp $kernel_file /boot
}

function _docker() {
   dnf -y install https://download.docker.com/linux/fedora/27/x86_64/stable/Packages/docker-ce-17.12.0.ce-1.fc27.x86_64.rpm
   cat docker-storage-setup  > /etc/sysconfig/docker-storage-setup
}

function _user() {
   passwd -d root
   userdel admin > /dev/null 2>&1 || :
   rm -rf /home/admin
   useradd admin
   echo "admin:admin" | chpasswd
   usermod -aG wheel,libvirt admin
}

function _dist() {
   rm -rf dist
   mkdir -p dist; pushd dist
   mkdir root

   rsync -a  / root \
       --exclude builddir \
       --exclude proc \
       --exclude sys \
       --exclude dev \
       --exclude persist \
       --exclude var/cache \
       --progress

   pushd root; mkdir -p dev sys proc var/cache; popd
   mksquashfs root rootfs.img -no-xattrs
   rm -rf root
   popd
   echo "build complete"
}

################################################################################
_main $@
################################################################################
