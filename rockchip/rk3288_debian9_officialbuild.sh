#!/bin/bash

VER_PREFIX="rk"

for i in $MACHINE_LIST
do
        NEW_MACHINE=$i
done

RELEASE_VERSION=$1
echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST= ${MACHINE_LIST}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"
VER_TAG="${VER_PREFIX}ABV"$(echo $RELEASE_VERSION | sed 's/[.]//')
echo "[ADV] VER_TAG = $VER_TAG"
CURR_PATH="$PWD"
ROOT_DIR="${VER_PREFIX}ABV${RELEASE_VERSION}"_"$DATE"
OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"

echo "$Release_Note" > Release_Note
REALEASE_NOTE="Release_Note"

#--------------------------------------------------
#======================
AND_BSP="debian"
AND_BSP_VER="9.5"
AND_VERSION="debian_V9.5"

#======================

# Make storage folder
if [ -e $OUTPUT_DIR ] ; then
    echo "[ADV] $OUTPUT_DIR had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR"
    mkdir -p $OUTPUT_DIR
fi

# ===========
#  Functions
# ===========
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

    HASH_DEBIAN_UBOOT=$(cd $CURR_PATH/$ROOT_DIR/u-boot && git rev-parse --short HEAD)
    HASH_DEBIAN_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/kernel && git rev-parse --short HEAD)
    HASH_DEBIAN_APP=$(cd $CURR_PATH/$ROOT_DIR/app && git rev-parse --short HEAD)
    HASH_DEBIAN_BUILDROOT=$(cd $CURR_PATH/$ROOT_DIR/buildroot && git rev-parse --short HEAD)
    HASH_DEBIAN_DEVICE=$(cd $CURR_PATH/$ROOT_DIR/device && git rev-parse --short HEAD)
    HASH_DEBIAN_EXTERNAL=$(cd $CURR_PATH/$ROOT_DIR/external && git rev-parse --short HEAD)
    HASH_DEBIAN_PREBUILTS=$(cd $CURR_PATH/$ROOT_DIR/prebuilts && git rev-parse --short HEAD)
    HASH_DEBIAN_RKBIN=$(cd $CURR_PATH/$ROOT_DIR/rkbin && git rev-parse --short HEAD)
    HASH_DEBIAN_ROOTFS=$(cd $CURR_PATH/$ROOT_DIR/rootfs && git rev-parse --short HEAD)
    HASH_DEBIAN_TOOLS=$(cd $CURR_PATH/$ROOT_DIR/tools && git rev-parse --short HEAD)

    cd $CURR_PATH


    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Debian GNU/Linux 9.x (stretch)
Part Number,N/A
Author,
Date,${DATE}
Build Number,${BUILD_NUMBER}
TAG,
Tested Platform,${NEW_MACHINE}
MD5 Checksum,TGZ: ${MD5_SUM}
Image Size,${FILE_SIZE}B (${FILE_SIZE_BYTE} bytes)
Issue description, N/A
Function Addition,
Manifest, ${HASH_BSP}

DEBIAN_UBOOT, ${HASH_DEBIAN_UBOOT}
DEBIAN_KERNEL, ${HASH_DEBIAN_KERNEL}
DEBIAN_APP, ${HASH_DEBIAN_APP}
DEBIAN_BUILDROOT, ${HASH_DEBIAN_BUILDROOT}
DEBIAN_DEVICE, ${HASH_DEBIAN_DEVICE}
DEBIAN_EXTERNAL, ${HASH_DEBIAN_EXTERNAL}
DEBIAN_PREBUILTS, ${HASH_DEBIAN_PREBUILTS}
DEBIAN_RKBIN, ${HASH_DEBIAN_RKBIN}
DEBIAN_ROOTFS, ${HASH_DEBIAN_ROOTFS}
DEBIAN_TOOLS, ${HASH_DEBIAN_TOOLS}



END_OF_CSV
}

function save_temp_log()
{
    LOG_PATH="$CURR_PATH/$ROOT_DIR"
    cd $LOG_PATH

    LOG_DIR="AI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"_log
    echo "[ADV] mkdir $LOG_DIR"
    mkdir $LOG_DIR

    # Backup conf, run script & log file
    cp -a *.log $LOG_DIR

    echo "[ADV] creating ${LOG_DIR}.tgz ..."
    tar czf $LOG_DIR.tgz $LOG_DIR
    generate_md5 $LOG_DIR.tgz

    mv -f $LOG_DIR.tgz $OUTPUT_DIR
    mv -f $LOG_DIR.tgz.md5 $OUTPUT_DIR

    # Remove all temp logs
    rm -rf $LOG_DIR
}

