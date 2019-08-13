#!/bin/bash

PRODUCT=$1
VER_PREFIX="rk"


echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST= ${MACHINE_LIST}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"
#echo "[ADV] SCRIPT_XML = ${SCRIPT_XML}"
echo "[ADV] KERNEL_CONFIG = ${KERNEL_CONFIG}"
echo "[ADV] KERNEL_DTB = ${KERNEL_DTB}"
CURR_PATH="$PWD"
ROOT_DIR="${VER_PREFIX}AB${RELEASE_VERSION}"_"$DATE"
OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"


#======================
AND_BSP="android"
AND_BSP_VER="7.1"
AND_VERSION="android_N7.1.2"

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

function save_temp_log()
{
    LOG_PATH="$CURR_PATH/$ROOT_DIR"
    cd $LOG_PATH

    LOG_DIR="DI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"_log
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

function building()
{
    echo "[ADV] building $1 ..."
    LOG_FILE="$NEW_MACHINE"_Build.log
    LOG2_FILE="$NEW_MACHINE"_Build2.log
    LOG3_FILE="$NEW_MACHINE"_Build3.log

    if [ "$1" == "uboot" ]; then
        echo "[ADV] build uboot"
		cd $CURR_PATH/$ROOT_DIR/u-boot
		#make clean
		./make.sh rk3399 >> $CURR_PATH/$ROOT_DIR/$LOG_FILE
	elif [ "$1" == "kernel" ]; then
		echo "[ADV] build kernel  = $KERNEL_CONFIG"
        echo "[ADV] build kernel dtb  = $KERNEL_DTB"
		cd $CURR_PATH/$ROOT_DIR/kernel
		#make distclean
		make ARCH=arm64 $KERNEL_CONFIG
		make ARCH=arm64 $KERNEL_DTB -j16 >> $CURR_PATH/$ROOT_DIR/$LOG2_FILE
        echo "[ADV] build kernel Finished"
    elif [ "$1" == "recovery" ]; then
		echo "[ADV] build recovery"
		cd $CURR_PATH/$ROOT_DIR
		./build.sh recovery
    elif [ "$1" == "buildroot" ]; then
		echo "[ADV] build buildroot"
		cd $CURR_PATH/$ROOT_DIR
		./build.sh rootfs
    elif [ "$1" == "debian" ]; then
        cd $CURR_PATH/$ROOT_DIR/rootfs
        echo "[ADV] install tools for build debian"
        sudo apt-get install -y binfmt-support
        sudo apt-get install -y qemu-user-static
		sudo apt-get -y update
		sudo apt-get install -y live-build
        echo "[ADV] dpkg packages"
        sudo dpkg -i ubuntu-build-service/packages/*
        sudo apt-get install -f
        echo "[ADV]-------------FOR armhf  32-----------"
        #echo "[ADV] armhf mk-base-debian.sh"
        #RELEASE=stretch TARGET=desktop ARCH=armhf ./mk-base-debian.sh
        #echo "[ADV] mk-rootfs-stretch.sh"
        #VERSION=debug ARCH=armhf ./mk-rootfs-stretch.sh
        #echo "[ADV] mk-image.sh armhf"
        #./mk-image.sh
        #echo "[ADV]---------------------------------"
        echo "[ADV]-------------FOR arm64  64-----------"
        echo "[ADV] arm64 mk-base-debian.sh"
        RELEASE=stretch TARGET=desktop ARCH=arm64 ./mk-base-debian.sh
        echo "[ADV] mk-rootfs-stretch-arm64.sh"
        VERSION=debug ARCH=arm64 ./mk-rootfs-stretch-arm64.sh
        echo "[ADV] add advantech "
        cp -aRL $CURR_PATH/$ROOT_DIR/rootfs/adv/* $CURR_PATH/$ROOT_DIR/rootfs
        ./mk-adv.sh ARCH=arm64
        ./mk-adv-module.sh ARCH=arm64
        ./mk-adv-word.sh ARCH=arm64
		echo "[ADV] check MACHINE is dms53"
	if [ "$NEW_MACHINE" == "dmssa53" ]; then
		echo "[ADV] mk-adv-dms53 shell script"
		./mk-adv-dms53.sh ARCH=arm64
	fi
	echo "[ADV] mk-image.sh arm64 "
        ./mk-image.sh
        sudo tar cvf binary.tgz $CURR_PATH/$ROOT_DIR/rootfs/binary
	echo "[ADV]---------------------------------"
    	cd $CURR_PATH/$ROOT_DIR 
    	./build.sh BoardConfig_debian.mk
	    ./mkfirmware.sh


    else
    echo "[ADV] pass building..."
    fi
    [ "$?" -ne 0 ] && echo "[ADV] Build failure! Check log file '$LOG_FILE'" && exit 1
}

function set_environment()
{
    echo "[ADV] set environment"
    cd $CURR_PATH/$ROOT_DIR
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/
	export PATH=$JAVA_HOME/bin:$PATH
	export CLASSPATH=.:$JAVA_HOME/lib:$JAVA_HOME/lib/tools.jar
}

function build_linux_images()
{
	cd $CURR_PATH/$ROOT_DIR
	#set_environment
	building uboot
	building kernel
#	building recovery
	building buildroot
	building debian

    #=== package image to rockdev folder ===
	cd $CURR_PATH/$ROOT_DIR
}

function prepare_images()
{
    cd $CURR_PATH

    IMAGE_DIR="DI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR

    # Copy image files to image directory

    cp -aRL $CURR_PATH/$ROOT_DIR/u-boot/*.bin $IMAGE_DIR
	cp -aRL $CURR_PATH/$ROOT_DIR/u-boot/trust.img $IMAGE_DIR
	cp -aRL $CURR_PATH/$ROOT_DIR/u-boot/uboot.img $IMAGE_DIR
	cp -aRL $CURR_PATH/$ROOT_DIR/kernel/boot.img $IMAGE_DIR
	cp -aRL $CURR_PATH/$ROOT_DIR/buildroot/output/rockchip_rk3399_recovery/images/recovery.img $IMAGE_DIR
    cp -aRL $CURR_PATH/$ROOT_DIR/buildroot/output/rockchip_rk3399/images/rootfs.ext4 $IMAGE_DIR
    cp -aRL $CURR_PATH/$ROOT_DIR/out/linaro-rootfs.img $IMAGE_DIR
    cp -aRL $CURR_PATH/$ROOT_DIR/rockdev/oem* $IMAGE_DIR
    cp -aRL $CURR_PATH/$ROOT_DIR/device/rockchip/rk3399/parameter* $IMAGE_DIR
    cp -aRL $CURR_PATH/$ROOT_DIR/rootfs/linaro-rootfs.img $IMAGE_DIR
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
    sudo mv -f $CURR_PATH/$ROOT_DIR/rootfs/binary.tgz $OUTPUT_DIR
}
# ================
#  Main procedure 
# ================


if [ "$PRODUCT" == "$VER_PREFIX" ]; then
echo "[ADV] get rockchip code"
mkdir $ROOT_DIR
cd $ROOT_DIR
if [ "$BSP_BRANCH" == "" ] ; then
	 echo "[ADV] BSP_BRANCH is null"
    repo init -u $BSP_URL
elif [ "$BSP_XML" == "" ] ; then
	 echo "[ADV] BSP_XML is null"
    repo init -u $BSP_URL -b $BSP_BRANCH
else
	 echo "[ADV] BSP BRANCH AND URL is not null"
    repo init -u $BSP_URL -b $BSP_BRANCH -m $BSP_XML
fi
repo sync

else #"$PRODUCT" != "$VER_PREFIX"
echo "[ADV] build images"

for NEW_MACHINE in $MACHINE_LIST
do
echo "[ADV] NEW_MACHINE = $NEW_MACHINE"
	build_linux_images
echo "[ADV] prepare_images"
	prepare_images
echo "[ADV] copy_image_to_storage"
	copy_image_to_storage
	save_temp_log
done

fi
cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

