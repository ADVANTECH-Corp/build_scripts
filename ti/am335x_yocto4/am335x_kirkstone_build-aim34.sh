#!/bin/bash

MACHINE_PROJECT="$1"

#--- [platform specific] ---
VER_PREFIX="am335x"
#---------------------------
echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] DEPLOY_IMAGE_NAME = ${DEPLOY_IMAGE_NAME}"
echo "[ADV] BACKEND_TYPE = ${BACKEND_TYPE}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] BUILDALL_DIR = ${BUILDALL_DIR}"
echo "[ADV] OS_IMAGE_NAME = ${OS_IMAGE_NAME}"
echo "[ADV] U_BOOT_VERSION = ${U_BOOT_VERSION}"
echo "[ADV] U_BOOT_URL = ${U_BOOT_URL}"
echo "[ADV] U_BOOT_BRANCH = ${U_BOOT_BRANCH}"
echo "[ADV] U_BOOT_PATH = ${U_BOOT_PATH}"
echo "[ADV] META_ADVANTECH_PATH = ${META_ADVANTECH_PATH}"
echo "[ADV] META_ADVANTECH_BRANCH = ${META_ADVANTECH_BRANCH}"
echo "[ADV] KERNEL_VERSION = ${KERNEL_VERSION}"
echo "[ADV] KERNEL_URL = ${KERNEL_URL}"
echo "[ADV] KERNEL_BRANCH = ${KERNEL_BRANCH}"
echo "[ADV] KERNEL_PATH = ${KERNEL_PATH}"
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

function do_repo_init()
{
    echo -e "\n [ADV] Running ${FUNCNAME[0]} \n"
    REPO_OPT="-u $BSP_URL"

    if [ ! -z "$BSP_BRANCH" ] ; then
        REPO_OPT="$REPO_OPT -b $BSP_BRANCH"
    fi
    if [ ! -z "$BSP_XML" ] ; then
        REPO_OPT="$REPO_OPT -m $BSP_XML"
    fi

    repo init $REPO_OPT
    echo -e " [ADV] END ${FUNCNAME[0]} \n"
}

function get_source_code()
{
    echo -e "\n =====================\n [ADV] Start Running ${FUNCNAME[0]} \n"
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
    echo "building $DEPLOY_IMAGE_NAME"
    building $DEPLOY_IMAGE_NAME
    echo -e "\n =====================\n [ADV] END ${FUNCNAME[0]} \n"
}

function sdk_modify()
{
    echo -e "\n =====================\n [ADV] Start Running ${FUNCNAME[0]} \n"
    cd $CURR_PATH/$ROOT_DIR

# meta-arago
    echo -e "\n # meta-arago \n"
    sed -i "s/^do_image_wic/#do_image_wic/g" ./sources/meta-arago/meta-arago-distro/conf/distro/arago.conf
    sed -i "s/^IMAGE_BOOT_FILES/#IMAGE_BOOT_FILES/g" ./sources/meta-arago/meta-arago-distro/conf/distro/arago.conf
    cat sources/meta-arago/meta-arago-distro/conf/distro/arago.conf | grep IMAGE_BOOT_FILES 
    cat sources/meta-arago/meta-arago-distro/conf/distro/arago.conf | grep do_image_wic

# meta-processor-sdk
    echo -e "\n #  meta-processor-sdk \n"
    sed -i "s/protocol=git/branch=master;proctocol=https/g" ./sources/meta-processor-sdk/recipes-connectivity/wpantund/wpantund_git.bb
    cat ./sources/meta-processor-sdk/recipes-connectivity/wpantund/wpantund_git.bb | grep SRC_UR -A 3

# oe-core
    echo -e "\n # oe-core \n"
    sed -i "s/^DISTRO_FEATURES_BACKFILL_CONSIDERED/#DISTRO_FEATURES_BACKFILL_CONSIDERED/g" ./sources/oe-core/meta/conf/distro/include/init-manager-systemd.inc
    cat ./sources/oe-core/meta/conf/distro/include/init-manager-systemd.inc | grep DISTRO_FEATURES

    cd $CURR_PATH
    echo -e "\n =====================\n [ADV] END ${FUNCNAME[0]} \n"
}

