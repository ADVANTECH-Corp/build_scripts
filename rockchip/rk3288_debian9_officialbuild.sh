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

# ================
#  Main procedure 
# ================
    mkdir $ROOT_DIR
    get_source_code
    build_linux_images

echo "[ADV] build script done!"

