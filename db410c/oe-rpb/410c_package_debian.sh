#!/bin/bash

echo "[ADV] FTP_SITE = ${FTP_SITE}"
echo "[ADV] FTP_DIR = ${FTP_DIR}"
echo "[ADV] DATE = ${DATE}"
echo "[ADV] VERSION = ${VERSION}"
echo "[ADV] DEBIAN_LINARO_RELEASE = ${DEBIAN_LINARO_RELEASE}"
echo "[ADV] DEBIAN_BUILD_VERSION = ${DEBIAN_BUILD_VERSION}"
echo "[ADV] DEBIAN_OS_FLAVOUR= ${DEBIAN_OS_FLAVOUR}"
echo "[ADV] KERNEL_VERSION = ${KERNEL_VERSION}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] STORED = ${STORED}"
CURR_PATH="$PWD"
STORAGE_PATH="$CURR_PATH/$STORED"
RAMDISK_IMAGE="initrd.img-${KERNEL_VERSION}-linaro-lt-qcom"
BOOT_IMAGE="boot-linaro-stretch-qcom-snapdragon-arm64-${DEBIAN_BUILD_VERSION}"
DEBIAN_ROOTFS="linaro-${DEBIAN_OS_FLAVOUR}-alip-qcom-snapdragon-arm64-${DEBIAN_BUILD_VERSION}"

# === 1. Put the debian images into out/ folder. =================================================
function get_debian_images()
{
    # Get Debian ramdisk & rootfs images
    pftp -v -n ${FTP_SITE} <<-EOF
user "ftpuser" "P@ssw0rd"
cd "Image/db410c/96boards/${DEBIAN_LINARO_RELEASE}"
prompt
binary
ls
mget ${RAMDISK_IMAGE}
mget ${DEBIAN_ROOTFS}.img.gz
close
quit
EOF
    mkdir ./out
    mv ${RAMDISK_IMAGE} ./out/
    mv ${DEBIAN_ROOTFS}.img.gz ./out/
    gunzip out/${DEBIAN_ROOTFS}.img.gz
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
    for MODULE_TARBALL in ${MISC_FILE_NAME}/modules-*.tgz
    do
        tar zxf ${MODULE_TARBALL}
    done
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
        --cmdline "root=/dev/disk/by-partlabel/rootfs rw rootwait console=ttyMSM0,115200n8"
}

function generate_md5()
{
    FILENAME=$1

    if [ -e $FILENAME ]; then
        MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
        echo $MD5_SUM > $FILENAME.md5
    fi
}

function resize_image()
{
	LOOP_DEV=$1

	dd if=/dev/zero of=rootfs_new.img bs=1M count=3000

	sudo losetup $LOOP_DEV rootfs_new.img

	sudo dd if=rootfs_tmp.raw of=$LOOP_DEV

	sudo e2fsck -f -y $LOOP_DEV
	sudo resize2fs $LOOP_DEV
}

function package_debian_rootfs()
{
	MODULE_VERSION=`echo $(ls lib/modules/)`

	# WiFi calibration data
	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-qcom-410c/recipes-bsp/firmware/files/WCNSS_qcom_wlan_nv.bin

	# Mbed
	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/factory-configurator-client/files/dragonboard-410c/factory-configurator-client-example.elf

	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/dragonboard-410c/edge-core
	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/dragonboard-410c/edge-core-dev
	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/dragonboard-410c/lorapt-example
	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/dragonboard-410c/pt-example
	wget --progress=dot -e dotbytes=2M \
		https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH%-EdgeSense}/meta-Edge-Sense/recipes-mbed/mbed-edge/files/dragonboard-410c/pt-example_1520

	# Resize rootfs image
	sudo umount /mnt

	for ((i=1;i<=7;i++))
	do
		LOOP_DEV="/dev/loop${i}"
		sudo losetup -a | grep $LOOP_DEV
		if [ $? -eq 0 ]
		then
		    echo "$LOOP_DEV busy"
		else
		    echo "$LOOP_DEV free"
		    break
		fi
	done

	simg2img ./out/${DEBIAN_ROOTFS}.img rootfs_tmp.raw
	resize_image $LOOP_DEV

	sudo mount $LOOP_DEV /mnt

	# Copy files
	sudo rm -rf /mnt/lib/modules/*
	sudo cp -ar lib/modules/ /mnt/lib/
	sudo cp -a  WCNSS_qcom_wlan_nv.bin /mnt/lib/firmware/wlan/prima/

	sudo mkdir /mnt/tools
	sudo chmod 755 *
	sudo cp -a  factory-configurator-client-example.elf /mnt/usr/bin/
	sudo cp -a  edge-core /mnt/usr/bin/
	sudo cp -a  edge-core-dev /mnt/tools/
	sudo cp -a  lorapt-example /mnt/usr/bin/
	sudo cp -a  pt-example /mnt/usr/bin/
	sudo cp -a  pt-example_1520 /mnt/usr/bin/

	# Set network interface to eth0
	sudo mv /mnt/lib/udev/rules.d/73-usb-net-by-mac.rules /mnt/lib/udev/rules.d/73-usb-net-by-mac.rules.xxx

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
	sudo losetup -d $LOOP_DEV

	ext2simg -v rootfs_new.img "${OUT_DEBIAN_ROOTFS}".img
	gzip -c9 ${OUT_DEBIAN_ROOTFS}.img > ${OUT_DEBIAN_ROOTFS}.img.gz
	
	tar zcf "${RELEASE_VERSION}_${DATE}_${DEBIAN_OS_FLAVOUR}".tgz ${OUT_DEBIAN_ROOTFS}.img.gz ${OUT_BOOT_IMAGE}.img
	generate_md5 "${RELEASE_VERSION}_${DATE}_${DEBIAN_OS_FLAVOUR}".tgz
	mv "${RELEASE_VERSION}_${DATE}_${DEBIAN_OS_FLAVOUR}".tgz $STORAGE_PATH
	mv *.md5 $STORAGE_PATH
	
	rm rootfs_new.img rootfs_tmp.raw ${OUT_BOOT_IMAGE}.img ${OUT_DEBIAN_ROOTFS}.img ${OUT_DEBIAN_ROOTFS}.img.gz
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

# Debian
 OS_PREFIX="D"

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
