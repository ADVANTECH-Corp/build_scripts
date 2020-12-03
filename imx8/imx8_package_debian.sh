#!/bin/bash

echo "[ADV] FTP_SITE = ${FTP_SITE}"
echo "[ADV] FTP_DIR = ${FTP_DIR}"
echo "[ADV] DATE = ${DATE}"
echo "[ADV] VERSION = ${VERSION}"
echo "[ADV] AIM_VERSION = ${AIM_VERSION}"
echo "[ADV] STORED = ${STORED}"

echo "[ADV] DEBIAN_VERSION = ${DEBIAN_VERSION}"
echo "[ADV] DEBIAN_ROOTFS = ${DEBIAN_ROOTFS}"

VERSION_TAG=$(echo $VERSION | sed 's/[.]//')

CURR_PATH="$PWD"
STORAGE_PATH="$CURR_PATH/$STORED"

MOUNT_POINT="$CURR_PATH/mnt"
if [ -e $MOUNT_POINT ]; then
	echo "[ADV] $MOUNT_POINT had already been created"
else
	echo "[ADV] mkdir $MOUNT_POINT"
	mkdir -p $MOUNT_POINT
fi

# Loop device
LOOP_DEV=`sudo losetup -f`
if [ -z $LOOP_DEV ]; then
	echo "loop device busy!"
	exit 1
fi

function get_debian_rootfs()
{
    echo "[ADV] get_debian_rootfs"
    mkdir out
    pftp -v -n ${FTP_SITE} << EOF
user "ftpuser" "P@ssw0rd"
cd "Image/imx8/debian/${DEBIAN_VERSION}"
prompt
binary
ls
mget ${DEBIAN_ROOTFS}
close
quit
EOF
}

function generate_md5()
{
    FILENAME=$1

    if [ -e $FILENAME ]; then
        MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
        echo $MD5_SUM > $FILENAME.md5
    fi
}

function generate_csv()
{
    FILENAME=$1
    MD5_SUM=
    FILE_SIZE_BYTE=
    FILE_SIZE=

    if [ -e $FILENAME ]; then
        MD5_SUM=`cat ${FILENAME}.md5`
        set - `ls -l ${FILENAME}`; FILE_SIZE_BYTE=$5
        set - `ls -lh ${FILENAME}`; FILE_SIZE=$5
    fi

    cd $CURR_PATH

    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Debian ${DEBIAN_VERSION}
Part Number,N/A
Author,
Date,${DATE}
Version,${DEBIAN_PRODUCT}${VERSION_TAG}
Build Number,${BUILD_NUMBER}
TAG,
Tested Platform,${CPU_TYPE_Module}${NEW_MACHINE}
MD5 Checksum,GZ: ${MD5_SUM}
Image Size,${FILE_SIZE}B (${FILE_SIZE_BYTE} bytes)
Issue description, N/A
Function Addition,
Yocto Kernel,imx8LB${VERSION_TAG}_${DATE}
Debian Rootfs,${DEBIAN_ROOTFS}
END_OF_CSV
}

function generate_mksd_linux()
{
    OUTPUT_DIR=$1
    sudo mkdir $OUTPUT_DIR/mk_inand
    chmod 755 $CURR_PATH/mksd-linux.sh
    sudo cp $CURR_PATH/mksd-linux.sh $OUTPUT_DIR/mk_inand/
    sudo chown 0.0 $OUTPUT_DIR/mk_inand/mksd-linux.sh
}

