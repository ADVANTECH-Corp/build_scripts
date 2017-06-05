#!/bin/bash  -xe

echo "[ADV] FTP_DIR = ${FTP_DIR}"
echo "[ADV] DATE = ${DATE}"
echo "[ADV] VERSION = ${VERSION}"
echo "[ADV] BL_LINARO_RELEASE = ${BL_LINARO_RELEASE}"
echo "[ADV] BL_BUILD_NUMBER = ${BL_BUILD_NUMBER}"
echo "[ADV] INSTALLER_LINARO_RELEASE = ${INSTALLER_LINARO_RELEASE}"
echo "[ADV] INSTALLER_BUILD_VERSION = ${INSTALLER_BUILD_VERSION}"
echo "[ADV] KERNEL_VERSION = ${KERNEL_VERSION}"
echo "[ADV] TARGET_OS = ${TARGET_OS}"
echo "[ADV] STORED = ${STORED}"
CURR_PATH="$PWD"
STORAGE_PATH="$CURR_PATH/$STORED"
RAMDISK_IMAGE="initrd.img-${KERNEL_VERSION}-linaro-lt-qcom"
BOOT_IMAGE="boot-linaro-stretch-qcom-snapdragon-arm64-${INSTALLER_BUILD_VERSION}"
DEBIAN_ROOTFS="linaro-stretch-alip-qcom-snapdragon-arm64-${INSTALLER_BUILD_VERSION}"

# === 1. Put the debian images into out/ folder. =================================================
function get_debian_images()
{
    # Get Debian ramdisk image
	wget --progress=dot -e dotbytes=2M -P ./out/ \
		 https://builds.96boards.org/releases/dragonboard410c/linaro/debian/${INSTALLER_LINARO_RELEASE}/${RAMDISK_IMAGE}
	# Get Debian rootfs image
	wget --progress=dot -e dotbytes=2M -P ./out/ \
		 https://builds.96boards.org/releases/dragonboard410c/linaro/debian/${INSTALLER_LINARO_RELEASE}/${DEBIAN_ROOTFS}.img.gz

    gunzip out/${DEBIAN_ROOTFS}.img.gz
}

function get_misc_image()
{
    # Get misc images from FTP
    MISC_FILE_NAME="${MISC_VERSION}_${DATE}_misc"

    pftp -v -n 172.22.12.82 <<-EOF
user "ftpuser" "P@ssw0rd"
cd "officialbuild/${FTP_DIR}/${DATE}"
prompt
binary
ls
mget ${MISC_FILE_NAME}.tgz
close
quit
EOF

    tar zxf ${MISC_FILE_NAME}.tgz
    rm ${MISC_FILE_NAME}.tgz

    mv ${MISC_FILE_NAME}/Image--4.4-r0*.bin ./out/Image--4.4-r0.bin
    mv ${MISC_FILE_NAME}/dt-Image--4.4-r0*.img ./out/dt-Image--4.4-r0.img
    tar zxf ${MISC_FILE_NAME}/modules--4.4-r0*.tgz
}

function get_bootimg()
{
	#Get mkbootimg source code
	git clone https://github.com/osm0sis/mkbootimg
	cd mkbootimg

	make

	chmod 775 mkbootimg
	sudo cp -a mkbootimg /usr/bin/
	cd ../
}

function make_boot_image()
{
	#Generate boot image
	mkbootimg \
        --kernel ./out/Image--4.4-r0.bin \
        --ramdisk ./out/${RAMDISK_IMAGE} \
        --output ${OUT_BOOT_IMAGE}.img \
        --dt ./out/dt-Image--4.4-r0.img \
        --pagesize 2048 \
        --base 0x80000000 \
        --cmdline "root=/dev/disk/by-partlabel/rootfs rw rootwait console=ttyMSM0,115200n8"
}

function package_debian_rootfs()
{
        MODULE_VERSION=`echo $(ls lib/modules/)`
	simg2img ./out/${DEBIAN_ROOTFS}.img rootfs_tmp.raw

        sudo losetup /dev/loop1 rootfs_tmp.raw
        sudo mount /dev/loop1 /mnt

        sudo rm -rf /mnt/lib/modules/*
        sudo cp -ar lib/modules/ /mnt/lib/

	# Set up chroot
	sudo cp /usr/bin/qemu-aarch64-static /mnt/usr/bin/

	# Depmod in chroot mode
	sudo chroot /mnt << EOF
depmod -a ${MODULE_VERSION}
chown -R root:root /lib/modules/${MODULE_VERSION}/
exit
EOF

	sudo rm /mnt/usr/bin/qemu-aarch64-static
	sudo umount /mnt
	sudo losetup -d /dev/loop1

	ext2simg -v rootfs_tmp.raw "${OUT_DEBIAN_ROOTFS}".img
	gzip -c9 ${OUT_DEBIAN_ROOTFS}.img > ${OUT_DEBIAN_ROOTFS}.img.gz
	
	tar zcf "${RELEASE_VERSION}_${DATE}".tgz ${OUT_DEBIAN_ROOTFS}.img.gz ${OUT_BOOT_IMAGE}.img
	mv "${RELEASE_VERSION}_${DATE}".tgz $STORAGE_PATH
	
	rm rootfs_tmp.raw ${OUT_BOOT_IMAGE}.img ${OUT_DEBIAN_ROOTFS}.img ${OUT_DEBIAN_ROOTFS}.img.gz
}


# === [Main] List Official Build Version ============================================================
if [ $RSB_4760 == true ]; then
    MACHINE_LIST="$MACHINE_LIST 4760"
fi
if [ $EPC_R4761 == true ]; then
    MACHINE_LIST="$MACHINE_LIST 4761"
fi

NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9]*\)'`
VERSION_NUM=$NUM1$NUM2

if [ $TARGET_OS == "Yocto" ]; then
    OS_PREFIX="L"
elif [ $TARGET_OS == "Debian" ]; then
    OS_PREFIX="D"
fi

get_debian_images
get_bootimg

for NEW_MACHINE in $MACHINE_LIST
do
    MISC_VERSION="${NEW_MACHINE}LIV${VERSION_NUM}"
    RELEASE_VERSION="${NEW_MACHINE}${OS_PREFIX}IV${VERSION_NUM}"

    if [ $NEW_MACHINE == "4760" ]; then
        PRODUCT="RSB-4760"
    elif [ $NEW_MACHINE == "4761" ]; then
        PRODUCT="EPC-R4761"
    fi
	
	L_PRODUCT=`echo ${PRODUCT} | awk '{print tolower($0)}'`
	OUT_BOOT_IMAGE=`echo ${BOOT_IMAGE} | sed 's/linaro/'$(echo $L_PRODUCT)'/g'`
	OUT_DEBIAN_ROOTFS=`echo ${DEBIAN_ROOTFS} | sed 's/linaro/'$(echo $L_PRODUCT)'/g'`
	
	get_misc_image
	make_boot_image
	package_debian_rootfs
done
