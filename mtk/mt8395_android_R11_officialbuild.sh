#!/bin/bash

PRODUCT=$1
CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
IMAGE_VER="${MODEL_NAME}${BOARD_VER}${AIM_VERSION}AIV${RELEASE_VERSION}_$DATE"
VER_TAG="${VER_PREFIX}AB"$(echo $RELEASE_VERSION | sed 's/[.]//')

HASH_ANDROID_BSP=""
HASH_ANDROID_DEVICE=""
HASH_ANDROID_FRAMEWORKS=""
HASH_ANDROID_HARDWARE=""
HASH_ANDROID_KERNEL=""
HASH_ANDROID_PACKAGES=""
HASH_ANDROID_SYSTEM=""
HASH_ANDROID_VENDOR=""
EXISTED_VERSION=""

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MODEL_NAME = ${MODEL_NAME}"
echo "[ADV] BOARD_VER = ${BOARD_VER}"
echo "[ADV] ROOT_DIR = ${ROOT_DIR}"
echo "[ADV] OUTPUT_DIR = ${OUTPUT_DIR}"
echo "[ADV] IMAGE_VER = ${IMAGE_VER}"
echo "[ADV] VER_TAG = ${VER_TAG}"
echo "[ADV] KERNEL_BRANCH = ${KERNEL_BRANCH}"
echo "[ADV] Release_Note = ${Release_Note}"

echo "$Release_Note" > Release_Note
REALEASE_NOTE="Release_Note"

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
    echo "[ADV] get android source code"
    cd $CURR_PATH/$ROOT_DIR

    do_repo_init

    EXISTED_VERSION=`find .repo/manifests -name ${VER_TAG}.xml`
    if [ -z "$EXISTED_VERSION" ] ; then
        echo "[ADV] This is a new VERSION"
        repo sync
    else
        echo "[ADV] $RELEASE_VERSION already exists!"
    fi
}

function get_csv_info()
{
    echo "[ADV] get csv info"
    CSV_FILE=${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}/${IMAGE_VER}.csv

    echo "[ADV] Show HASH in ${CSV_FILE}"
    if [ -e ${CSV_FILE} ] ; then
        HASH_ANDROID_BSP=`cat ${CSV_FILE} | grep "ANDROID_BSP" | cut -d ',' -f 2`
        HASH_ANDROID_DEVICE=`cat ${CSV_FILE} | grep "ANDROID_DEVICE" | cut -d ',' -f 2`
        HASH_ANDROID_FRAMEWORKS=`cat ${CSV_FILE} | grep "ANDROID_FRAMEWORKS" | cut -d ',' -f 2`
        HASH_ANDROID_HARDWARE=`cat ${CSV_FILE} | grep "ANDROID_HARDWARE" | cut -d ',' -f 2`
        HASH_ANDROID_KERNEL=`cat ${CSV_FILE} | grep "ANDROID_KERNEL" | cut -d ',' -f 2`
        HASH_ANDROID_PACKAGES=`cat ${CSV_FILE} | grep "ANDROID_PACKAGES" | cut -d ',' -f 2`
        HASH_ANDROID_SYSTEM=`cat ${CSV_FILE} | grep "ANDROID_SYSTEM" | cut -d ',' -f 2`
        HASH_ANDROID_VENDOR=`cat ${CSV_FILE} | grep "ANDROID_VENDOR" | cut -d ',' -f 2`

        echo "[ADV] HASH_ANDROID_BSP : ${HASH_ANDROID_BSP}"
        echo "[ADV] HASH_ANDROID_DEVICE : ${HASH_ANDROID_DEVICE}"
        echo "[ADV] HASH_ANDROID_FRAMEWORKS : ${HASH_ANDROID_FRAMEWORKS}"
        echo "[ADV] HASH_ANDROID_HARDWARE : ${HASH_ANDROID_HARDWARE}"
        echo "[ADV] HASH_ANDROID_KERNEL : ${HASH_ANDROID_KERNEL}"
        echo "[ADV] HASH_ANDROID_PACKAGES : ${HASH_ANDROID_PACKAGES}"
        echo "[ADV] HASH_ANDROID_SYSTEM : ${HASH_ANDROID_SYSTEM}"
        echo "[ADV] HASH_ANDROID_VENDOR : ${HASH_ANDROID_VENDOR}"
    else
        echo "[ADV] Cannot find ${CSV_FILE}"
        exit 1;
    fi
}

function commit_tag()
{
    FILE_PATH=$1
    BRANCH=$2
    HASH_CSV=$3

    if [ -d "$CURR_PATH/$ROOT_DIR/$FILE_PATH" ]; then
        cd $CURR_PATH/$ROOT_DIR/$FILE_PATH
        git checkout $BRANCH
        git reset --hard $HASH_CSV

        # Add tag
        HASH_ID=`git tag -v $VER_TAG | grep object | cut -d ' ' -f 2`
        if [ "x$HASH_ID" != "x" ] ; then
            echo "[ADV] tag exists! There is no need to add tag"
        else
            echo "[ADV] Add tag $VER_TAG"
            REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
            git tag -a $VER_TAG -m "[Official Release] $VER_TAG"
            git push $REMOTE_SERVER $VER_TAG
        fi
    else
        echo "[ADV] Directory $CURR_PATH/$ROOT_DIR/$FILE_PATH doesn't exist"
    fi

    cd $CURR_PATH
}

function create_xml_and_commit()
{
    HASH_CSV=$1

    if [ -d "$CURR_PATH/$ROOT_DIR/.repo/manifests" ];then
        echo "[ADV] Create XML file"
        cd $CURR_PATH/$ROOT_DIR/.repo/manifests
 	git checkout $BSP_BRANCH
	git reset --hard $HASH_CSV
        # add revision into xml
        repo manifest -o $VER_TAG.xml -r

        # push to github
        REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
        git add $VER_TAG.xml
        git commit -m "[Official Release] ${VER_TAG}"
        git push
        git tag -a $VER_TAG -F $CURR_PATH/$REALEASE_NOTE
        git push $REMOTE_SERVER $VER_TAG
    else
        echo "[ADV] Directory $CURR_PATH/$ROOT_DIR/.repo/manifests doesn't exist"
    fi

    cd $CURR_PATH
}

function copy_dailybuild_files()
{
    echo "[ADV] copy dailybuild files to $OUTPUT_DIR"

    mv -f ${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}/${IMAGE_VER}* $OUTPUT_DIR
}

# ================
#  Main procedure 
# ================

mkdir $ROOT_DIR
get_source_code

if [ -z "$EXISTED_VERSION" ] ; then
    # Get the dailybuild commit info
    get_csv_info

    echo "[ADV] Add tag"
    commit_tag device $BSP_BRANCH $HASH_ANDROID_DEVICE
    commit_tag frameworks $BSP_BRANCH $HASH_ANDROID_FRAMEWORKS
    commit_tag hardware $BSP_BRANCH $HASH_ANDROID_HARDWARE
    commit_tag kernel-4.19 $KERNEL_BRANCH $HASH_ANDROID_KERNEL
    commit_tag packages $BSP_BRANCH $HASH_ANDROID_PACKAGES
    commit_tag system  $BSP_BRANCH $HASH_ANDROID_SYSTEM
    commit_tag vendor $BSP_BRANCH $HASH_ANDROID_VENDOR

    # Create manifests xml and commit
    create_xml_and_commit $HASH_ANDROID_BSP

    rm -rf $ROOT_DIR
fi

echo "[ADV] copy dailybuild files"
copy_dailybuild_files

echo "[ADV] build script done!"
