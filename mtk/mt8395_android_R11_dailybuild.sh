#!/bin/bash

PRODUCT=$1
VER_PREFIX="mtk"

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST= ${MACHINE_LIST}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"
echo "[ADV] KERNEL_CONFIG = ${KERNEL_CONFIG}"
echo "[ADV] KERNEL_DTB = ${KERNEL_DTB}"
echo "[ADV] LUNCH_COMBO = ${LUNCH_COMBO}"
echo "[ADV] MODEL_NAME = ${MODEL_NAME}"
echo "[ADV] BOARD_VER = ${BOARD_VER}"
echo "[ADV] BSP_TARBALL = ${BSP_TARBALL}"

CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${RELEASE_VERSION}_${DATE}/android-bsp"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
IMAGE_VER="${MODEL_NAME}${BOARD_VER}${AIM_VERSION}AIV${RELEASE_VERSION}_$DATE"

# Make storage folder
if [ -e $OUTPUT_DIR ]; then
    echo "[ADV] $OUTPUT_DIR had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR"
    mkdir -p $OUTPUT_DIR
fi

# ===========
#  Functions
# ===========
function decompress_bsp()
{
    cd $CURR_PATH/${PLATFORM_PREFIX}_${RELEASE_VERSION}_${DATE}

    if [ "$BSP_TARBALL" == "" ] ; then
        echo "[ADV] BSP_TARBALL is null"
    else
        tar -zxvf ${BSP_TARBALL}
    fi
}

function get_source_code()
{
    cd $CURR_PATH/$ROOT_DIR

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

    HASH_ANDROID_BSP=$(cd $CURR_PATH/$ROOT_DIR/.repo/manifests && git rev-parse --short HEAD)
    HASH_ANDROID_PRELOADER=$(cd $CURR_PATH/$ROOT_DIR/vendor/mediatek/proprietary/bootable/bootloader/preloader && git rev-parse --short HEAD)
    HASH_ANDROID_LK=$(cd $CURR_PATH/$ROOT_DIR/vendor/mediatek/proprietary/bootable/bootloader/lk && git rev-parse --short HEAD)
    HASH_ANDROID_DEVICE=$(cd $CURR_PATH/$ROOT_DIR/device && git rev-parse --short HEAD)
    HASH_ANDROID_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/kernel-4.19 && git rev-parse --short HEAD)
    cd $CURR_PATH


    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Android 11
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

ANDROID_BSP, ${HASH_ANDROID_BSP}
ANDROID_PRELOADER, ${HASH_ANDROID_PRELOADER}
ANDROID_LK, ${HASH_ANDROID_LK}
ANDROID_DEVICE, ${HASH_ANDROID_DEVICE}
ANDROID_KERNEL, ${HASH_ANDROID_KERNEL}

END_OF_CSV
}

function save_temp_log()
{
    LOG_PATH="$CURR_PATH/$ROOT_DIR"
    cd $LOG_PATH

    LOG_DIR=${IMAGE_VER}_log
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

    if [ "$1" == "kernel" ]; then
	echo "[ADV] build kernel  = $KERNEL_CONFIG"
        cd $CURR_PATH/$ROOT_DIR/kernel-4.19
        make distclean
        make ARCH=arm64 $KERNEL_CONFIG
        make ARCH=arm64 $KERNEL_DTB >> $CURR_PATH/$ROOT_DIR/$LOG_FILE
    elif [ "$1" == "android" ]; then
        echo "[ADV] build android"
        cd $CURR_PATH/$ROOT_DIR
        source build/envsetup.sh
        lunch $LUNCH_COMBO
        make clean
        make 2>&1 | tee $CURR_PATH/$ROOT_DIR/$LOG2_FILE
    else
        echo "[ADV] pass building..."
    fi

    [ "$?" -ne 0 ] && echo "[ADV] Build failure! Check log file '$LOG_FILE' or '$LOG_FILE2'" && exit 1
}

function build_android_images()
{
    # Android 
    building android
}

function prepare_images()
{
    cd $CURR_PATH

    IMAGE_DIR=$IMAGE_VER
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR

    # Copy image files to image directory
    cp $CURR_PATH/$ROOT_DIR/out/target/product/aiot8395p1_64_bsp/* $IMAGE_DIR

    echo "[ADV] creating ${IMAGE_DIR}.tgz ..."
    tar czf ${IMAGE_DIR}.tgz $IMAGE_DIR
    generate_md5 ${IMAGE_DIR}.tgz
}

function copy_image_to_storage()
{
    echo "[ADV] copy images to $OUTPUT_DIR"
    IMAGE_DIR=$IMAGE_VER

    generate_csv ${IMAGE_DIR}.tgz
    mv ${IMAGE_DIR}.csv $OUTPUT_DIR
    mv -f ${IMAGE_DIR}.tgz $OUTPUT_DIR
    mv -f *.md5 $OUTPUT_DIR
}

# ================
#  Main procedure 
# ================

if [ "$PRODUCT" == "$VER_PREFIX" ]; then
    echo "[ADV] get android source code"

    decompress_bsp
    get_source_code

else #"$PRODUCT" != "$VER_PREFIX"
    echo "[ADV] build images"

    for NEW_MACHINE in $MACHINE_LIST
    do
        echo "[ADV] NEW_MACHINE = $NEW_MACHINE"
	build_android_images
	prepare_images
	copy_image_to_storage
	save_temp_log
    done

fi

echo "[ADV] build script done!"