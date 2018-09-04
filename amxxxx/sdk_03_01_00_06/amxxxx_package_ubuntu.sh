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

# === [Functions] ===
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
    sudo tar Jxf ${UBUNTU_ROOTFS}.tar.xz -C ./out/
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
    tar Jxf ${MISC_FILE_NAME}/processor-sdk-linux-image-*.tar.xz -C ti-sdk-004
    rm ${MISC_FILE_NAME}/processor-sdk-linux-image-*.tar.xz
}

function generate_md5()
{
    FILENAME=$1

    if [ -e $FILENAME ]; then
        MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
        echo $MD5_SUM > $FILENAME.md5
    fi
}

function get_install_files()
{
	# Mbed
	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/factory-configurator-client/files/arago/factory-configurator-client-example.elf

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/arago/edge-core

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/arago/edge-core-dev

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/arago/pt-example_modbus

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/mec.service

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/pt-modbus.service

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-ti-adv/recipes-core/service/files/g_multi.service

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/arm_update_activate.sh

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/arm_update_active_details.sh

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/arm_update_prepare.sh

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/arago/arm_write_header.sh

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-WISE-PaaS/recipes-ota/ota-script/files/do_update_mbed.sh
}

function package_ubuntu_rootfs()
{
	MODULE_VERSION=`echo $(ls lib/modules/)`

	# Copy files
	sudo rm -rf out/boot/*
	sudo cp -a boot/* out/boot/
	sudo rm -rf out/lib/modules/*
	sudo cp -ar lib/modules/ out/lib/

	#sudo mkdir /out/tools
	sudo chown root:root edge* *.sh *.service *.elf

	sudo chmod 755 *

	sudo cp -a edge-core out/usr/bin/
	sudo cp -a edge-core-dev out/usr/bin/
	sudo cp -a pt-example_modbus out/usr/bin/
	sudo cp -a factory-configurator-client-example.elf out/usr/bin/

	sudo cp -a arm_update_activate.sh out/usr/sbin/
	sudo cp -a arm_update_active_details.sh out/usr/sbin/
	sudo cp -a arm_update_prepare.sh out/usr/sbin/
	sudo cp -a arm_write_header.sh out/usr/sbin/

	sudo cp -a do_update_mbed.sh out/tools/

	sudo chmod 644 mec.service
	sudo cp -a mec.service out/lib/systemd/system/
	sudo chmod 644 pt-modbus.service
	sudo cp -a pt-modbus.service out/lib/systemd/system/
	sudo chmod 644 g_multi.service
	sudo cp -a g_multi.service out/lib/systemd/system/

	# Set up chroot
	sudo cp /usr/bin/qemu-arm-static out/usr/bin/

	# Depmod in chroot mode
	sudo chroot ./out << EOF
depmod -a ${MODULE_VERSION}
chown -R root:root /lib/modules/${MODULE_VERSION}/
systemctl enable mec.service
systemctl enable g_multi.service
exit
EOF
	sudo rm out/usr/bin/qemu-arm-static

	# Package 
	cd out/
	sudo tar Jcf ../tisdk-rootfs-image-ubuntu_${DATE}.tar.xz *

	# Remove files
	cd $CURR_PATH
	sudo rm -rf ${MISC_FILE_NAME} boot lib out
}

function generate_sdkimg()
{
	cd $CURR_PATH
	mkdir ${OUTPUT_SDKIMG_TGZ}

	rm ti-sdk-004/filesystem/tisdk-rootfs-image-*
	cp -a tisdk-rootfs-image-ubuntu_${DATE}.tar.xz ti-sdk-004/filesystem/
	cd ti-sdk-004/
	sudo tar Jcf ../${OUTPUT_SDKIMG_TGZ}/${OUTPUT_SDKIMG_TAR_XZ}.tar.xz *
	cd ..
	sudo tar zcf ${OUTPUT_SDKIMG_TGZ}.tgz ${OUTPUT_SDKIMG_TGZ}

	generate_md5 ${OUTPUT_SDKIMG_TGZ}.tgz
	mv ${OUTPUT_SDKIMG_TGZ}.tgz $STORAGE_PATH
	mv *.md5 $STORAGE_PATH
	sudo rm -rf ti-sdk-004
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

get_install_files

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

	echo "[ADV] get_rootfs_image"
	get_rootfs_image
	echo "[ADV] get_misc_image"
	get_misc_image
	echo "[ADV] package_ubuntu_rootfs"
	package_ubuntu_rootfs
	echo "[ADV] generate_sdkimg"
	generate_sdkimg
done
