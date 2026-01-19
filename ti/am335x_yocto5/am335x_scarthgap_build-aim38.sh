#!/bin/bash

MACHINE_PROJECT="$1"

#--- [platform specific] ---
VER_PREFIX="am335x"
#---------------------------
echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] BUILDALL_DIR = ${BUILDALL_DIR}"
echo "[ADV] OS_IMAGE_NAME = ${OS_IMAGE_NAME}"
echo "[ADV] AIM_VERSION = ${AIM_VERSION}"

VER_TAG="${VER_PREFIX}LBV${RELEASE_VERSION}"

CURR_PATH="$PWD"
ROOT_DIR="${VER_TAG}"_"$DATE"_tisdk
STORAGE_PATH="$CURR_PATH/$STORED/$DATE"

echo "$Release_Note" > Release_Note
REALEASE_NOTE="Release_Note"

# Make storage folder
if [ -e $STORAGE_PATH ] ; then
	echo "[ADV] $STORAGE_PATH had already been created"
else
	echo "[ADV] mkdir $STORAGE_PATH"
	mkdir -p $STORAGE_PATH
fi

# Make mnt folder
MOUNT_POINT="$CURR_PATH/mnt"
if [ -e $MOUNT_POINT ]; then
	echo "[ADV] $MOUNT_POINT had already been created"
else
	echo "[ADV] mkdir $MOUNT_POINT"
	mkdir $MOUNT_POINT
fi

################################
#                function 
################################
function generate_md5()
{
    echo -e "\n [ADV] Running ${FUNCNAME[0]} \n"
    FILENAME=$1

    if [ -e $FILENAME ]; then
        MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
        echo $MD5_SUM > $FILENAME.md5
    fi
}

function get_source_code()
{
    echo -e "\n =====================\n [ADV] Start Running ${FUNCNAME[0]} \n"
    cd $CURR_PATH
    git clone https://AIM-Linux@dev.azure.com/AIM-Linux/RISC-TI-Linux/_git/adv-ti-yocto-bsp -b $BSP_BRANCH $ROOT_DIR
    
    echo -e "\n =====================\n [ADV] END ${FUNCNAME[0]} \n"
}

function save_temp_log()
{
    echo -e "\n [ADV] Running ${FUNCNAME[0]} \n"
    LOG_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR"
    echo "[ADV] LOG_PATH:$LOG_PATH"
    cd $LOG_PATH

    echo "[ADV] mkdir $LOG_DIR"
    mkdir $LOG_DIR

    # Backup conf, run script & log file
    cp -a conf $LOG_DIR
    # find $LOG_PATH/arago-tmp*/work -name "log.*_*" -o -name "run.*_*" | xargs -i cp -a --parents {} $LOG_DIR
    find $LOG_PATH/arago-tmp*/work \( -name "log.*_*" -o -name "run.*_*" \) -exec cp -a --parents {} $LOG_DIR \;

    sync

    echo "[ADV] creating ${LOG_DIR}.tgz ..."
    tar czf $LOG_DIR.tgz $LOG_DIR
    sync
    generate_md5 $LOG_DIR.tgz

    mv -f $LOG_DIR.tgz $STORAGE_PATH
    mv -f $LOG_DIR.tgz.md5 $STORAGE_PATH

    # Remove all temp logs
    rm -rf $LOG_DIR
    find . -name "temp" | xargs rm -rf
    sync
}

function building()
{
    echo "[ADV] building $OLD_MACHINE $NEW_MACHINE $1 $2..."
    LOG_DIR="LIV${RELEASE_VERSION}"_"$MACHINE_PROJECT"_"$DATE"_log

    if [ "x" != "x$2" ]; then
    echo "MACHINE=$MACHINE_PROJECT bitbake $1 -c $2 -f"
    MACHINE=$MACHINE_PROJECT bitbake $1 -c $2 -f

    else
    echo "MACHINE=$MACHINE_PROJECT bitbake $1"
    MACHINE=$MACHINE_PROJECT bitbake $1
    fi

    sync

    # Remove build folder
    if [ "$?" -ne 0 ]; then
        echo "[ADV] Build failure! Check details in ${LOG_DIR}.tgz"
        save_temp_log
        exit 1
    fi
}

function build_yocto_images()
{
    echo -e "\n =====================\n [ADV] Start Running ${FUNCNAME[0]} \n"
    cd $CURR_PATH/$ROOT_DIR
    ./oe-layertool-setup.sh -f configs/processor-sdk/processor-sdk-scarthgap-11.02.05.02-config.txt

    cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR
    echo "[ADV] current path:$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR"
    # set_environment
    echo "[ADV] MACHINE $MACHINE_PROJECT"
    . conf/setenv

    building u-boot-ti-staging cleansstate
    building u-boot-ti-staging

    building linux-ti-staging cleansstate
    building linux-ti-staging

    # Build full image
    echo "building tisdk-default-image"
    building tisdk-default-image
    echo "building tisdk-thinlinux-image"
    building tisdk-thinlinux-image
    echo -e "\n =====================\n [ADV] END ${FUNCNAME[0]} \n"
}

