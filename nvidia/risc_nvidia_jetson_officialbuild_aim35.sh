#!/bin/bash

PRODUCT=$1
CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${TARGET_BOARD}_${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
IMAGE_VER="${MODEL_NAME}${BOARD_VER}${AIM_VERSION}UIV${RELEASE_VERSION}_$DATE"
VER_TAG="${VER_PREFIX}UBV"$(echo $RELEASE_VERSION | sed 's/[.]//')

HASH_MANIFEST=""
HASH_JETSON_DOWNLOAD=""
HASH_JETSON_KERNEL=""
HASH_JETSON_L4T=""
HASH_JETSON_SCRIPTS=""
HASH_JETSON_TOOLS=""

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
    CSV_FILE=${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}/${IMAGE_VER}.tgz.csv

    echo "[ADV] Show HASH in ${CSV_FILE}"
    if [ -e ${CSV_FILE} ] ; then
        HASH_MANIFEST=`cat ${CSV_FILE} | grep "Manifest" | cut -d ',' -f 2`
        HASH_JETSON_DOWNLOAD=`cat ${CSV_FILE} | grep "JETSON_DOWNLOAD" | cut -d ',' -f 2`
        HASH_JETSON_KERNEL=`cat ${CSV_FILE} | grep "JETSON_KERNEL" | cut -d ',' -f 2`
        HASH_JETSON_L4T=`cat ${CSV_FILE} | grep "JETSON_L4T" | cut -d ',' -f 2`
        HASH_JETSON_SCRIPTS=`cat ${CSV_FILE} | grep "JETSON_SCRIPTS" | cut -d ',' -f 2`
        HASH_JETSON_TOOLS=`cat ${CSV_FILE} | grep "JETSON_TOOLS" | cut -d ',' -f 2`

        echo "[ADV] HASH_MANIFEST : ${HASH_MANIFEST}"
        echo "[ADV] HASH_JETSON_DOWNLOAD : ${HASH_JETSON_DOWNLOAD}"
        echo "[ADV] HASH_JETSON_KERNEL : ${HASH_JETSON_KERNEL}"
        echo "[ADV] HASH_JETSON_L4T : ${HASH_JETSON_L4T}"
        echo "[ADV] HASH_JETSON_SCRIPTS : ${HASH_JETSON_SCRIPTS}"
        echo "[ADV] HASH_JETSON_TOOLS : ${HASH_JETSON_TOOLS}"
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
    commit_tag download $BSP_BRANCH $HASH_JETSON_DOWNLOAD
    commit_tag kernel $PROJECT_BRANCH $HASH_JETSON_KERNEL
    commit_tag Linux_for_Tegra $PROJECT_BRANCH $HASH_JETSON_L4T
    commit_tag scripts $PROJECT_BRANCH $HASH_JETSON_SCRIPTS
    commit_tag tools $PROJECT_BRANCH $HASH_JETSON_TOOLS

    # Create manifests xml and commit
    create_xml_and_commit $HASH_MANIFEST

    rm -rf $ROOT_DIR
fi

echo "[ADV] copy dailybuild files"
copy_dailybuild_files

echo "[ADV] build script done!"
