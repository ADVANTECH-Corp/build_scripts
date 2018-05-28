#!/bin/bash

VER_PREFIX="410c"
TMP_DIR="tmp-rpb-glibc"

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] DEPLOY_IMAGE_NAME = ${DEPLOY_IMAGE_NAME}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST = ${MACHINE_LIST}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"

echo "[ADV] META_ADVANTECH_PATH = ${META_ADVANTECH_PATH}"
echo "[ADV] KERNEL_VERSION = ${KERNEL_VERSION}"
echo "[ADV] KERNEL_PATH = ${KERNEL_PATH}"
CURR_PATH="$PWD"
ROOT_DIR="${VER_PREFIX}LB${RELEASE_VERSION}"_"$DATE"
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

function save_temp_log()
{
    LOG_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR"
    cd $LOG_PATH

    echo "[ADV] mkdir $LOG_DIR"
    mkdir $LOG_DIR

    # Backup conf, run script & log file
    cp -a conf $LOG_DIR
    find $TMP_DIR/work -name "log.*_*" -o -name "run.*_*" | xargs -i cp -a --parents {} $LOG_DIR

    echo "[ADV] creating ${LOG_DIR}.tgz ..."
    tar czf $LOG_DIR.tgz $LOG_DIR
    generate_md5 $LOG_DIR.tgz

    mv -f $LOG_DIR.tgz $STORAGE_PATH
    mv -f $LOG_DIR.tgz.md5 $STORAGE_PATH

    # Remove all temp logs
    rm -rf $LOG_DIR
    find . -name "temp" | xargs rm -rf
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

    HASH_BSP=$(cd $CURR_PATH/$ROOT_DIR/.repo/manifests && git rev-parse --short HEAD)
    HASH_ADV=$(cd $CURR_PATH/$ROOT_DIR/layers/meta-advantech && git rev-parse --short HEAD)
    HASH_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/work-shared/$NEW_MACHINE/kernel-source && git rev-parse --short HEAD)
    cd $CURR_PATH

    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Linux ${KERNEL_VERSION}
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
oe-rpb-manifest, ${HASH_BSP}
meta-advantech, ${HASH_ADV}
linux-linaro-qcomlt, ${HASH_KERNEL}
END_OF_CSV
}

function add_version()
{
    cd $CURR_PATH
    # Set Linux version
    sed -i "/LOCALVERSION/d" $ROOT_DIR/$KERNEL_PATH
    echo "LOCALVERSION = \"-LI${RELEASE_VERSION}-${BUILD_NUMBER}\"" >> $ROOT_DIR/$KERNEL_PATH
}

function building()
{
    echo "[ADV] building $1 $2..."
    LOG_DIR="LI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"_log

    if [ "x" != "x$2" ]; then
        bitbake $1 -c $2 -f

    else
        bitbake $1
    fi

    if [ "$?" -ne 0 ]; then
        echo "[ADV] Build failure! Check details in ${LOG_DIR}.tgz"
        save_temp_log
        exit 1
    fi
}

function set_environment()
{
    echo "[ADV] set environment"

    # Accept EULA if/when needed
    ELUA_MACHINE=$(echo $NEW_MACHINE | sed 's/-//g')
    export EULA_${ELUA_MACHINE}=1

    # Link downloads directory from backup
    if [ -e $CURR_PATH/downloads ] ; then
        echo "[ADV] link downloads directory"
        ln -s $CURR_PATH/downloads downloads
    fi

    BUILDALL_DIR=build_"${NEW_MACHINE}"
    MACHINE=$NEW_MACHINE DISTRO=rpb source setup-environment $BUILDALL_DIR

    # Add job BUILD_NUMBER to output files names
    cat << EOF >> conf/auto.conf
IMAGE_NAME_append = "-${BUILD_NUMBER}"
KERNEL_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
MODULE_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
EOF

    # get build stats to make sure that we use sstate properly
    cat << EOF >> conf/auto.conf
INHERIT += "buildstats buildstats-summary"
EOF
}

function build_yocto_images()
{
    cd $CURR_PATH/$ROOT_DIR

    set_environment

    echo "[ADV] Build recovery image!"
    building initramfs-debug-image

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
    DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/deploy/images/${NEW_MACHINE}"

    # Boot image
    echo "[ADV] copying boot image ..."
    FILE_NAME=$(readlink $DEPLOY_IMAGE_PATH/boot-${NEW_MACHINE}.img)
    mv $DEPLOY_IMAGE_PATH/$FILE_NAME $IMAGE_DIR

    # Rootfs
    echo "[ADV] sparse rootfs image ..."
    FILE_NAME=$(readlink $DEPLOY_IMAGE_PATH/${DEPLOY_IMAGE_NAME}-${NEW_MACHINE}.ext4.gz)
    rootfs="$DEPLOY_IMAGE_PATH/$FILE_NAME"
    gunzip -k ${rootfs}
    sudo ext2simg -v ${rootfs%.gz} ${rootfs%.ext4.gz}.img
    rm -f ${rootfs%.gz}
    gzip -9 ${rootfs%.ext4.gz}.img

    mv ${rootfs%.ext4.gz}.img.gz $IMAGE_DIR

    # Recovery
    echo "[ADV] copying recovery image ..."
    FILE_NAME=$(readlink $DEPLOY_IMAGE_PATH/recovery.img)
    mv $DEPLOY_IMAGE_PATH/$FILE_NAME $IMAGE_DIR

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

echo "[ADV] build images"
for NEW_MACHINE in $MACHINE_LIST
do
    add_version

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
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