function copy_folder()
{
    SRC_DIR=$1
    DEST_DIR=$2
    sudo mkdir -p $MOUNT_POINT/${DEST_DIR}
    sudo cp -a $MOUNT_POINT/${SRC_DIR}/* $MOUNT_POINT/${DEST_DIR}/
    sudo rm -rf $MOUNT_POINT/${SRC_DIR}
}

function create_debian_image()
{
    case ${AIM_VERSION} in
    AIM20) SDCARD_SIZE=3700;;
    AIM30) SDCARD_SIZE=6500;;
    *) echo "cannot read AIM version from \"$AIM_VERSION\""; exit 1 ;;
    esac

    YOCTO_IMAGE_SDCARD="*-image-*${CPU_TYPE_Module}${NEW_MACHINE}*.sdcard"
    YOCTO_IMAGE_TGZ="${PRODUCT}${VERSION_TAG}_${CPU_TYPE}_flash_tool.tgz"
    DEBIAN_IMAGE="${DEBIAN_PRODUCT}${VERSION_TAG}_${CPU_TYPE}_${DATE}.img"

    pftp -v -n ${FTP_SITE} << EOF
user "ftpuser" "P@ssw0rd"
cd "officialbuild/${FTP_DIR}/${DATE}/"
prompt
binary
ls
mget ${YOCTO_IMAGE_TGZ}
close
quit
EOF
    #  Yocto image
    tar zxf ${YOCTO_IMAGE_TGZ}
    mv ${YOCTO_IMAGE_TGZ/.tgz}/image/*.sdcard .

    # Maybe the loop device is occuppied, unmount it first
    sudo umount $MOUNT_POINT
    sudo losetup -d $LOOP_DEV

    echo "[ADV] rename yocto image file to debian image file"
    sudo mv ${YOCTO_IMAGE_SDCARD} ${DEBIAN_IMAGE}

    # resize
    sudo mv ${DEBIAN_IMAGE} ${DEBIAN_IMAGE/.img}.sdcard
    sudo dd if=/dev/zero of=${DEBIAN_IMAGE} bs=1M count=$SDCARD_SIZE
    sudo losetup ${LOOP_DEV} ${DEBIAN_IMAGE}
    echo "[ADV] resize ${DEBIAN_IMAGE} to ${SDCARD_SIZE}MB"
    sudo dd if=${DEBIAN_IMAGE/.img}.sdcard of=$LOOP_DEV
    sudo sync

    rootfs_start=`sudo fdisk -u -l ${LOOP_DEV} | grep ${LOOP_DEV}p2 | awk '{print $2}'`
    sudo fdisk -u $LOOP_DEV << EOF
d
2
n
p
2
$rootfs_start

Y
w
EOF
    sudo sync
    sudo partprobe ${LOOP_DEV}
    sudo e2fsck -f -y ${LOOP_DEV}p2
    sudo resize2fs ${LOOP_DEV}p2

    # Update Debian rootfs
    echo "[ADV] update rootfs"
    sudo mount ${LOOP_DEV}p2 $MOUNT_POINT/
    sudo mv $MOUNT_POINT/etc/modprobe.d $MOUNT_POINT/.modprobe.d
    sudo mv $MOUNT_POINT/etc/modules-load.d $MOUNT_POINT/.modules-load.d
    sudo mv $MOUNT_POINT/etc/udev $MOUNT_POINT/.udev
    sudo mv $MOUNT_POINT/lib/modules $MOUNT_POINT/.modules
    sudo mv $MOUNT_POINT/lib/firmware $MOUNT_POINT/.firmware
    sudo rm -rf $MOUNT_POINT/*
    sudo tar zxf ${DEBIAN_ROOTFS} -C $MOUNT_POINT/
    copy_folder .modprobe.d etc/modprobe.d
    copy_folder .modules-load.d etc/modules-load.d
    copy_folder .udev etc/udev
    copy_folder .modules lib/modules
    copy_folder .firmware lib/firmware

    sudo sh -c "echo ${CPU_TYPE_Module}${NEW_MACHINE} > $MOUNT_POINT/etc/hostname"
    sudo sed -i "s/\(127\.0\.1\.1 *\).*/\1${CPU_TYPE_Module}${NEW_MACHINE}/" $MOUNT_POINT/etc/hosts

    # additional operations
    sudo chmod o+x $MOUNT_POINT/usr/lib/dbus-1.0/dbus-daemon-launch-helper

    sudo umount $MOUNT_POINT
    sudo losetup -d ${LOOP_DEV}
    sudo rm ${DEBIAN_IMAGE/.img}.sdcard

    # generate flash_tool
    echo "[ADV] generate flash tool"
    FLASH_DIR=${DEBIAN_PRODUCT}${VERSION_TAG}_${CPU_TYPE}_flash_tool
    sudo mkdir -p $FLASH_DIR/image
    sudo cp ${DEBIAN_IMAGE} $FLASH_DIR/image/${DEBIAN_IMAGE/.img}.sdcard
    sudo chown -R 0.0 $FLASH_DIR/image
    generate_mksd_linux $FLASH_DIR

    tar czf ${FLASH_DIR}.tgz $FLASH_DIR
    generate_md5 ${FLASH_DIR}.tgz
    sudo mv ${FLASH_DIR}.tgz* $STORAGE_PATH

    # output file
    echo "[ADV] output files"
    gzip -c9 ${DEBIAN_IMAGE} > ${DEBIAN_IMAGE}.gz
    generate_md5 ${DEBIAN_IMAGE}.gz
    generate_csv ${DEBIAN_IMAGE}.gz
    sudo mv ${DEBIAN_IMAGE}.csv $STORAGE_PATH
    sudo mv ${DEBIAN_IMAGE}.gz $STORAGE_PATH
    sudo mv ${DEBIAN_IMAGE}.gz.md5 $STORAGE_PATH
}

