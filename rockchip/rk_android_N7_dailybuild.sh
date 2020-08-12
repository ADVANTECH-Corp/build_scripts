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

    #HASH_BSP=$(cd $CURR_PATH/$ROOT_DIR/.repo/manifests && git rev-parse --short HEAD)
    HASH_ANDROID_RKTOOLS=$(cd $CURR_PATH/$ROOT_DIR/RKTools && git rev-parse --short HEAD)
    HASH_ANDROID_ABI=$(cd $CURR_PATH/$ROOT_DIR/abi && git rev-parse --short HEAD)
    HASH_ANDROID_ART=$(cd $CURR_PATH/$ROOT_DIR/art && git rev-parse --short HEAD)
    HASH_ANDROID_BIONIC=$(cd $CURR_PATH/$ROOT_DIR/bionic && git rev-parse --short HEAD)
    HASH_ANDROID_BOOTABLE=$(cd $CURR_PATH/$ROOT_DIR/bootable && git rev-parse --short HEAD)
    HASH_ANDROID_BUILD=$(cd $CURR_PATH/$ROOT_DIR/build && git rev-parse --short HEAD)
    HASH_ANDROID_CTS=$(cd $CURR_PATH/$ROOT_DIR/cts && git rev-parse --short HEAD) 
    HASH_ANDROID_DALVIK=$(cd $CURR_PATH/$ROOT_DIR/dalvik && git rev-parse --short HEAD)
    HASH_ANDROID_DEVELOPERS=$(cd $CURR_PATH/$ROOT_DIR/developers && git rev-parse --short HEAD)
    HASH_ANDROID_DEVELOPMENT=$(cd $CURR_PATH/$ROOT_DIR/development && git rev-parse --short HEAD)
    HASH_ANDROID_DEVICE=$(cd $CURR_PATH/$ROOT_DIR/device && git rev-parse --short HEAD)
    HASH_ANDROID_DOCS=$(cd $CURR_PATH/$ROOT_DIR/docs && git rev-parse --short HEAD)
    HASH_ANDROID_EXTERNAL=$(cd $CURR_PATH/$ROOT_DIR/external && git rev-parse --short HEAD)
    HASH_ANDROID_FRAMEWORKS=$(cd $CURR_PATH/$ROOT_DIR/frameworks && git rev-parse --short HEAD)
    HASH_ANDROID_HARDWARE=$(cd $CURR_PATH/$ROOT_DIR/hardware && git rev-parse --short HEAD)
    HASH_ANDROID_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/kernel && git rev-parse --short HEAD)
    HASH_ANDROID_LIBCORE=$(cd $CURR_PATH/$ROOT_DIR/libcore && git rev-parse --short HEAD)
    HASH_ANDROID_LIBNATIVEHELPER=$(cd $CURR_PATH/$ROOT_DIR/libnativehelper && git rev-parse --short HEAD)
    HASH_ANDROID_NDK=$(cd $CURR_PATH/$ROOT_DIR/ndk && git rev-parse --short HEAD)
    HASH_ANDROID_PACKAGES=$(cd $CURR_PATH/$ROOT_DIR/packages && git rev-parse --short HEAD)
    HASH_ANDROID_PDK=$(cd $CURR_PATH/$ROOT_DIR/pdk && git rev-parse --short HEAD)
    HASH_ANDROID_PLATFORM_TESTING=$(cd $CURR_PATH/$ROOT_DIR/platform_testing && git rev-parse --short HEAD)
    HASH_ANDROID_PREBUILTS=$(cd $CURR_PATH/$ROOT_DIR/prebuilts && git rev-parse --short HEAD)
    HASH_ANDROID_REPO=$(cd $CURR_PATH/$ROOT_DIR/repo && git rev-parse --short HEAD)
    HASH_ANDROID_RKST=$(cd $CURR_PATH/$ROOT_DIR/rkst && git rev-parse --short HEAD)
    HASH_ANDROID_SDK=$(cd $CURR_PATH/$ROOT_DIR/sdk && git rev-parse --short HEAD)
    HASH_ANDROID_SYSTEM=$(cd $CURR_PATH/$ROOT_DIR/system && git rev-parse --short HEAD)
    HASH_ANDROID_TOOLCHAIN=$(cd $CURR_PATH/$ROOT_DIR/toolchain && git rev-parse --short HEAD)
    HASH_ANDROID_TOOLS=$(cd $CURR_PATH/$ROOT_DIR/tools && git rev-parse --short HEAD)
    HASH_ANDROID_UBOOT=$(cd $CURR_PATH/$ROOT_DIR/u-boot && git rev-parse --short HEAD)
    HASH_ANDROID_VENDOR=$(cd $CURR_PATH/$ROOT_DIR/vendor && git rev-parse --short HEAD)
    cd $CURR_PATH


    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Android 7.1.1
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
Android-manifest, ${HASH_BSP}

