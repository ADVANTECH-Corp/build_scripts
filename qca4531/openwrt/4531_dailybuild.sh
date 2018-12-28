#!/bin/bash -ex

VER_PREFIX="4531"

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"

echo "[ADV] UBOOT_IMAGE_NAME = ${UBOOT_IMAGE_NAME}"
echo "[ADV] KERNEL_IMAGE_NAME = ${KERNEL_IMAGE_NAME}"
echo "[ADV] ROOTFS_IMAGE_NAME = ${ROOTFS_IMAGE_NAME}"

echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST = ${MACHINE_LIST}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"

CURR_PATH="$PWD"
ROOT_DIR="${VER_PREFIX}OB${RELEASE_VERSION}"_"$DATE"
STORAGE_PATH="$CURR_PATH/$STORED/$DATE"

# Make storage folder
if [ -e $STORAGE_PATH ] ; then
    echo "[ADV] $STORAGE_PATH had already been created"
else
    echo "[ADV] mkdir $STORAGE_PATH"
    mkdir -p $STORAGE_PATH
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

# ===============================
#  Functions [platform specific]
# ===============================
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

    HASH_BSP=$(cd $CURR_PATH/$ROOT_DIR && git rev-parse --short HEAD)
    HASH_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/qsdk/qca/src/linux-4.4 && git rev-parse --short HEAD)
    cd $CURR_PATH

    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Linux OpenWrt 4.4.60
Part Number,N/A
Author,
Date,${DATE}
Version,LI${RELEASE_VERSION}
Build Number,${BUILD_NUMBER}
TAG,
Tested Platform,${NEW_MACHINE}
MD5 Checksum,TGZ: ${MD5_SUM}
Image Size,${FILE_SIZE}B (${FILE_SIZE_BYTE} bytes)
Issue description, N/A
Function Addition,
openwrt, ${HASH_BSP}
linux-msm, ${HASH_KERNEL}
END_OF_CSV
}

function add_version()
{
    cd $CURR_PATH
    DAILYBUILD_VER="-${PROJECT_PREFIX}OI${RELEASE_VERSION}.${BUILD_NUMBER}"

    # Set U-boot version
    LINE_NUM=`grep -n "EXTRAVERSION =" $ROOT_DIR/$U_BOOT_PATH | cut -f1 -d:`
    sed -i "/EXTRAVERSION =/d" $ROOT_DIR/$U_BOOT_PATH
    sed -i "${LINE_NUM}iEXTRAVERSION = ${DAILYBUILD_VER}" $ROOT_DIR/$U_BOOT_PATH

    # Set Linux version
    if [ -e $ROOT_DIR/$KERNEL_PATH ] ; then
        rm $ROOT_DIR/$KERNEL_PATH
    fi
    echo "${DAILYBUILD_VER}" > $ROOT_DIR/$KERNEL_PATH
}

function build_images()
{
    add_version

    cd $CURR_PATH/$ROOT_DIR/qsdk

    make package/symlinks
    cp qca/configs/advantech/${NEW_MACHINE}.config .config
    make defconfig
    make V=s

    if [ "$?" -ne 0 ]; then
        echo "[ADV] Build failure! Check details in Jenkins console output."
        exit 1
    fi
}

function prepare_images()
{
    cd $CURR_PATH

    IMAGE_DIR="${PROJECT_PREFIX}OI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR

    # Copy image files to image directory
    DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/"

    echo "[ADV] copying images ..."
    mv $DEPLOY_IMAGE_PATH/$UBOOT_IMAGE_NAME $IMAGE_DIR
    mv $DEPLOY_IMAGE_PATH/$KERNEL_IMAGE_NAME $IMAGE_DIR
    mv $DEPLOY_IMAGE_PATH/$ROOTFS_IMAGE_NAME $IMAGE_DIR

    # Create tarball file
    echo "[ADV] creating ${IMAGE_DIR}.tgz ..."
    tar czf ${IMAGE_DIR}.tgz $IMAGE_DIR
    generate_md5 ${IMAGE_DIR}.tgz

    rm -rf $IMAGE_DIR
}

function copy_image_to_storage()
{
    echo "[ADV] copy images to $STORAGE_PATH"

    generate_csv ${IMAGE_DIR}.tgz
    mv ${IMAGE_DIR}.csv $STORAGE_PATH

    mv -f ${IMAGE_DIR}.tgz $STORAGE_PATH
    mv -f *.md5 $STORAGE_PATH
}

# ================
#  Main procedure
# ================
echo "[ADV] get source code"
git clone $BSP_URL $ROOT_DIR
cd $ROOT_DIR
git submodule init
git submodule update

echo "[ADV] build images"
for NEW_MACHINE in $MACHINE_LIST
do
    PROJECT_PREFIX=`expr $NEW_MACHINE : '.*-\(.*\)'`

    build_images
    prepare_images
    copy_image_to_storage
done

# Remove strange filepath
cd $CURR_PATH/$ROOT_DIR/qsdk/build_dir/host/findutils-4.4.2
while [ -e confdir3/ ]; do mv confdir3/ d/; cd d/; done

cd $CURR_PATH

echo "[ADV] build script done!"

