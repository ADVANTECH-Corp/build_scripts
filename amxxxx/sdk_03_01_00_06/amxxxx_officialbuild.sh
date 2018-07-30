#!/bin/bash

RELEASE_VERSION=$1
VER_PREFIX="amxx"

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

ROOT_DIR="${VER_PREFIX}LBV${RELEASE_VERSION}"_"$DATE"
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

VER_TAG="${VER_PREFIX}LBV"$1

echo "$Release_Note" > Release_Note
REALEASE_NOTE="Release_Note"

# ===========
#  Functions
# ===========
function do_repo_init()
{
    REPO_OPT="-u $BSP_URL"

    if [ ! -z "$BSP_BRANCH" ] ; then
        REPO_OPT="$REPO_OPT -b $BSP_BRANCH"
    fi
    if [ ! -z "$BSP_XML" ] ; then
        REPO_OPT="$REPO_OPT -m $BSP_XML"
    fi

    repo init $REPO_OPT
}

function get_source_code()
{
    echo "[ADV] get yocto source code"
    cd $ROOT_DIR

    do_repo_init

    EXISTED_VERSION=`find .repo/manifests -name ${VER_TAG}.xml`
    if [ -z "$EXISTED_VERSION" ] ; then
        echo "[ADV] This is a new VERSION"
    else
        echo "[ADV] $RELEASE_VERSION already exists!"
        rm -rf .repo
        BSP_BRANCH="refs/tags/$VER_TAG"
        BSP_XML="$VER_TAG.xml"
        do_repo_init
    fi

    repo sync

    cd $CURR_PATH
}

function generate_md5()
{
    FILENAME=$1

    if [ -e $FILENAME ]; then
        MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
        echo $MD5_SUM > $FILENAME.md5
    fi
}

function check_tag_and_checkout()
{
        FILE_PATH=$1

        if [ -d "$ROOT_DIR/$FILE_PATH" ];then
                cd $ROOT_DIR/$FILE_PATH
                META_TAG=`git tag | grep $VER_TAG`
                if [ "$META_TAG" != "" ]; then
                        echo "[ADV] meta-advantech has been tagged ,and check to this $VER_TAG version"
                        REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                        git checkout $VER_TAG
                        git tag --delete $VER_TAG
                        git push --delete $REMOTE_SERVER refs/tags/$VER_TAG
                else
                        echo "[ADV] meta-advantech isn't tagged ,nothing to do"
                fi
                cd $CURR_PATH
        else
                echo "[ADV] Directory $ROOT_DIR/$FILE_PATH doesn't exist"
                exit 1
        fi
}

function check_tag_and_replace()
{
        FILE_PATH=$1
        REMOTE_URL=$2
        REMOTE_BRANCH=$3

        HASH_ID=`git ls-remote $REMOTE_URL $VER_TAG | awk '{print $1}'`
        if [ "$HASH_ID" != "" ]; then
                echo "[ADV] $REMOTE_URL has been tagged ,ID is $HASH_ID"
        else
                HASH_ID=`git ls-remote $REMOTE_URL | grep refs/heads/$REMOTE_BRANCH | awk '{print $1}'`
                echo "[ADV] $REMOTE_URL isn't tagged ,get latest HASH_ID is $HASH_ID"
        fi
        sed -i "s/"\$\{AUTOREV\}"/$HASH_ID/g" $ROOT_DIR/$FILE_PATH
}

function add_version()
{
	echo "[ADV] add version"
	cd $CURR_PATH

	# Set U-boot version
	sed -i "/UBOOT_LOCALVERSION_append/d" $ROOT_DIR/$U_BOOT_PATH
	echo "UBOOT_LOCALVERSION_append = \"_$OFFICIAL_VER\"" >> $ROOT_DIR/$U_BOOT_PATH
	
	# Set Linux version
	sed -i "/KERNEL_LOCALVERSION_append/d" $ROOT_DIR/$KERNEL_PATH
	echo "KERNEL_LOCALVERSION_append = \"_$OFFICIAL_VER\"" >> $ROOT_DIR/$KERNEL_PATH
}

function remove_version()
{
        sed -i "/UBOOT_LOCALVERSION_append/d" $ROOT_DIR/$U_BOOT_PATH
        sed -i "/KERNEL_LOCALVERSION_append/d" $ROOT_DIR/$KERNEL_PATH
}

function auto_add_tag()
{
        FILE_PATH=$1
        DIR=`ls $FILE_PATH`
        if [ -d "$FILE_PATH/$DIR/git" ];then
                cd $FILE_PATH/$DIR/git
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
                echo "[ADV] Directory $FILE_PATH doesn't exist"
                exit 1
        fi
}

function create_branch_and_commit()
{
        FILE_PATH=$1

        if [ -d "$ROOT_DIR/$FILE_PATH" ];then
                cd $ROOT_DIR/$FILE_PATH
                echo "[ADV] create branch $VER_TAG"
                REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                git checkout -b $VER_TAG
                git add .
                git commit -m "[Official Release] $VER_TAG"
                git push $REMOTE_SERVER $VER_TAG
                cd $CURR_PATH
        else
                echo "[ADV] Directory $ROOT_DIR/$FILE_PATH doesn't exist"
                exit 1
        fi
}