# === [Main] List Official Build Version ============================================================
TOTAL_LIST=" \
    ROM7720A1_8QM \
    ROM5720A1_8M \
    ROM5620A1_8X \
    ROM3620A1_8X \
    ROM5721A1_8MM \
    RSB3720A1_8MP
"
MACHINE_LIST=""

for M in $TOTAL_LIST; do
  VAR_NAME=${M/_*}
  M=${M,,}
  eval [[ \$${VAR_NAME} == true ]] && MACHINE_LIST="$MACHINE_LIST${M//_/-} "
done

# echo MACHINE_LIST=\"$MACHINE_LIST\"

# DEBIAN
OS_PREFIX="D"

get_debian_rootfs

for NEW_MACHINE in $MACHINE_LIST
do
    #MISC_VERSION="${NEW_MACHINE}LIV${VERSION_NUM}"
    #RELEASE_VERSION="${NEW_MACHINE}${OS_PREFIX}IV${VERSION_NUM}"

    case ${NEW_MACHINE/*-} in
    8x)  CPU_TYPE="iMX8X";  CPU_TYPE_Module="imx8qxp" ;;
    8m)  CPU_TYPE="iMX8M";  CPU_TYPE_Module="imx8mq"  ;;
    8mm) CPU_TYPE="iMX8MM"; CPU_TYPE_Module="imx8mm"  ;;
    8qm) CPU_TYPE="iMX8QM"; CPU_TYPE_Module="imx8qm"  ;;
    8mp) CPU_TYPE="iMX8MP"; CPU_TYPE_Module="imx8mp"  ;;
    *) echo "cannot read CPU type from \"$NEW_MACHINE\""; exit 1 ;;
    esac

    NEW_MACHINE=${NEW_MACHINE/-*}
    case $NEW_MACHINE in
    rom7720a1) PROD="7720A1" ;;
    rom5720a1) PROD="5720A1" ;;
    rom5620a1) PROD="5620A1" ;;
    rom3620a1) PROD="3620A1" ;;
    rom5721a1) PROD="5721A1" ;;
    rsb3720a1) PROD="3720A1" ;;
    *) echo "cannot handle \"$NEW_MACHINE\""; exit 1 ;;
    esac

    PRODUCT="${PROD}${AIM_VERSION}LI"
    DEBIAN_PRODUCT="${PROD}${AIM_VERSION}${OS_PREFIX}I"

    create_debian_image
done
