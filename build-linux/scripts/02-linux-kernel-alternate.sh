wget -c https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.9.tar.xz
BUILD_HOME=$(pwd)
SRCDIR=$(pwd)/linux-5.9
ROOTFS=$(pwd)/rootfs

rm -rf $SRCDIR
tar xvf src/linux-5.9.* || exit;
cd $SRCDIR

echo "building kernel"
#make headers_install_all
sed 's/=m/=y/g' /boot/config-$(uname -r) >> .config
make menuconfig || exit;
make || exit;

if [ ! -e $ROOTFS ]; then
    mkdir $ROOTFS
fi;

echo "copying files kernel to boot directory"
cp $SRCDIR/arch/x86/boot/bzImage $ROOTFS/boot/vmlinuz || exit;

