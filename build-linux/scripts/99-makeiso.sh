
wget -c https://cdn.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz

ROOTFS=$(pwd)/rootfs
rm -rf syslinux-6.03
tar xvf sources/syslinux-6.03.tar.* || exit

rm -rf isoimage || exit
mkdir isoimage || exit

cd $ROOTFS
echo "compiling rootfs.gz"
find . | cpio -R root:root -H newc -o | gzip > ../isoimage/rootfs.gz
cd ..

echo "copying files to isoimage directory"

echo "copying files to isoimage directory"
if [ -e linux-4.16.18 ]; then
    echo "Custom kernel found, using it."
    cp linux-4.16.18/arch/x86/boot/bzImage isoimage/kernel.gz || exit
else
    echo "Using kernel from host system"
    cp /boot/vmlinuz-$(uname -r) isoimage/kernel.gz || exit
fi

cp syslinux-6.03/bios/core/isolinux.bin isoimage/ || exit
cp syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 isoimage/ || exit
echo 'default kernel.gz initrd=rootfs.gz' > isoimage/isolinux.cfg || exit

xorriso \
    -as mkisofs \
    -o lfs.iso \
    -b isolinux.bin \
    -c boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    isoimage/ || exit