function create_xml_and_commit()
{
        if [ -d "$ROOT_DIR/.repo/manifests" ];then
                echo "[ADV] Create XML file"
                cd $ROOT_DIR
                # add revision into xml
                repo manifest -o $VER_TAG.xml -r

                mv $VER_TAG.xml .repo/manifests
                cd .repo/manifests
		git checkout $BSP_BRANCH

                # push to github
                REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                git add $VER_TAG.xml
                git commit -m "[Official Release] ${VER_TAG}"
                git push
                git tag -a $VER_TAG -F $CURR_PATH/$REALEASE_NOTE
                git push $REMOTE_SERVER $VER_TAG
                cd $CURR_PATH
        else
                echo "[ADV] Directory $ROOT_DIR/.repo/manifests doesn't exist"
                exit 1
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
    LOG_DIR="${OFFICIAL_VER}"_"${CPU_TYPE}"_"$DATE"_log

    if [ "x" != "x$2" ]; then
        MACHINE=$OLD_MACHINE bitbake $1 -c $2 -f

    else
        MACHINE=$NEW_MACHINE bitbake $1
    fi

    # Remove build folder
    if [ "$?" -ne 0 ]; then
        echo "[ADV] Build failure! Check details in ${LOG_DIR}.tgz"
        save_temp_log
        #rm -rf $CURR_PATH/$ROOT_DIR
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

    IMAGE_DIR="${OFFICIAL_VER}"_"${CPU_TYPE}"_"$DATE"
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
}

function copy_image_to_storage()
{
    echo "[ADV] copy BSP to $OUTPUT_DIR"
    mv -f ${ROOT_DIR}.tgz $OUTPUT_DIR

    echo "[ADV] copy all images to $OUTPUT_DIR"
    echo "[ADV] copy ${IMAGE_DIR}_sdkimg.tgz to $OUTPUT_DIR"
    mv -f ${IMAGE_DIR}_sdkimg.tgz $OUTPUT_DIR

    echo "[ADV] copy ${IMAGE_DIR}_spl.tgz image to $OUTPUT_DIR"
    mv -f ${IMAGE_DIR}_spl.tgz $OUTPUT_DIR

    echo "[ADV] copy ${IMAGE_DIR}_zimage.tgz image to $OUTPUT_DIR"
    mv -f ${IMAGE_DIR}_zimage.tgz $OUTPUT_DIR

    echo "[ADV] copy ${IMAGE_DIR}_modules.tgz to $OUTPUT_DIR"
    mv -f ${IMAGE_DIR}_modules.tgz $OUTPUT_DIR

    echo "[ADV] copy all *.md5 images to $OUTPUT_DIR"
    mv -f *.md5 $OUTPUT_DIR
}

# ================
#  Main procedure 
# ================
echo "[ADV] get yocto source code"
mkdir $ROOT_DIR
get_source_code

if [ -z "$EXISTED_VERSION" ] ; then
    # Check meta-advantech tag exist or not, and checkout to tag version
    check_tag_and_checkout $META_ADVANTECH_PATH

    # Check tag exist or not, and replace bbappend file SRCREV
    check_tag_and_replace $U_BOOT_PATH $U_BOOT_URL $U_BOOT_BRANCH
    check_tag_and_replace $KERNEL_PATH $KERNEL_URL $KERNEL_BRANCH
fi

# BSP source code
echo "[ADV] tar $ROOT_DIR.tgz file"
cd $CURR_PATH
rm -r $ROOT_DIR/configs $ROOT_DIR/oe-layertool-setup.sh $ROOT_DIR/sample-files
cp -r $ROOT_DIR/.repo/manifests/configs $ROOT_DIR/configs
cp -r $ROOT_DIR/.repo/manifests/sample-files $ROOT_DIR/sample-files
cp $ROOT_DIR/.repo/manifests/oe-layertool-setup.sh $ROOT_DIR/oe-layertool-setup.sh
tar czf $ROOT_DIR.tgz $ROOT_DIR --exclude-vcs --exclude .repo
generate_md5 $ROOT_DIR.tgz

#Create build folder
echo "[ADV] Create build folder"
cd $ROOT_DIR
./oe-layertool-setup.sh

# Link downloads directory from backup
if [ -e $CURR_PATH/downloads ] ; then
    echo "[ADV] link downloads directory"
    ln -s $CURR_PATH/downloads downloads
fi

echo "[ADV] build images"
for NEW_MACHINE in $MACHINE_LIST
do
    CPU_TYPE=${NEW_MACHINE:0:6}

    typeset -u OFFICIAL_VER
    OFFICIAL_VER=${NEW_MACHINE:9}
    OFFICIAL_VER="${OFFICIAL_VER}LIV${RELEASE_VERSION}"

    add_version
    build_yocto_images
    prepare_images
    copy_image_to_storage
    save_temp_log
done

if [ -z "$EXISTED_VERSION" ] ; then
    cd $CURR_PATH
    remove_version

    # Commit and create meta-advantech branch
    create_branch_and_commit $META_ADVANTECH_PATH

    # Add git tag
    echo "[ADV] Add tag"
    auto_add_tag $ROOT_DIR/$BUILDALL_DIR/$BUILD_TMP_DIR/work/${NEW_MACHINE}-linux-gnueabi/u-boot-ti-staging
    auto_add_tag $ROOT_DIR/$BUILDALL_DIR/$BUILD_TMP_DIR/work/${NEW_MACHINE}-linux-gnueabi/linux-processor-sdk

    # Create manifests xml and commit
    create_xml_and_commit
fi

# Copy downloads to backup
if [ ! -e $CURR_PATH/downloads ] ; then
    echo "[ADV] backup 'downloads' directory"
    cp -a $CURR_PATH/$ROOT_DIR/downloads $CURR_PATH
fi

#cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

