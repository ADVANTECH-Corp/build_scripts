#!/bin/bash

PRODUCT=$1
OFFICIAL_VER=$2

#--- [platform specific] ---
VER_PREFIX="410c"
TMP_DIR="tmp-rpb-glibc"
DEFAULT_DEVICE="rsb-4760"
NEW_MACHINE=${PRODUCT}
#---------------------------

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] DEPLOY_IMAGE_NAME = ${DEPLOY_IMAGE_NAME}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"

echo "[ADV] META_ADVANTECH_PATH = ${META_ADVANTECH_PATH}"
echo "[ADV] KERNEL_VERSION = ${KERNEL_VERSION}"
echo "[ADV] KERNEL_URL = ${KERNEL_URL}"
echo "[ADV] KERNEL_BRANCH = ${KERNEL_BRANCH}"
echo "[ADV] KERNEL_PATH = ${KERNEL_PATH}"

VER_TAG="${VER_PREFIX}LB"$(echo $RELEASE_VERSION | sed 's/[.]//')

CURR_PATH="$PWD"
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
function get_source_code()
{
    echo "[ADV] get yocto source code"
    cd $ROOT_DIR

    if [ "$BSP_BRANCH" == "" ] ; then
        repo init -u $BSP_URL
    elif [ "$BSP_XML" == "" ] ; then
        repo init -u $BSP_URL -b $BSP_BRANCH
    else
        repo init -u $BSP_URL -b $BSP_BRANCH -m $BSP_XML
    fi
    repo sync

    cd $CURR_PATH
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

function update_revision_for_xml()
{
        FILE_PATH=$1
        PROJECT_LIST=`grep "path=" $FILE_PATH`
        XML_PATH="$PWD"

        # Delete old revision
        for PROJECT in $PROJECT_LIST
        do
                REV=`expr ${PROJECT} : 'revision="\([a-zA-Z0-9_.]*\)"'`
                if [ "$REV" != "" ]; then
                        echo "[ADV] delete revision : $REV"
                        sed -i "s/ revision=\"${REV}\"//g" $FILE_PATH
                fi
        done

        # Add new revision
        for PROJECT in $PROJECT_LIST
        do
                LAYER=`expr ${PROJECT} : 'path="\([a-zA-Z0-9/-]*\)"'`
                if [ "$LAYER" != "" ]; then
                        echo "[ADV] add revision for $LAYER"
                        cd ../../$LAYER
                        HASH_ID=`git rev-parse HEAD`
                        cd $XML_PATH
                        sed -i "s:path=\"${LAYER}\":path=\"${LAYER}\" revision=\"${HASH_ID}\":g" $FILE_PATH
                fi
        done
}

function create_xml_and_commit()
{
        if [ -d "$ROOT_DIR/.repo/manifests" ];then
                echo "[ADV] Create XML file"
                cd $ROOT_DIR/.repo
                cp manifest.xml manifests/$VER_TAG.xml
                cd manifests
                git checkout $BSP_BRANCH

                # add revision into xml
                update_revision_for_xml $VER_TAG.xml

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
Version,${OFFICIAL_VER}
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
    # Set Linux version
    sed -i "/LOCALVERSION/d" $ROOT_DIR/$KERNEL_PATH
    echo "LOCALVERSION = \"-$OFFICIAL_VER\"" >> $ROOT_DIR/$KERNEL_PATH
}

function building()
{
    echo "[ADV] building $1 $2..."
    LOG_DIR="$OFFICIAL_VER"_"$DATE"_log

    if [ "$1" == "populate_sdk" ]; then
        echo "[ADV] bitbake $DEPLOY_IMAGE_NAME -c populate_sdk"
        bitbake $DEPLOY_IMAGE_NAME -c populate_sdk

    elif [ "x" != "x$2" ]; then
        bitbake $1 -c $2 -f

    else
        bitbake $1
    fi

    [ "$?" -ne 0 ] && echo "[ADV] Build failure! Check details in ${LOG_DIR}.tgz" && save_temp_log && exit 1
    #rm -rf $CURR_PATH/$ROOT_DIR
}

function set_environment()
{
    cd $CURR_PATH/$ROOT_DIR
    echo "[ADV] set environment"

    if [ "$1" == "sdk" ]; then
        # Link downloads directory from backup
        if [ -e $CURR_PATH/downloads ] ; then
            echo "[ADV] link downloads directory"
            ln -s $CURR_PATH/downloads downloads
        fi
        # Use default device for sdk
        NEW_MACHINE=$DEFAULT_DEVICE
    fi

    # Accept EULA if/when needed
    ELUA_MACHINE=$(echo $NEW_MACHINE | sed 's/-//g')
    export EULA_${ELUA_MACHINE}=1

    BUILDALL_DIR=build_"${PRODUCT}"
    MACHINE=$NEW_MACHINE DISTRO=rpb source setup-environment $BUILDALL_DIR

    KERNEL_SOURCE_DIR="$BUILDALL_DIR/$TMP_DIR/work-shared/$NEW_MACHINE/kernel-source"

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

function build_yocto_sdk()
{
    set_environment sdk

    # Build kernel image first
    building linux-linaro-qcomlt

    # Generate sdk image
    building populate_sdk
}

function build_yocto_images()
{
    set_environment

    # Build full image
    building $DEPLOY_IMAGE_NAME
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

    case $IMAGE_TYPE in
    "sdk")
        cp $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/deploy/sdk/* $OUTPUT_DIR
        ;;
    "normal")
        # Boot image
        echo "[ADV] copying boot image ..."
        FILE_NAME="boot-Image--4.4*.img"
        mv $DEPLOY_IMAGE_PATH/$FILE_NAME $OUTPUT_DIR

        # Rootfs
        echo "[ADV] sparse rootfs image ..."
        for rootfs in ${DEPLOY_IMAGE_PATH}/*.rootfs.ext4.gz; do
            gunzip -k ${rootfs}
            sudo ext2simg -v ${rootfs%.gz} ${rootfs%.ext4.gz}.img
            rm -f ${rootfs%.gz}
            gzip -9 ${rootfs%.ext4.gz}.img

            mv ${rootfs%.ext4.gz}.img.gz $OUTPUT_DIR
        done
        ;;
    "installsd")
        # [To-Do]
        ;;
    *)
        echo "[ADV] prepare_images: invalid parameter #1!"
        exit 1;
        ;;
    esac

    # Package image file
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
    "installsd")
        mv -f ${INSTALL_DIR}.tgz $STORAGE_PATH
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
if [ "$PRODUCT" == "$VER_PREFIX" ]; then
    mkdir $ROOT_DIR
    get_source_code

    # Check meta-advantech tag exist or not, and checkout to tag version
    check_tag_and_checkout $META_ADVANTECH_PATH

    # Check tag exist or not, and replace bbappend file SRCREV
    check_tag_and_replace $KERNEL_PATH $KERNEL_URL $KERNEL_BRANCH

    # BSP source code
    echo "[ADV] tar $ROOT_DIR.tgz file"
    tar czf $ROOT_DIR.tgz $ROOT_DIR --exclude-vcs --exclude .repo
    generate_md5 $ROOT_DIR.tgz

    # Build Yocto SDK
    echo "[ADV] build yocto sdk"
    build_yocto_sdk

    echo "[ADV] generate sdk image"
    SDK_DIR="$ROOT_DIR"_sdk
    prepare_images sdk $SDK_DIR
    copy_image_to_storage sdk

    # Commit and create meta-advantech branch
    create_branch_and_commit $META_ADVANTECH_PATH

    # Add git tag
    auto_add_tag $KERNEL_SOURCE_DIR $KERNEL_URL

    # Create manifests xml and commit
    create_xml_and_commit

    # Remove pre-built image
    rm $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/deploy/images/$DEFAULT_DEVICE/*

else #"$PRODUCT" != "$VER_PREFIX"
    if [ ! -e $ROOT_DIR ]; then
        echo -e "No BSP is found!\nStop building." && exit 1
    fi

    echo "[ADV] add version"
    add_version

    echo "[ADV] build images"
    build_yocto_images

    echo "[ADV] generate normal image"
    DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/deploy/images/${NEW_MACHINE}"

    IMAGE_DIR="$OFFICIAL_VER"_"$DATE"
    prepare_images normal $IMAGE_DIR
    copy_image_to_storage normal

    echo "[ADV] generate installation image"
    INSTALL_DIR="$OFFICIAL_VER"_sdcard_install_"$DATE"
    prepare_images installsd $INSTALL_DIR
    copy_image_to_storage installsd

    save_temp_log
fi

# Copy downloads to backup
if [ ! -e $CURR_PATH/downloads ] ; then
    echo "[ADV] backup 'downloads' directory"
    cp -a $CURR_PATH/$ROOT_DIR/downloads $CURR_PATH
fi

cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

