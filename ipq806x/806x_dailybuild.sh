#!/bin/bash

VER_PREFIX="806x"

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BUILDALL_DIR = ${BUILDALL_DIR}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST = ${MACHINE_LIST}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"

CURR_PATH="$PWD"
ROOT_DIR="${VER_PREFIX}LB${RELEASE_VERSION}"_"$DATE"
OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"

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
    cd $LOG_PATH

    echo "[ADV] mkdir $LOG_DIR"
    mkdir $LOG_DIR

    # Backup conf, run script & log file
    #cp -a make.log $LOG_DIR

    echo "[ADV] creating ${LOG_DIR}.tgz ..."
    tar czf $LOG_DIR.tgz $LOG_DIR
    generate_md5 $LOG_DIR.tgz

    mv -f $LOG_DIR.tgz $OUTPUT_DIR
    mv -f $LOG_DIR.tgz.md5 $OUTPUT_DIR

    # Remove all temp logs
    rm -rf $LOG_DIR
}

function set_environment()
{
    echo "[ADV] set environment"
		export ARMGCC_DIR=`pwd`/qsdk/staging_dir/toolchain-arm_cortex-a7_gcc-4.8-linaro_uClibc-0.9.33.2_eabi/
		export TOOLCHAIN_DIR=`pwd`/qsdk/staging_dir/toolchain-arm_cortex-a7_gcc-4.8-linaro_uClibc-0.9.33.2_eabi/
		export STAGING_DIR=`pwd`/qsdk/staging_dir/
}

function build_yocto_images()
{
    cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR
    LOG_DIR="LI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"_log
    echo "[ADV] build_yocto_image"
		
    set_environment

    # Build full image
    make -j8 V=s
		
    if [ "$?" -ne 0 ]; then
        echo "[ADV] Build failure! Check details in Jenkins output"
        rm -rf $CURR_PATH/$ROOT_DIR
        exit 1
    fi
}

function prepare_images()
{
    cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR

		./arm_initial_pack.sh
		
    IMAGE_DIR="LI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR

    # Copy image files to image directory
    DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/WISE-3610/image"

    # Single image
    FILE_NAME="nand-ipq40xx-single.img"
    mv $DEPLOY_IMAGE_PATH/$FILE_NAME $IMAGE_DIR
    
    echo "[ADV] creating ${IMAGE_DIR}_single.img.gz ..."    
  	gzip -c9 $IMAGE_DIR/$FILE_NAME > ${IMAGE_DIR}_single.img.gz
    generate_md5 ${IMAGE_DIR}_single.img.gz
    rm $IMAGE_DIR/$FILE_NAME
    
		# Inital image
		FILE_NAME="nand-ipq40xx-initial.img"
		mv $DEPLOY_IMAGE_PATH/$FILE_NAME $IMAGE_DIR
    
    echo "[ADV] creating ${IMAGE_DIR}_initial.img.gz ..."
    gzip -c9 $IMAGE_DIR/$FILE_NAME > ${IMAGE_DIR}_initial.img.gz
    generate_md5 ${IMAGE_DIR}_initial.img.gz
    rm $IMAGE_DIR/$FILE_NAME
    
		# Rootfs image
		FILE_NAME="openwrt-ipq806x-ipq40xx-ubi-root.img"
		mv $DEPLOY_IMAGE_PATH/$FILE_NAME $IMAGE_DIR
		
    echo "[ADV] creating ${IMAGE_DIR}_root.img.gz ..."
    gzip -c9 $IMAGE_DIR/$FILE_NAME > ${IMAGE_DIR}_root.img.gz
    generate_md5 ${IMAGE_DIR}_root.img.gz
    rm $IMAGE_DIR/$FILE_NAME		
		
	  cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR
    
    rm -rf $IMAGE_DIR
}

function copy_image_to_storage()
{
    echo "[ADV] copy images to $OUTPUT_DIR"

    mv -f ${IMAGE_DIR}_single.img.gz $OUTPUT_DIR
    mv -f ${IMAGE_DIR}_initial.img.gz $OUTPUT_DIR
    mv -f ${IMAGE_DIR}_root.img.gz $OUTPUT_DIR
    mv -f *.md5 $OUTPUT_DIR
}

# ================
#  Main procedure 
# ================
echo "[ADV] get yocto source code"
mkdir $ROOT_DIR
cd $ROOT_DIR
if [ "$BSP_BRANCH" == "" ] ; then
	  git clone $BSP_URL
    
elif [ "$BSP_XML" == "" ] ; then
    git clone $BSP_URL -b $BSP_BRANCH
fi

# Link downloads directory from backup
#if [ -e $CURR_PATH/downloads ] ; then
#    echo "[ADV] link downloads directory"
#    ln -s $CURR_PATH/downloads downloads
#fi

echo "[ADV] build images"
for NEW_MACHINE in $MACHINE_LIST
do
    build_yocto_images
    prepare_images
    copy_image_to_storage
done

# Copy downloads to backup
#if [ ! -e $CURR_PATH/downloads ] ; then
#    echo "[ADV] backup 'downloads' directory"
#    cp -a $CURR_PATH/$ROOT_DIR/downloads $CURR_PATH
#fi

cd $CURR_PATH

echo "[ADV] build script done!"


