#!/bin/bash

VER_PREFIX="amxxxx"

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BUILDALL_DIR = ${BUILDALL_DIR}"
echo "[ADV] DEPLOY_IMAGE_NAME = ${DEPLOY_IMAGE_NAME}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST = ${MACHINE_LIST}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"
echo "[ADV] BUILD_TMP_DIR = ${BUILD_TMP_DIR}"
echo "[ADV] SDK_IMAGE_NAME = ${SDK_IMAGE_NAME}"
echo "[ADV] FIRST_BUILD = ${FIRST_BUILD}"

CURR_PATH="$PWD"
ROOT_DIR="${VER_PREFIX}LB${RELEASE_VERSION}"_"$DATE"
OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"

echo "[ADV] CURR_PATH = ${CURR_PATH}"
echo "[ADV] ROOT_DIR = ${ROOT_DIR}"
echo "[ADV] OUTPUT_DIR = ${OUTPUT_DIR}"

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
    LOG_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR"
    echo "[ADV] LOG_PATH:$LOG_PATH"

    cd $LOG_PATH
    echo "[ADV] mkdir $LOG_DIR"
    mkdir $LOG_DIR

    # Backup conf, run script & log file
    cp -a conf $LOG_DIR
    find $BUILD_TMP_DIR/work -name "log.*_*" -o -name "run.*_*" | xargs -i cp -a --parents {} $LOG_DIR

    echo "[ADV] creating ${LOG_DIR}.tgz ..."
    tar czf $LOG_DIR.tgz $LOG_DIR
    generate_md5 $LOG_DIR.tgz

    mv -f $LOG_DIR.tgz $OUTPUT_DIR
    mv -f $LOG_DIR.tgz.md5 $OUTPUT_DIR

    # Remove all temp logs
    rm -rf $LOG_DIR
    find . -name "temp" | xargs rm -rf
}

function building()
{
    echo "[ADV] building $OLD_MACHINE $NEW_MACHINE $1 $2..."
    LOG_DIR="LI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"_log

    if [ "x" != "x$2" ]; then
        MACHINE=$OLD_MACHINE bitbake $1 -c $2 -f

    else
        MACHINE=$NEW_MACHINE bitbake $1
    fi

    # Remove build folder
    if [ "$?" -ne 0 ]; then
        echo "[ADV] Build failure! Check details in ${LOG_DIR}.tgz"
        save_temp_log
        rm -rf $CURR_PATH/$ROOT_DIR
        exit 1
    fi
}

function build_yocto_images()
{
    cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR

    echo "[ADV] current path:$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR"
    # set_environment
    echo "[ADV] change $NEW_MACHINE"
    . conf/setenv

    # Re-build U-Boot & kernel
    if [ "$FIRST_BUILD" = "1" ] ; then
        OLD_MACHINE=$NEW_MACHINE
        echo "[ADV] Fisrt build: OLD_MACHINE=$OLD_MACHINE"
        FIRST_BUILD="0"
    fi

    building u-boot-ti-staging cleansstate
    building u-boot-ti-staging

    building linux-processor-sdk cleansstate
    building linux-processor-sdk

    OLD_MACHINE=$NEW_MACHINE
    echo "[ADV] Replace OLD_MACHINE=$OLD_MACHINE"

    # Build full image
    building $DEPLOY_IMAGE_NAME
}

function prepare_images()
{
    cd $CURR_PATH

    IMAGE_DIR="LI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR

    # Copy image files to image directory
    DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$BUILD_TMP_DIR/deploy/images/${NEW_MACHINE}"
    echo "[ADV] DEPLOY_IMAGE_PATH=$DEPLOY_IMAGE_PATH"

    # processor-sdk-linux-image image - ex: processor-sdk-linux-image-am57xx-evm-20170407050848.tar.xz
    FILE_NAME=${SDK_IMAGE_NAME}"-"${NEW_MACHINE}"-*.tar.xz"

    echo "[ADV] SDK images:$FILE_NAME"
    echo "[ADV] creating ${IMAGE_DIR}_sdkimg.tgz for all SDK images..."
    
    mv $DEPLOY_IMAGE_PATH/$FILE_NAME $IMAGE_DIR
    tar czf ${IMAGE_DIR}_sdkimg.tgz $IMAGE_DIR

    generate_md5 ${IMAGE_DIR}_sdkimg.tgz
    rm -rf $IMAGE_DIR/$FILE_NAME

    # U-Boot & SPL & MLO
    echo "[ADV] creating ${IMAGE_DIR}_spl.tgz for u-boot & SPL & MLO images ..."
    mv $DEPLOY_IMAGE_PATH/u-boot* $IMAGE_DIR
    mv $DEPLOY_IMAGE_PATH/MLO* $IMAGE_DIR

    echo "List all U-Boot & SPL & MLO files in $IMAGE_DIR:"
    for entry in "$IMAGE_DIR"/* ; do
        echo $entry
    done

    tar czf ${IMAGE_DIR}_spl.tgz $IMAGE_DIR
    generate_md5 ${IMAGE_DIR}_spl.tgz
    rm -rf $IMAGE_DIR/*

    # dtb & zImage
    echo "[ADV] creating ${IMAGE_DIR}_zimage.tgz for dtb & zImage images ..."
    mv $DEPLOY_IMAGE_PATH/zImage* $IMAGE_DIR

    echo "List all dtb & zImage files in $IMAGE_DIR:"
    for entry in "$IMAGE_DIR"/* ; do
        echo $entry
    done

    tar czf ${IMAGE_DIR}_zimage.tgz $IMAGE_DIR
    generate_md5 ${IMAGE_DIR}_zimage.tgz
    rm -rf $IMAGE_DIR
}

function copy_image_to_storage()
{
    echo "[ADV] copy all images to $OUTPUT_DIR"
    echo "[ADV] copy ${IMAGE_DIR}_sdkimg.tgz to $OUTPUT_DIR"
    mv -f ${IMAGE_DIR}_sdkimg.tgz $OUTPUT_DIR

    echo "[ADV] copy ${IMAGE_DIR}_spl.tgz image to $OUTPUT_DIR"
    mv -f ${IMAGE_DIR}_spl.tgz $OUTPUT_DIR

    echo "[ADV] copy ${IMAGE_DIR}_zimage.tgz image to $OUTPUT_DIR"
    mv -f ${IMAGE_DIR}_zimage.tgz $OUTPUT_DIR

    echo "[ADV] copy all *.md5 images to $OUTPUT_DIR"
    mv -f *.md5 $OUTPUT_DIR
}

# ================
#  Main procedure 
# ================
echo "[ADV] get yocto source code"
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

#Create build folder
echo "[ADV] Create build folder"
./oe-layertool-setup.sh

# Link downloads directory from backup
if [ -e $CURR_PATH/downloads ] ; then
    echo "[ADV] link downloads directory"
    ln -s $CURR_PATH/downloads downloads
fi

echo "[ADV] build images"
for NEW_MACHINE in $MACHINE_LIST
do
    build_yocto_images
    prepare_images
    copy_image_to_storage
    save_temp_log
done

# Copy downloads to backup
if [ ! -e $CURR_PATH/downloads ] ; then
    echo "[ADV] backup 'downloads' directory"
    cp -a $CURR_PATH/$ROOT_DIR/downloads $CURR_PATH
fi

cd $CURR_PATH
rm -rf $ROOT_DIR

echo "[ADV] build script done!"

