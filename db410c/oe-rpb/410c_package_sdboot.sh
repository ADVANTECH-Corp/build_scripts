#!/bin/bash  -xe

echo "[ADV] FTP_SITE = ${FTP_SITE}"
echo "[ADV] FTP_DIR = ${FTP_DIR}"
echo "[ADV] DATE = ${DATE}"
echo "[ADV] VERSION = ${VERSION}"
echo "[ADV] DEBIAN_LINARO_RELEASE = ${DEBIAN_LINARO_RELEASE}"
echo "[ADV] DEBIAN_BUILD_VERSION = ${DEBIAN_BUILD_VERSION}"
echo "[ADV] DEBIAN_OS_FLAVOUR= ${DEBIAN_OS_FLAVOUR}"
echo "[ADV] KERNEL_VERSION = ${KERNEL_VERSION}"
echo "[ADV] STORED = ${STORED}"
CURR_PATH="$PWD"
STORAGE_PATH="$CURR_PATH/$STORED"

INSTALLER_RAMDISK_IMAGE="initrd.img-${KERNEL_VERSION}-linaro-lt-qcom"
INSTALLER_BOOT_IMAGE="boot-installer-linaro-${DEBIAN_OS_FLAVOUR}-qcom-snapdragon-arm64-${DEBIAN_BUILD_VERSION}"
SDBOOT_RAMDISK_IMAGE="initrd.img"
SDBOOT_BOOT_IMAGE="boot-sdboot-linaro-${DEBIAN_OS_FLAVOUR}-qcom-snapdragon-arm64-${DEBIAN_BUILD_VERSION}"

# === 1. Put the initrd images into out/ folder. =================================================
function get_initrd_images()
{
    # Get sd-installer ramdisk image
    pftp -v -n ${FTP_SITE} <<-EOF
user "ftpuser" "P@ssw0rd"
cd "Image/db410c/96boards/${DEBIAN_LINARO_RELEASE}"
prompt
binary
ls
mget ${INSTALLER_RAMDISK_IMAGE}
close
quit
EOF
    mkdir ./out
    mv ${INSTALLER_RAMDISK_IMAGE} ./out/
    # Get sd-boot ramdisk image
    echo "This is not an initrd" > out/${SDBOOT_RAMDISK_IMAGE}
}

function get_misc_image()
{
    # Get misc images from FTP
    MISC_FILE_NAME="${MISC_VERSION}_${DATE}_misc"

    pftp -v -n ${FTP_SITE} <<-EOF
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

    mv ${MISC_FILE_NAME}/Image-*.bin ./out/Image
    mv ${MISC_FILE_NAME}/dt-*.img ./out/dt.img
}

function get_bootimg()
{
	#Get mkbootimg source code
	#git fork from https://github.com/osm0sis/mkbootimg
	git clone https://github.com/ADVANTECH-Corp/mkbootimg
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
        --kernel ./out/Image \
        --ramdisk ./out/${RAMDISK_IMAGE} \
        --output ${OUT_BOOT_IMAGE}.img \
        --dt ./out/dt.img \
        --pagesize 2048 \
        --base 0x80000000 \
        --cmdline "root=/dev/${QCOM_BOOTIMG_ROOTFS} rw rootwait console=ttyMSM0,115200n8"
}

function generate_md5()
{
    FILENAME=$1

    if [ -e $FILENAME ]; then
        MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
        echo $MD5_SUM > $FILENAME.md5
    fi
}

function package_sdboot()
{
	SDBOOT_IMAGES="${RELEASE_VERSION}_${DATE}_sdboot"
	tar zcf ${SDBOOT_IMAGES}.tgz *.img
	generate_md5 ${SDBOOT_IMAGES}.tgz

	mv ${SDBOOT_IMAGES}.tgz $STORAGE_PATH
	mv *.md5 $STORAGE_PATH
}


# === [Main] List Official Build Version ============================================================
if [ $RSB_4760 == true ]; then
    MACHINE_LIST="$MACHINE_LIST 4760"
fi
if [ $EPC_R4761 == true ]; then
    MACHINE_LIST="$MACHINE_LIST 4761"
fi

NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
VERSION_NUM=$NUM1$NUM2

get_initrd_images
get_bootimg

for NEW_MACHINE in $MACHINE_LIST
do
    MISC_VERSION="${NEW_MACHINE}LIV${VERSION_NUM}"
    RELEASE_VERSION="${MISC_VERSION}"

    if [ $NEW_MACHINE == "4760" ]; then
        PRODUCT="RSB-4760"
    elif [ $NEW_MACHINE == "4761" ]; then
        PRODUCT="EPC-R4761"
    fi

	L_PRODUCT=`echo ${PRODUCT} | awk '{print tolower($0)}'`
	get_misc_image

	# sd-installer
	RAMDISK_IMAGE=${INSTALLER_RAMDISK_IMAGE}
	OUT_BOOT_IMAGE=`echo ${INSTALLER_BOOT_IMAGE} | sed 's/linaro/'$(echo $L_PRODUCT)'/g'`
	QCOM_BOOTIMG_ROOTFS="mmcblk1p8"
	
	make_boot_image

	# sd-boot for factory
	RAMDISK_IMAGE=${SDBOOT_RAMDISK_IMAGE}
	OUT_BOOT_IMAGE=`echo ${SDBOOT_BOOT_IMAGE} | sed 's/linaro/'$(echo $L_PRODUCT)'/g'`
	QCOM_BOOTIMG_ROOTFS="mmcblk1p13"

	make_boot_image
done

package_sdboot

