#!/bin/bash
set -e

cd $(dirname "$0")

recipe=$1

recipes=""
for dir in `/bin/ls -1`; do
   [ -d $dir ] || continue
   [ -f $dir/mock.cfg ] || continue
   [ "$recipes" == "" ] && recipes="$dir" || recipes+=" | $dir"
done

[ "$recipes" == "" ] || recipes="( recipe = $recipes )"

[ -z $recipe ] && { echo "usage:$0 recipe $recipes"; exit 2; }

[ -d $recipe ] || { echo "Recipe directory $recipe does not exist"; exit 1; }

which mock > /dev/null 2>&1 || {
   echo "Installing mock"
   dnf -y install mock || { echo "Mock install failed!"; exit 1; }
}

cd $recipe

[ -f mock.cfg ] || { echo "File mock.cfg not found"; exit 1; }
[ -f packages ] || { echo "File packages not found"; exit 1; }

mock -r mock.cfg --init

packages=$(cat packages | xargs echo)
mock -r mock.cfg --install $packages

mock -r mock.cfg --shell "rm -rf /builddir"
mock -r mock.cfg --shell "mkdir /builddir"
mock -r mock.cfg --copyin src /builddir
mock -r mock.cfg --shell "bash /builddir/src/build.sh"

rm -rf dist

mock -r mock.cfg --copyout /builddir/src/dist dist

mock -r mock.cfg --clean
