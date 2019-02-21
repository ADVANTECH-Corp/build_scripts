#!/bin/bash -ex

VER_PREFIX="4531"

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"

echo "[ADV] UBOOT_IMAGE_NAME = ${UBOOT_IMAGE_NAME}"
echo "[ADV] KERNEL_IMAGE_NAME = ${KERNEL_IMAGE_NAME}"
echo "[ADV] ROOTFS_IMAGE_NAME = ${ROOTFS_IMAGE_NAME}"

echo "[ADV] SDK_IMAGE_NAME = ${SDK_IMAGE_NAME}"
echo "[ADV] TOOLCHAIN_IMAGE_NAME = ${TOOLCHAIN_IMAGE_NAME}"

echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST = ${MACHINE_LIST}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"

CURR_PATH="$PWD"
VER_TAG="${VER_PREFIX}OB${RELEASE_VERSION}"
ROOT_DIR="${VER_TAG}"_"$DATE"
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

function auto_add_tag()
{
        FILE_PATH=$1

        if [ -d "$ROOT_DIR/$FILE_PATH" ];then
                cd $ROOT_DIR/$FILE_PATH
                HEAD_HASH_ID=`git rev-parse HEAD`
                TAG_HASH_ID=`git tag -v $VER_TAG | grep object | cut -d ' ' -f 2`
                if [ "$HEAD_HASH_ID" == "$TAG_HASH_ID" ]; then
                        echo "[ADV] tag exists! There is no need to add tag"
                else
                        echo "[ADV] Add tag $VER_TAG"
                        REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                        git tag -a $VER_TAG -m "[Official Release] $VER_TAG"
                        git push $REMOTE_SERVER $VER_TAG
                fi
                cd $CURR_PATH
        else
                echo "[ADV] Directory $ROOT_DIR/$FILE_PATH doesn't exist"
                exit 1
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
OS,Linux OpenWrt 4.4.16
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
    DAILYBUILD_VER="-${PROJECT_PREFIX}OI${RELEASE_VERSION}"

    # Set U-boot version
    U_BOOT_VER_FILE="${ROOT_DIR}/${U_BOOT_PATH}/Makefile"
    LINE_NUM=`grep -n "EXTRAVERSION =" $U_BOOT_VER_FILE | cut -f1 -d:`
    sed -i "/EXTRAVERSION =/d" $U_BOOT_VER_FILE
    sed -i "${LINE_NUM}iEXTRAVERSION = ${DAILYBUILD_VER}" $U_BOOT_VER_FILE

    # Set Linux version
    KERNEL_VER_FILE="${ROOT_DIR}/${KERNEL_PATH}/localversion"
    if [ -e $KERNEL_VER_FILE ] ; then
        rm $KERNEL_VER_FILE
    fi
    echo "${DAILYBUILD_VER}" > $KERNEL_VER_FILE
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

    IMAGE_TYPE=$1
    OUTPUT_DIR=$2
    if [ "$OUTPUT_DIR" == "" ]; then
        echo "[ADV] prepare_images: invalid parameter #2!"
        exit 1;
    else
        echo "[ADV] mkdir $OUTPUT_DIR"
        mkdir $OUTPUT_DIR
    fi

    DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/"

    case $IMAGE_TYPE in
    "sdk")
        echo "[ADV] copying SDK & toolchain ..."
        mv $DEPLOY_IMAGE_PATH/$SDK_IMAGE_NAME $OUTPUT_DIR
        mv $DEPLOY_IMAGE_PATH/$TOOLCHAIN_IMAGE_NAME $OUTPUT_DIR
        ;;
    "normal")
        echo "[ADV] copying images ..."
        mv $DEPLOY_IMAGE_PATH/$UBOOT_IMAGE_NAME $OUTPUT_DIR
        mv $DEPLOY_IMAGE_PATH/$KERNEL_IMAGE_NAME $OUTPUT_DIR
        mv $DEPLOY_IMAGE_PATH/$ROOTFS_IMAGE_NAME $OUTPUT_DIR
        ;;
    *)
        echo "[ADV] prepare_images: invalid parameter #1!"
        exit 1;
        ;;
    esac

    # Create tarball file
    echo "[ADV] creating ${OUTPUT_DIR}.tgz ..."
    tar czf ${OUTPUT_DIR}.tgz $OUTPUT_DIR
    generate_md5 ${OUTPUT_DIR}.tgz

    rm -rf $OUTPUT_DIR
}

function copy_image_to_storage()
{
    echo "[ADV] copy images to $STORAGE_PATH"

    case $1 in
    "sdk")
        mv -f ${ROOT_DIR}.tgz $STORAGE_PATH
        mv -f ${SDK_DIR}.tgz $STORAGE_PATH
        ;;
    "normal")
        generate_csv ${IMAGE_DIR}.tgz
        mv ${IMAGE_DIR}.csv $STORAGE_PATH
        mv -f ${IMAGE_DIR}.tgz $STORAGE_PATH
        ;;
    *)
        echo "[ADV] copy_image_to_storage: invalid parameter #1!"
        exit 1;
        ;;
    esac

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

cd ..
echo "[ADV] tar $ROOT_DIR.tgz file"
tar czf $ROOT_DIR.tgz $ROOT_DIR --exclude-vcs
generate_md5 $ROOT_DIR.tgz

# Link downloads directory from backup
if [ -e $CURR_PATH/dl ] ; then
    echo "[ADV] link downloads directory"
    rm -rf $ROOT_DIR/qsdk/dl
    ln -s $CURR_PATH/dl $ROOT_DIR/qsdk/dl
fi

echo "[ADV] build images"
for NEW_MACHINE in $MACHINE_LIST
do
    PROJECT_PREFIX=`expr $NEW_MACHINE : '.*-\(.*\)'`

    build_images

    IMAGE_DIR="${PROJECT_PREFIX}OI${RELEASE_VERSION}"_"$DATE"
    prepare_images normal $IMAGE_DIR
    copy_image_to_storage normal
done

SDK_DIR="$ROOT_DIR"_sdk
prepare_images sdk $SDK_DIR
copy_image_to_storage sdk

echo "[ADV] add git tag"
auto_add_tag /
auto_add_tag $KERNEL_PATH

# Copy downloads to backup
if [ ! -e $CURR_PATH/dl ] ; then
    echo "[ADV] backup downloads directory"
    cp -a $CURR_PATH/$ROOT_DIR/qsdk/dl $CURR_PATH
fi

# Remove strange filepath
cd $CURR_PATH/$ROOT_DIR/qsdk/build_dir/host/findutils-4.4.2
while [ -e confdir3/ ]; do mv confdir3/ d/; cd d/; done

cd $CURR_PATH

echo "[ADV] build script done!"