function prepare_images()
{
    echo -e "\n =====================\n [ADV] Start Running ${FUNCNAME[0]} \n"
    cd $CURR_PATH

    IMAGE_DIR="LI${RELEASE_VERSION}"_"$MACHINE_PROJECT"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR

    # Copy image files to image directory
    DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/deploy-ti/images/${MACHINE_PROJECT}"
    SDK_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/deploy-ti/sdk"
    echo "[ADV] DEPLOY_IMAGE_PATH=$DEPLOY_IMAGE_PATH"

    # tisdk-core-bundle-am335xepcr3220a1-20240828094234.tar.xz   ,  tisdk-default-image-am335xepcr3220a1-20240828094234.rootfs.tar.xz
    FILE_NAME=${OS_IMAGE_NAME}"-"${MACHINE_PROJECT}"-*.tar.xz"

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
        echo "[ADV] creating ${IMAGE_DIR}_sdk.tgz for arago-2023.04-armv7a-linux-gnueabi-tisdk.sh"
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

################################
#                tag & version 
################################


function check_tag_and_checkout()
{
    echo -e "\n [ADV]  ${FUNCNAME[0]}"
    cd $CURR_PATH
	FILE_PATH=$1
	META_BRANCH=$2
	HASH_CSV=$3

        if [ -d "$ROOT_DIR/$FILE_PATH" ];then
                cd $ROOT_DIR/$FILE_PATH
                META_TAG=`git tag | grep $VER_TAG`
                if [ "$META_TAG" != "" ]; then
                        echo "[ADV] meta-advantech has been tagged ($VER_TAG). Nothing to do."
                else
                        echo "[ADV] checkout meta-advantech to $META_BRANCH"
                        git checkout $META_BRANCH
                        git pull --rebase
                fi
                cd $CURR_PATH
        else
                echo "[ADV] Directory $ROOT_DIR/$FILE_PATH doesn't exist"
                exit 1
        fi
}

function check_tag_and_replace()
{
    echo -e "\n [ADV]  ${FUNCNAME[0]}"
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
    sed -i "s/SRCREV = \"[^\"]*\"/SRCREV = \"$HASH_ID\"/"   $CURR_PATH/$ROOT_DIR/$FILE_PATH
}

function add_version()
{
	echo -e "\n [ADV]  ${FUNCNAME[0]}"
	cd $CURR_PATH

	# Set U-boot version
	sed -i "/UBOOT_LOCALVERSION:append/d" $ROOT_DIR/$U_BOOT_PATH
	echo "UBOOT_LOCALVERSION:append = \"_$OFFICIAL_VER\"" >> $ROOT_DIR/$U_BOOT_PATH
	
	# Set Linux version
	sed -i "/KERNEL_LOCALVERSION:append/d" $ROOT_DIR/$KERNEL_PATH
	typeset -l OFFICIAL_VER_lowercase
	OFFICIAL_VER_lowercase=$OFFICIAL_VER
	echo "KERNEL_LOCALVERSION:append = \"-$OFFICIAL_VER_lowercase\"" >> $ROOT_DIR/$KERNEL_PATH
}

function remove_version()
{
    echo -e "\n [ADV]  ${FUNCNAME[0]}"
    sed -i "/UBOOT_LOCALVERSION:append/d" $ROOT_DIR/$U_BOOT_PATH
    sed -i "/KERNEL_LOCALVERSION:append/d" $ROOT_DIR/$KERNEL_PATH
}

function auto_add_tag()
{
    echo -e "\n [ADV]  ${FUNCNAME[0]}"
        REMOTE_URL=$1
        META_BRANCH=$2
        cd $CURR_PATH

		# Get source
        git clone $REMOTE_URL
        SOURCE_DIR=${REMOTE_URL##*/}
        SOURCE_DIR=${SOURCE_DIR/.git}
        cd $SOURCE_DIR
        git checkout $META_BRANCH

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
}

function commit_tag_and_rollback()
{
    echo -e "\n [ADV]  ${FUNCNAME[0]}"
        FILE_PATH=$1
        cd $CURR_PATH

        if [ -d "$ROOT_DIR/$FILE_PATH" ];then
                cd $ROOT_DIR/$FILE_PATH
                META_TAG=`git tag | grep $VER_TAG`
                if [ "$META_TAG" != "" ]; then
                        echo "[ADV] meta-advantech has been tagged ($VER_TAG). Nothing to do."
                else
                        echo "[ADV] create tag $VER_TAG"
                        REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                        git add .
                        git commit -m "[Official Release] $VER_TAG"
						git push
                        git tag -a $VER_TAG -m "[Official Release] $VER_TAG"
						git push $REMOTE_SERVER $VER_TAG
                fi
                cd $CURR_PATH
        else
                echo "[ADV] Directory $ROOT_DIR/$FILE_PATH doesn't exist"
                exit 1
        fi
}

function create_branch_and_commit()
{
    echo -e "\n [ADV]  ${FUNCNAME[0]}"
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
    echo -e "\n [ADV]  ${FUNCNAME[0]}"
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


# ================
#  Main procedure
# ================

    mkdir $ROOT_DIR
    get_source_code

if [ -z "$EXISTED_VERSION" ] ; then
    # Check meta-advantech tag exist or not, and checkout to tag version
    check_tag_and_checkout $META_ADVANTECH_PATH $META_ADVANTECH_BRANCH $HASH_ADVANTECH

    # Check tag exist or not, and replace bbappend file SRCREV
    check_tag_and_replace $U_BOOT_PATH $U_BOOT_URL $U_BOOT_BRANCH
    check_tag_and_replace $KERNEL_PATH $KERNEL_URL $KERNEL_BRANCH
fi

#SDK souce code modify
    echo "[ADV] SDK souce code modify"
    sdk_modify

# add version
if [ $ALSO_BUILD_OFFICIAL_IMAGE == true ]
then
    typeset -u OFFICIAL_VER
    OFFICIAL_VER=${MACHINE_PROJECT:9}
    OFFICIAL_VER="${OFFICIAL_VER}${AIM_VERSION}LIV${RELEASE_VERSION}"
    add_version
fi

# BSP source code
    echo "[ADV] tar $ROOT_DIR.tgz file"
    cp -r $CURR_PATH/$ROOT_DIR  $STORAGE_PATH/ ; sync
    cd $STORAGE_PATH
    tar --exclude='vcs' --exclude='.repo' -czf $ROOT_DIR.tgz $ROOT_DIR 
    generate_md5 $ROOT_DIR.tgz
    rm -rf $ROOT_DIR ; sync

#Create build folder
    echo "[ADV] Create build folder"
    cd $CURR_PATH/$ROOT_DIR
    ./oe-layertool-setup.sh

# Link downloads directory from backup
if [ -e $CURR_PATH/downloads ] ; then
    echo "[ADV] link downloads directory"
    ln -s $CURR_PATH/downloads downloads
fi

echo "[ADV] build images"
    build_yocto_images
    prepare_images
    copy_image_to_storage
    save_temp_log

if [ $ALSO_BUILD_OFFICIAL_IMAGE == true ]
then
    if [ -z "$EXISTED_VERSION" ] ; then
        cd $CURR_PATH
        remove_version

        # Add git tag
        echo "[ADV] Add tag"
        commit_tag_and_rollback $META_ADVANTECH_PATH
        auto_add_tag  $U_BOOT_URL $U_BOOT_BRANCH
        auto_add_tag $KERNEL_URL $KERNEL_BRANCH

        # Create manifests xml and commit
        create_xml_and_commit
    fi
fi

echo -e "\n [ADV] build script done! \n"