ANDROID_RKTOOLS, ${HASH_ANDROID_RKTOOLS}
ANDROID_ABI, ${HASH_ANDROID_ABI}
ANDROID_ART, ${HASH_ANDROID_ART}
ANDROID_BIONIC, ${HASH_ANDROID_BIONIC}
ANDROID_BOOTABLE, ${HASH_ANDROID_BOOTABLE}
ANDROID_BUILD, ${HASH_ANDROID_BUILD}
ANDROID_CTS, ${HASH_ANDROID_CTS}
ANDROID_DALVIK, ${HASH_ANDROID_DALVIK}
ANDROID_DEVELOPERS, ${HASH_ANDROID_DEVELOPERS}
ANDROID_DEVELOPMENT, ${HASH_ANDROID_DEVELOPMENT}
ANDROID_DEVICE, ${HASH_ANDROID_DEVICE}
ANDROID_DOCS, ${HASH_ANDROID_DOCS}
ANDROID_EXTERNAL, ${HASH_ANDROID_EXTERNAL}
ANDROID_FRAMEWORKS, ${HASH_ANDROID_FRAMEWORKS}
ANDROID_HARDWARE, ${HASH_ANDROID_HARDWARE}
ANDROID_KERNEL, ${HASH_ANDROID_KERNEL}
ANDROID_LIBCORE, ${HASH_ANDROID_LIBCORE}
ANDROID_LIBNATIVEHELPER, ${HASH_ANDROID_LIBNATIVEHELPER}
ANDROID_NDK, ${HASH_ANDROID_NDK}
ANDROID_PACKAGES, ${HASH_ANDROID_PACKAGES}
ANDROID_PDK, ${HASH_ANDROID_PDK}
ANDROID_PLATFORM_TESTING, ${HASH_ANDROID_PLATFORM_TESTING}
ANDROID_PREBUILTS, ${HASH_ANDROID_PREBUILTS}
ANDROID_REPO, ${HASH_ANDROID_REPO}
ANDROID_RKST, ${HASH_ANDROID_RKST}
ANDROID_SDK, ${HASH_ANDROID_SDK}
ANDROID_SYSTEM, ${HASH_ANDROID_SYSTEM}
ANDROID_TOOLCHAIN, ${HASH_ANDROID_TOOLCHAIN}
ANDROID_TOOLS, ${HASH_ANDROID_TOOLS}
ANDROID_UBOOT, ${HASH_ANDROID_UBOOT}
ANDROID_VENDOR, ${HASH_ANDROID_VENDOR}

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

