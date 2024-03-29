#!/bin/bash

PRODUCT=$1
CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${TARGET_BOARD}_${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
IMAGE_VER="${MODEL_NAME}${BOARD_VER}${AIM_VERSION}UIV${RELEASE_VERSION}"
VER_TAG="${VER_PREFIX}UBV"$(echo $RELEASE_VERSION | sed 's/[.]//')

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
    CSV_FILE=${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}/${IMAGE_VER}_emmc_${DATE}.tgz.csv

    echo "[ADV] Show HASH in ${CSV_FILE}"
    if [ -e ${CSV_FILE} ] ; then
        HASH_MANIFEST=`cat ${CSV_FILE} | grep "Manifest" | cut -d ',' -f 2`
        HASH_AMSS=`cat ${CSV_FILE} | grep "AMSS" | cut -d ',' -f 2`
        HASH_AUDIO_KERNEL=`cat ${CSV_FILE} | grep "AUDIO_KERNEL" | cut -d ',' -f 2`
        HASH_BOOTLOADER=`cat ${CSV_FILE} | grep "BOOTLOADER" | cut -d ',' -f 2`
        HASH_BSP=`cat ${CSV_FILE} | grep "BSP" | cut -d ',' -f 2`
        HASH_DISPLAY_HARDWARE=`cat ${CSV_FILE} | grep "DISPLAY_HARDWARE" | cut -d ',' -f 2`
        HASH_DOWNLOAD=`cat ${CSV_FILE} | grep "DOWNLOAD" | cut -d ',' -f 2`
        HASH_KERNEL=`cat ${CSV_FILE} | grep "QCS_KERNEL" | cut -d ',' -f 2`
        HASH_META_ADVANTECH=`cat ${CSV_FILE} | grep "META_ADVANTECH" | cut -d ',' -f 2`
        HASH_META_QTI_BSP=`cat ${CSV_FILE} | grep "META_QTI_BSP" | cut -d ',' -f 2`
        HASH_META_QTI_UBUNTU=`cat ${CSV_FILE} | grep "META_QTI_UBUNTU" | cut -d ',' -f 2`
        HASH_SCRIPTS=`cat ${CSV_FILE} | grep "SCRIPTS" | cut -d ',' -f 2`
        HASH_TOOLS=`cat ${CSV_FILE} | grep "TOOLS" | cut -d ',' -f 2`

        echo "[ADV] HASH_MANIFEST : ${HASH_MANIFEST}"
        echo "[ADV] HASH_AMSS : ${HASH_AMSS}"
        echo "[ADV] HASH_AUDIO_KERNEL : ${HASH_AUDIO_KERNEL}"
        echo "[ADV] HASH_BOOTLOADER : ${HASH_BOOTLOADER}"
        echo "[ADV] HASH_BSP : ${HASH_BSP}"
        echo "[ADV] HASH_DISPLAY_HARDWARE : ${HASH_DISPLAY_HARDWARE}"
        echo "[ADV] HASH_MANIFEST : ${HASH_MANIFEST}"
        echo "[ADV] HASH_DOWNLOAD : ${HASH_DOWNLOAD}"
        echo "[ADV] HASH_KERNEL : ${HASH_KERNEL}"
        echo "[ADV] HASH_META_ADVANTECH : ${HASH_META_ADVANTECH}"
        echo "[ADV] HASH_META_QTI_BSP : ${HASH_META_QTI_BSP}"
        echo "[ADV] HASH_META_QTI_UBUNTU : ${HASH_META_QTI_UBUNTU}"
        echo "[ADV] HASH_SCRIPTS : ${HASH_SCRIPTS}"
        echo "[ADV] HASH_TOOLS : ${HASH_TOOLS}"
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
        git fetch
        git rebase
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
    commit_tag amss $BSP_BRANCH $HASH_AMSS
    commit_tag src/vendor/qcom/opensource/audio-kernel $BSP_BRANCH $HASH_AUDIO_KERNEL
    commit_tag src/bootable/bootloader/edk2 $BSP_BRANCH $HASH_BOOTLOADER
    commit_tag src/hardware/qcom/display $BSP_BRANCH $HASH_DISPLAY_HARDWARE
    commit_tag download $BSP_BRANCH $HASH_DOWNLOAD
    commit_tag src/kernel/msm-5.4 $KERNEL_BRANCH $HASH_KERNEL
    commit_tag poky/meta-advantech $BSP_BRANCH $HASH_META_ADVANTECH
    commit_tag poky/meta-qti-bsp $BSP_BRANCH $HASH_META_QTI_BSP
    commit_tag poky/meta-qti-ubuntu $BSP_BRANCH $HASH_META_QTI_UBUNTU
    commit_tag scripts $BSP_BRANCH $HASH_SCRIPTS
    commit_tag tools $BSP_BRANCH $HASH_TOOLS

    # Create manifests xml and commit
    create_xml_and_commit $HASH_MANIFEST

    rm -rf $ROOT_DIR
fi

echo "[ADV] copy dailybuild files"
copy_dailybuild_files

echo "[ADV] build script done!"