function prepare_images()
{
    echo -e "\n =====================\n [ADV] Start Running ${FUNCNAME[0]} \n"
    cd $CURR_PATH

    IMAGE_DIR="LIV${RELEASE_VERSION}"_"$MACHINE_PROJECT"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR

    # Copy image files to image directory
    DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/deploy-ti/images/${MACHINE_PROJECT}"
    SDK_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/deploy-ti/sdk"
    echo "[ADV] DEPLOY_IMAGE_PATH=$DEPLOY_IMAGE_PATH"

    # tisdk-core-bundle-am335xepcr3220a1-yyyyMMddhhmmss.tar.xz   ,  tisdk-default-image-am335xepcr3220a1-yyyyMMddhhmmss.rootfs.tar.xz
    FILE_NAME=${OS_IMAGE_NAME}"-"${MACHINE_PROJECT}".rootfs-*.*"

    echo "[ADV] OS images:$FILE_NAME"
    echo "[ADV] creating ${IMAGE_DIR}_OS_img.tgz for all OS images..."

    mv $DEPLOY_IMAGE_PATH/$FILE_NAME $IMAGE_DIR
    tar czf ${IMAGE_DIR}_OS_img.tgz $IMAGE_DIR

    generate_md5 ${IMAGE_DIR}_OS_img.tgz
    rm -rf $IMAGE_DIR/$FILE_NAME

    # U-Boot & SPL & MLO
    echo "[ADV] creating ${IMAGE_DIR}_spl.tgz for u-boot & SPL & MLO images ..."
    mv $DEPLOY_IMAGE_PATH/u-boot* $IMAGE_DIR
    mv $DEPLOY_IMAGE_PATH/MLO* $IMAGE_DIR
    mv $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/arago-tmp-default-glibc/work/${MACHINE_PROJECT}-oe-linux-gnueabi/u-boot-ti-staging/2025.01+git/build/MLO.* $IMAGE_DIR

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
    mv $DEPLOY_IMAGE_PATH/*.dtb $IMAGE_DIR

    echo "List all dtb & zImage files in $IMAGE_DIR:"
    for entry in "$IMAGE_DIR"/* ; do
        echo $entry
    done

    tar czf ${IMAGE_DIR}_zimage.tgz $IMAGE_DIR
    generate_md5 ${IMAGE_DIR}_zimage.tgz
    rm -rf $IMAGE_DIR/*

    # modules
    echo "[ADV] creating ${IMAGE_DIR}_modules.tgz for kernel modules ..."
    mv $DEPLOY_IMAGE_PATH/modules* $IMAGE_DIR

    echo "List all module files in $IMAGE_DIR:"
    for entry in "$IMAGE_DIR"/* ; do
        echo $entry
    done

    tar czf ${IMAGE_DIR}_modules.tgz $IMAGE_DIR
    generate_md5 ${IMAGE_DIR}_modules.tgz
    rm -rf $IMAGE_DIR

    # SDK
    [  -d "$SDK_PATH" ] && echo "$SDK_PATH"
    if [  -d "$SDK_PATH" ]
    then
        echo "[ADV] creating ${IMAGE_DIR}_sdk.tgz"
        cp -a $SDK_PATH $IMAGE_DIR
    sync
        tar czf ${IMAGE_DIR}_sdk.tgz $IMAGE_DIR
        generate_md5 ${IMAGE_DIR}_sdk.tgz
        rm -rf $IMAGE_DIR/*
    fi
    sync
    echo -e "\n =====================\n [ADV] END ${FUNCNAME[0]} \n"
}

function copy_image_to_storage()
{
    echo -e "\n =====================\n [ADV] Start Running ${FUNCNAME[0]} \n"
    echo "[ADV] copy all images to $STORAGE_PATH"

    echo "[ADV] copy ${IMAGE_DIR}_OS_img.tgz to $STORAGE_PATH"
    mv -f ${IMAGE_DIR}_OS_img.tgz $STORAGE_PATH

    echo "[ADV] copy ${IMAGE_DIR}_spl.tgz image to $STORAGE_PATH"
    mv -f ${IMAGE_DIR}_spl.tgz $STORAGE_PATH

    echo "[ADV] copy ${IMAGE_DIR}_zimage.tgz image to $STORAGE_PATH"
    mv -f ${IMAGE_DIR}_zimage.tgz $STORAGE_PATH

    echo "[ADV] copy ${IMAGE_DIR}_sdk.tgz to $STORAGE_PATH"
    mv -f ${IMAGE_DIR}_sdk.tgz $STORAGE_PATH

    echo "[ADV] copy ${IMAGE_DIR}_modules.tgz to $STORAGE_PATH"
    mv -f ${IMAGE_DIR}_modules.tgz $STORAGE_PATH

    echo "[ADV] copy all *.md5 images to $STORAGE_PATH"
    mv -f *.md5 $STORAGE_PATH

    sync
    echo -e "\n =====================\n [ADV] END ${FUNCNAME[0]} \n"
}

# ================
#  Main procedure
# ================
    get_source_code

echo "[ADV] build images"
    build_yocto_images
    prepare_images
    copy_image_to_storage
    save_temp_log

echo -e "\n [ADV] build script done! \n"
