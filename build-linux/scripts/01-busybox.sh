
wget -c https://git.busybox.net/busybox/snapshot/busybox-1_32_0.tar.gz

BUILD_HOME=$(pwd)
SRCDIR=$(pwd)/busybox-1_32_0
ROOTFS=$(pwd)/rootfs

rm -rf $SRCDIR
tar xf sources/busybox*.tar.* || exit;
cd $SRCDIR || exit;

echo "building busybox" || exit;
make distclean defconfig || exit;
sed -i "s|.*CONFIG_STATIC.*|CONFIG_STATIC=y|" .config || exit;
rm -rf $SRCDIR/_install
make busybox install || exit;
cd $SRCDIR/_install || exit;

#populate fs directory tree
rm -rf $ROOTFS
mkdir $ROOTFS || exit;
mkdir boot dev home lib64 lost+found mnt proc srv usr tmp var bin cdrom etc lib media opt root sbin sys
mkdir var var/run var/run/utmp var/log var/log/lastlog
mkdir lib64 lib lib/x86_64-linux-gnu

#remove old configs
rm -rf linuxrc
rm -rf init

#populate /init script for loadtime
cat > $ROOTFS/init << "EOF"
echo '#!/bin/sh' > init || exit;
echo 'dmesg -n 1'
echo 'hostname chromebook'
echo 'mount -t devtmpfs none /dev'
echo 'mount -t proc none /proc'
echo 'mount -t sysfs none /sys'
echo 'setsid cttyhack /bin/sh'
EOF
chmod +x $ROOTFS/init || exit;

##Copy busybox to the rootfs
cp -Rp * $ROOTFS/ || exit;

##Populate some configurations for busybox

cat > $ROOTFS/etc/hostname << "EOF"
chromebook
EOF

cat > $ROOTFS/etc/passwd << "EOF"
root::0:0:root:/root:/bin/ash
EOF

cat > $ROOTFS/etc/fstab << "EOF"
# file system  mount-point  type   options          dump  fsck
#                                                         order

rootfs          /               auto    defaults        1      1
proc            /proc           proc    defaults        0      0
sysfs           /sys            sysfs   defaults        0      0
devpts          /dev/pts        devpts  gid=4,mode=620  0      0
tmpfs           /dev/shm        tmpfs   defaults        0      0
EOF

cat > $ROOTFS/etc/group << "EOF"
root:x:0:
bin:x:1:
sys:x:2:
kmem:x:3:
tty:x:4:
daemon:x:6:
disk:x:8:
dialout:x:10:
video:x:12:
utmp:x:13:
usb:x:14:
EOF

cat > $ROOTFS/etc/profile << "EOF"
export PATH=/bin:/usr/bin

if [ `id -u` -eq 0 ] ; then
        PATH=/bin:/sbin:/usr/bin:/usr/sbin
        unset HISTFILE
fi


# Set up some environment variables.
export USER=`id -un`
export LOGNAME=$USER
export HOSTNAME=`/bin/hostname`
export HISTSIZE=1000
export HISTFILESIZE=1000
export PAGER='/bin/more '
export EDITOR='/bin/vi'
EOF

cat > $ROOTFS/etc/issue<< "EOF"
Linux Test 0.1a
Kernel \r on an \m
EOF

cat > $ROOTFS/etc/inittab<< "EOF"
::sysinit:/etc/rc.d/startup

tty1:12345:respawn:/bin/getty 38400 tty1
tty2:12345:respawn:/bin/getty 38400 tty2
tty3:12345:respawn:/bin/getty 38400 tty3
tty4:12345:respawn:/bin/getty 38400 tty4
tty5:12345:respawn:/bin/getty 38400 tty5
tty6:12345:respawn:/bin/getty 38400 tty6

::shutdown:/etc/rc.d/shutdown
::ctrlaltdel:/sbin/reboot
EOF

cat > $ROOTFS/etc/mdev.conf<< "EOF"
# Devices:
# Syntax: %s %d:%d %s
# devices user:group mode

# null does already exist; therefore ownership has to
# be changed with command
null    root:root 0666  @chmod 666 $MDEV
zero    root:root 0666
grsec   root:root 0660
full    root:root 0666

random  root:root 0666
urandom root:root 0444
hwrandom root:root 0660

# console does already exist; therefore ownership has to
# be changed with command
console root:tty 0600 @mkdir -pm 755 fd && cd fd && for x
 ↪in 0 1 2 3 ; do ln -sf /proc/self/fd/$x $x; done

