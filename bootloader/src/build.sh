#!/bin/bash
################################################################################

set -e
export LABEL="autoinit_installer"

cd /builddir/src

cp /usr/bin/vim /usr/bin/vi

# The number of kernels expected is 1
kernel_count=$(/bin/ls -1 /usr/lib/modules | wc -l)
[ $kernel_count -eq 1 ] || { echo "Expected kernel count is 1"; exit 3; }
export KVER=$(/bin/ls -1 /usr/lib/modules)

pushd boot_loader; ./build.sh; popd
rm -rf boot_installer/stuff
cp -r boot_loader/dist boot_installer/stuff
pushd boot_installer; ./build.sh; popd
echo "Build successful"

################################################################################