function get_source_code()
{
    echo "[ADV] get rk3288 debian9 source code"
    mkdir $ROOT_DIR
    cd $ROOT_DIR

    if [ "$BSP_BRANCH" == "" ] ; then
       repo init -u $BSP_URL
    elif [ "$BSP_XML" == "" ] ; then
       repo init -u $BSP_URL -b $BSP_BRANCH
    else
       repo init -u $BSP_URL -b $BSP_BRANCH -m $BSP_XML
    fi
    repo sync

    cd $CURR_PATH
}

function building()
{
    echo "[ADV] building $1 ..."
    LOG_FILE="$NEW_MACHINE"_Build.log

    if [ "$1" == "uboot" ]; then
        echo "[ADV] build uboot UBOOT_DEFCONFIG=$UBOOT_DEFCONFIG"
		cd $CURR_PATH/$ROOT_DIR/u-boot
		./make.sh $UBOOT_DEFCONFIG
	elif [ "$1" == "kernel" ]; then
		echo "[ADV] build kernel KERNEL_DEFCONFIG = $KERNEL_DEFCONFIG KERNEL_DTB=$KERNEL_DTB"
		cd $CURR_PATH/$ROOT_DIR/kernel

		echo "[ADV] build kernel make ARCH=arm $KERNEL_DEFCONFIG"
		make ARCH=arm $KERNEL_DEFCONFIG
		echo "[ADV] build kernel make ARCH=arm $KERNEL_DTB -j12"
		make ARCH=arm $KERNEL_DTB -j12
    elif [ "$1" == "recovery" ]; then
		echo "[ADV] build recovery"
		cd $CURR_PATH/$ROOT_DIR
		source envsetup.sh 20
		./build.sh recovery
    elif [ "$1" == "rootfs" ]; then
		echo "[ADV] build rootfs"
		cd $CURR_PATH/$ROOT_DIR/rootfs
		sudo dpkg -i ubuntu-build-service/packages/*
		sudo apt-get install -f 
		./mk-base-debian.sh ARCH=armhf
		./mk-rootfs.sh ARCH=armhf
		./mk-adv.sh ARCH=armhf
		./mk-image.sh
	else
        echo "[ADV] pass building..."
    fi
    [ "$?" -ne 0 ] && echo "[ADV] Build failure! Check log file '$LOG_FILE'" && exit 1
}


function build_linux_images()
{
    cd $CURR_PATH/$ROOT_DIR
	echo "[ADV] build linux images begin"
	
	building uboot
	building kernel
	building rootfs
	building recovery

    # package image to rockdev folder
	cd $CURR_PATH/$ROOT_DIR
	echo "[ADV] build link images to rockdev"
	./mkfirmware.sh
	echo "[ADV] build linux images end"
}

function prepare_images()
{
    cd $CURR_PATH

    IMAGE_DIR="AI${RELEASE_VERSION}"_"$NEW_MACHINE"_Debian_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR
	mkdir -p $IMAGE_DIR/rockdev/image

    # Copy image files to image directory

    cp -a $CURR_PATH/$ROOT_DIR/rockdev/* $IMAGE_DIR/rockdev/image
    echo "[ADV] creating ${IMAGE_DIR}.tgz ..."
    tar czf ${IMAGE_DIR}.tgz $IMAGE_DIR
    generate_md5 ${IMAGE_DIR}.tgz
    #rm -rf $IMAGE_DIR
}

function copy_image_to_storage()
{
    echo "[ADV] copy images to $OUTPUT_DIR"

    generate_csv ${IMAGE_DIR}.tgz
    mv ${IMAGE_DIR}.csv $OUTPUT_DIR

    mv -f ${IMAGE_DIR}.tgz $OUTPUT_DIR
    mv -f *.md5 $OUTPUT_DIR

}

# ================
#  Main procedure 
# ================
    mkdir $ROOT_DIR
    get_source_code
    build_linux_images
    prepare_images
    copy_image_to_storage
    save_temp_log


echo "[ADV] build script done!"