kmem    root:root 0640
mem     root:root 0640
port    root:root 0640
ptmx    root:tty 0666

# ram.*
ram([0-9]*)     root:disk 0660 >rd/%1
loop([0-9]+)    root:disk 0660 >loop/%1
sd[a-z].*       root:disk 0660 */lib/mdev/usbdisk_link
hd[a-z][0-9]*   root:disk 0660 */lib/mdev/ide_links

tty             root:tty 0666
tty[0-9]        root:root 0600
tty[0-9][0-9]   root:tty 0660
ttyO[0-9]*      root:tty 0660
pty.*           root:tty 0660
vcs[0-9]*       root:tty 0660
vcsa[0-9]*      root:tty 0660

ttyLTM[0-9]     root:dialout 0660 @ln -sf $MDEV modem
ttySHSF[0-9]    root:dialout 0660 @ln -sf $MDEV modem
slamr           root:dialout 0660 @ln -sf $MDEV slamr0
slusb           root:dialout 0660 @ln -sf $MDEV slusb0
fuse            root:root  0666

# misc stuff
agpgart         root:root 0660  >misc/
psaux           root:root 0660  >misc/
rtc             root:root 0664  >misc/

# input stuff
event[0-9]+     root:root 0640 =input/
ts[0-9]         root:root 0600 =input/

# v4l stuff
vbi[0-9]        root:video 0660 >v4l/
video[0-9]      root:video 0660 >v4l/

# load drivers for usb devices
usbdev[0-9].[0-9]       root:root 0660 */lib/mdev/usbdev
usbdev[0-9].[0-9]_.*    root:root 0660
EOF

#best hack ever if you dont want to install bash
cat > $ROOTFS/bin/bash<< "EOF"
#!/bin/sh
/bin/busybox sh
EOF
chmod a+x $ROOTFS/bin/bash

cat > $ROOTFS/sbin/cpu-governer<< "EOF"
#!/bin/sh
echo "powersave" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo "powersave" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
EOF
chmod a+x $ROOTFS/sbin/cpu-governer

cat > $ROOTFS/sbin/brightness<< "EOF"
#!/bin/sh
if [ -z $1 ]; then
   echo "25" > /sys/class/backlight/intel_backlight/brightness;
else
   echo "$1" > /sys/class/backlight/intel_backlight/brightness;
fi;
EOF
chmod a+x $ROOTFS/sbin/brightness

cat > $ROOTFS/bin/battery-info<< "EOF"
#!/bin/sh

status=$(cat /sys/class/power_supply/BAT0/status)
charge_full_design=$(awk "BEGIN {print ($(cat /sys/class/power_supply/BAT0/charge_full_design) / 1000000)}")
charge_full=$(awk "BEGIN {print ($(cat /sys/class/power_supply/BAT0/charge_full) / 1000000)}")
charge=$(awk "BEGIN {print ($(cat /sys/class/power_supply/BAT0/charge_now) / 1000000)}")
voltage=$(awk "BEGIN {print ($(cat /sys/class/power_supply/BAT0/voltage_now) / 1000000)}")
current=$(awk "BEGIN {print ($(cat /sys/class/power_supply/BAT0/current_now) / 1000000)}")
watts=$(awk "BEGIN {print $voltage * $current}")
percent=$(awk "BEGIN {print (($charge * 100) / ($charge_full * 100)) * 100}")
hours=$(awk "BEGIN {print $charge / $current}")
degraded=$(awk "BEGIN {print 100 - ((($charge_full * 100) / ($charge_full_design * 100)) * 100)}")


battery () {

    echo "----Battery Info----"

    if [ $status = "Discharging" ]; then
        echo "Discharging";
    else
        if [ $status = "Charging" ]; then
            echo "Charge";
        fi
    fi

    echo "Voltage:              $voltage"
    echo "Current:              $current"
    echo "Watts:                $watts"
    echo "Charge:               $charge"
    echo "Charge Full:          $charge_full"
    echo "Hours Left:           $hours"
    echo "Battery Percent:      $percent"
    echo "Degradation Percent:  $degraded"
    echo ""

};

battery

EOF
chmod a+x $ROOTFS/bin/battery-info

##dont forget to set the permissions!
touch $ROOTFS/var/run/utmp $ROOTFS/var/log/{btmp,lastlog,wtmp}
chmod -v 664 $ROOTFS/var/run/utmp $ROOTFS/var/log/lastlog
chmod a+x $ROOTFS/init