function building()
{
    echo "[ADV] building $1 ..."
    LOG_FILE="$NEW_MACHINE"_Build.log
    LOG2_FILE="$NEW_MACHINE"_Build2.log
    LOG3_FILE="$NEW_MACHINE"_Build3.log

    if [ "$1" == "uboot" ]; then
        echo "[ADV] build uboot"
		cd $CURR_PATH/$ROOT_DIR/u-boot
		make clean
		make rk3399_box_defconfig
		make ARCHV=aarch64 -j12 2>> $CURR_PATH/$ROOT_DIR/$LOG_FILE
	elif [ "$1" == "kernel" ]; then
		echo "[ADV] build kernel  = $KERNEL_CONFIG"
		cd $CURR_PATH/$ROOT_DIR/kernel
		make distclean
		make ARCH=arm64 $KERNEL_CONFIG
		make ARCH=arm64 $KERNEL_DTB -j16 >> $CURR_PATH/$ROOT_DIR/$LOG2_FILE
    elif [ "$1" == "android" ]; then
		echo "[ADV] build android"
		cd $CURR_PATH/$ROOT_DIR
		source build/envsetup.sh
		if [ ${MACHINE_LIST} == "ds211" ]; then
			lunch ds211_box-userdebug
		else
			lunch rk3399_box-userdebug
		fi
		make clean
		make -j4 2>> $CURR_PATH/$ROOT_DIR/$LOG3_FILE
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

function build_android_images()
{
    cd $CURR_PATH/$ROOT_DIR

	set_environment
    # Android 
	building uboot
	building kernel
	building android
    # package image to rockdev folder
    ./mkimage.sh
}

function build_ota_images()
{
    cd $CURR_PATH/$ROOT_DIR
    rm -rf $CURR_PATH/$ROOT_DIR/rockdev/*
    ./mkimage.sh ota
}

function prepare_images()
{
    cd $CURR_PATH

    IMAGE_DIR="AI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR

    # Copy image files to image directory


	cp -a $CURR_PATH/$ROOT_DIR/rockdev/* $IMAGE_DIR

    echo "[ADV] creating ${IMAGE_DIR}.tgz ..."
    tar czf ${IMAGE_DIR}.tgz $IMAGE_DIR
    generate_md5 ${IMAGE_DIR}.tgz
    #rm -rf $IMAGE_DIR
}

function prepare_ota_images()
{
    cd $CURR_PATH

    OTA_IMAGE_DIR="OTA_AI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
    echo "[ADV] mkdir $OTA_IMAGE_DIR"
    mkdir $OTA_IMAGE_DIR
    #mkdir $CURR_PATH/rockdev/Image
    # Copy image files to image directory


	cp -a $CURR_PATH/$ROOT_DIR/rockdev/* $OTA_IMAGE_DIR

    cp -a $CURR_PATH/$ROOT_DIR/rockdev/Image* $CURR_PATH/rockdev/Image
    echo "[ADV] creating ${OTA_IMAGE_DIR}.tgz ..."
    tar czf ${OTA_IMAGE_DIR}.tgz $OTA_IMAGE_DIR
    generate_md5 ${OTA_IMAGE_DIR}.tgz
    #rm -rf $IMAGE_DIR
}

function create_update_images()
{
    cd $CURR_PATH
    SD_IMAGE_DIR="SD_AI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
    echo "[ADV] mkdir $SD_IMAGE_DIR"
    mkdir $SD_IMAGE_DIR

    cd $CURR_PATH/rockdev/
    ./mkupdate.sh
    # Copy image files to image directory

    cd $CURR_PATH
	cp -a $CURR_PATH/rockdev/update.img $SD_IMAGE_DIR

    echo "[ADV] creating ${SD_IMAGE_DIR}.tgz ..."
    tar czf ${SD_IMAGE_DIR}.tgz $SD_IMAGE_DIR
    generate_md5 ${SD_IMAGE_DIR}.tgz
    #rm -rf $IMAGE_DIR
}


function copy_image_to_storage()
{
    echo "[ADV] copy images to $OUTPUT_DIR"

    generate_csv ${IMAGE_DIR}.tgz
    mv ${IMAGE_DIR}.csv $OUTPUT_DIR
    mv -f ${IMAGE_DIR}.tgz $OUTPUT_DIR
    mv -f ${OTA_IMAGE_DIR}.tgz $OUTPUT_DIR
    mv -f ${SD_IMAGE_DIR}.tgz $OUTPUT_DIR
    mv -f *.md5 $OUTPUT_DIR

}
# ================
#  Main procedure 
# ================


if [ "$PRODUCT" == "$VER_PREFIX" ]; then
echo "[ADV] get android source code"
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
	build_android_images
	prepare_images
#-------------------------------------
    build_ota_images
    prepare_ota_images
#-------------------------------------
    create_update_images
#-------------------------------------
	copy_image_to_storage
	save_temp_log
done

fi
cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

