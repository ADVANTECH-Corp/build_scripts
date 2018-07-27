#!/bin/bash

echo "[ADV] FTP_SITE = ${FTP_SITE}"
echo "[ADV] FTP_DIR = ${FTP_DIR}"
echo "[ADV] DATE = ${DATE}"
echo "[ADV] VERSION = ${VERSION}"
echo "[ADV] UBUNTU_VERSION= ${UBUNTU_VERSION}"
echo "[ADV] UBUNTU_ROOTFS = ${UBUNTU_ROOTFS}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] STORED = ${STORED}"
CURR_PATH="$PWD"
STORAGE_PATH="$CURR_PATH/$STORED"

# === 1. Put the ubuntu image into out/ folder. =================================================
function get_rootfs_image()
{
    # Get Ubuntu rootfs image
    pftp -v -n ${FTP_SITE} <<-EOF
user "ftpuser" "P@ssw0rd"
cd "Image/amxxxx/Ubuntu/${UBUNTU_VERSION}"
prompt
binary
ls
mget ${UBUNTU_ROOTFS}.tar.xz
close
quit
EOF
    mkdir ./out
    tar Jxf ${UBUNTU_ROOTFS}.tar.xz -C ./out/
    rm ${UBUNTU_ROOTFS}.tar.xz
}

function get_misc_image()
{
    # Get kernel images & modules from FTP
    KERNEL_FILE_NAME="${MISC_FILE_NAME}_zimage"
    MODULES_FILE_NAME="${MISC_FILE_NAME}_modules"
    SDKIMG_FILE_NAME="${MISC_FILE_NAME}_sdkimg"

    pftp -v -n ${FTP_SITE} <<-EOF
user "ftpuser" "P@ssw0rd"
cd "officialbuild/${FTP_DIR}/${DATE}"
prompt
binary
ls
mget ${KERNEL_FILE_NAME}.tgz
mget ${MODULES_FILE_NAME}.tgz
mget ${SDKIMG_FILE_NAME}.tgz
close
quit
EOF
    # Kernel & DTB
    tar zxf ${KERNEL_FILE_NAME}.tgz
    rm ${KERNEL_FILE_NAME}.tgz

    mkdir ./boot
    mv ${MISC_FILE_NAME}/zImage--*.* ./boot/
    mv ${MISC_FILE_NAME}/zImage ./boot/
    mv ${MISC_FILE_NAME}/zImage-${CPU_TYPE}-${MACHINE}.dtb ./boot/${CPU_TYPE}-${MACHINE}.dtb

    # Modules
    tar zxf ${MODULES_FILE_NAME}.tgz
    rm ${MODULES_FILE_NAME}.tgz

    for MODULE_TARBALL in ${MISC_FILE_NAME}/modules--*.tgz
    do
        tar zxf ${MODULE_TARBALL}
    done

    # SDK
    tar zxf ${SDKIMG_FILE_NAME}.tgz
    rm ${SDKIMG_FILE_NAME}.tgz

    mkdir ./ti-sdk-004
    tar Jxf processor-sdk-linux-image-*.tar.xz -C ti-sdk-004
    rm processor-sdk-linux-image-*.tar.xz
}

function generate_md5()
{
    FILENAME=$1

    if [ -e $FILENAME ]; then
        MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
        echo $MD5_SUM > $FILENAME.md5
    fi
}

function package_ubuntu_rootfs()
{
	MODULE_VERSION=`echo $(ls lib/modules/)`

	# Mbed
	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/factory-configurator-client/files/dragonboard-410c/factory-configurator-client-example.elf

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/dragonboard-410c/edge-core

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-WISE-PaaS/recipes-ota/ota-script/files/do_update_mbed.sh

	# Copy files
	sudo rm -rf out/boot/*
	sudo cp -a boot/* out/boot/
	sudo rm -rf out/lib/modules/*
	sudo cp -ar lib/modules/ out/lib/

	#sudo mkdir /out/tools
	sudo chmod 755 *
	sudo cp -a  factory-configurator-client-example.elf out/usr/bin/
	sudo cp -a  edge-core out/usr/bin/
	sudo cp -a  do_update_mbed.sh out/tools/

	# Set up chroot
	sudo cp /usr/bin/qemu-arm-static out/usr/bin/

	# Depmod in chroot mode
	sudo chroot ./out << EOF
depmod -a ${MODULE_VERSION}
chown -R root:root /lib/modules/${MODULE_VERSION}/
exit
EOF

	sudo rm out/usr/bin/qemu-arm-static

	# Package 
	cd out/
	sudo tar Jcf ../tisdk-rootfs-image-ubuntu_${DATE}.tar.xz *

	rm -rf ${MISC_FILE_NAME}
}

function generate_sdkimg()
{
	cd $CURR_PATH
	mkdir ${MISC_FILE_NAME}

	rm ti-sdk-004/filesystem/tisdk-rootfs-image-*
	cp -a tisdk-rootfs-image-ubuntu_${DATE}.tar.xz ti-sdk-004/filesystem/
	cd ti-sdk-004/
	sudo tar Jcf ../${MISC_FILE_NAME}/${OUTPUT_SDKIMG_TAR_XZ}.tar.xz *
	cd ..
	sudo tar zcf ${OUTPUT_SDKIMG_TGZ}.tgz ${MISC_FILE_NAME}

	generate_md5 ${OUTPUT_SDKIMG_TGZ}.tgz
	mv ${OUTPUT_SDKIMG_TGZ}.tgz $STORAGE_PATH
	mv *.md5 $STORAGE_PATH
}


# === [Main] List Official Build Version ============================================================
if [ "$AM57XX_EVM" == "true" ]; then
        MACHINE_LIST="$MACHINE_LIST am57xx-evm"
fi
if [ "$ROM7510A1" == "true" ]; then
        MACHINE_LIST="$MACHINE_LIST am57xxrom7510a1"
fi
if [ "$ROM7510A2" == "true" ]; then
        MACHINE_LIST="$MACHINE_LIST am57xxrom7510a2"
fi
if [ "$RSB4220A1" == "true" ]; then
        MACHINE_LIST="$MACHINE_LIST am335xrsb4220a1"
fi
if [ "$RSB4221A1" == "true" ]; then
        MACHINE_LIST="$MACHINE_LIST am335xrsb4221a1"
fi
if [ "$ROM3310A1" == "true" ]; then
        MACHINE_LIST="$MACHINE_LIST am335xrom3310a1"
fi

NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
VERSION_NUM=$NUM1$NUM2

# Ubuntu
OS_PREFIX="U"

get_rootfs_image

for NEW_MACHINE in $MACHINE_LIST
do
	CPU_TYPE=${NEW_MACHINE:0:6}
	MACHINE=${NEW_MACHINE:6}
	typeset -u PRODUCT
	PRODUCT=${NEW_MACHINE:9}

	MISC_VERSION="${PRODUCT}LIV${VERSION_NUM}"
	MISC_FILE_NAME="${MISC_VERSION}_${CPU_TYPE}_${DATE}"

	RELEASE_VERSION="${PRODUCT}${OS_PREFIX}IV${VERSION_NUM}"
	OUTPUT_SDKIMG_TGZ="${RELEASE_VERSION}_${CPU_TYPE}_${DATE}_sdkimg"
	OUTPUT_SDKIMG_TAR_XZ="processor-sdk-linux-image-${NEW_MACHINE}-${DATE}"

	get_misc_image
	package_ubuntu_rootfs
	generate_sdkimg
done
