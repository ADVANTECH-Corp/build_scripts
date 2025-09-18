#!/bin/bash

PRODUCT=$1
CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${PROJECT}_v${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"

VER_TAG="${PROJECT}_${OS_VERSION}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${TARGET_BOARD}"
DEFAULT_VER_TAG="${PROJECT}_${OS_VERSION}_v0.0.0_${KERNEL_VERSION}_${TARGET_BOARD}"
DAILY_CSV_VER="${PROJECT}_${OS_VERSION}_v${DAILY_RELEASE_VERSION}_${KERNEL_VERSION}_${TARGET_BOARD}_${SOC_MEM}_${STORAGE}_${DATE}"
DAILY_LOG_VER="${PROJECT}_${OS_VERSION}_v${DAILY_RELEASE_VERSION}_${KERNEL_VERSION}_${TARGET_BOARD}_${SOC_MEM}_${STORAGE}_${DATE}_log"
DAILY_IMAGE_VER="${PROJECT}_${OS_VERSION}_v${DAILY_RELEASE_VERSION}_${KERNEL_VERSION}_${TARGET_BOARD}_${SOC_MEM}_${STORAGE}_${DATE}"
OFFICAL_CSV_VER="${PROJECT}_${OS_VERSION}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${TARGET_BOARD}_${SOC_MEM}_${STORAGE}_${DATE}"
OFFICAL_LOG_VER="${PROJECT}_${OS_VERSION}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${TARGET_BOARD}_${SOC_MEM}_${STORAGE}_${DATE}_log"
OFFICAL_IMAGE_VER="${PROJECT}_${OS_VERSION}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${TARGET_BOARD}_${SOC_MEM}_${STORAGE}_${DATE}"


#IMAGE_VER="${PROJECT}_${OS_VERSION}${RELEASE_VERSION}_${KERNEL_VERSION}_${SOC_MEM}_${STORAGE}_${DATE}"
#VER_TAG="${PROJECT}_${OS_VERSION}${RELEASE_VERSION}_${KERNEL_VERSION}_${SOC_MEM}"


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
echo "[ADV] DAILY_RELEASE_VERSION = ${DAILY_RELEASE_VERSION}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] Release_Note = ${Release_Note}"

echo "$Release_Note" > Release_Note
REALEASE_NOTE="Release_Note"

EXISTED_VERSION=""

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
        echo "[ADV] v$RELEASE_VERSION already exists!"
    fi
}

function get_csv_info()
{
    echo "[ADV] get csv info"
    CSV_FILE=${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}/${DAILY_CSV_VER}.tgz.csv

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

function create_aim_linux_release_xml()
{
    echo "[ADV] get AIM_Linux_Release source code"
    cd $CURR_PATH/$ROOT_DIR

    git clone $AIM_LINUX_RELEASE_BSP_URL -b ${OS_VERSION}
    pushd $AIM_LINUX_RELEASE_BSP_PLATFORM

    # check the default latest xml file
    EXISTED_VERSION=`find . -name ${DEFAULT_VER_TAG}.xml`
    if [ -z "$EXISTED_VERSION" ] ; then
        echo "[ADV] No the default latest xml file"
        # push to github
        cp $CURR_PATH/$ROOT_DIR/.repo/manifests/${BSP_XML} ./${DEFAULT_VER_TAG}.xml
        git add ${DEFAULT_VER_TAG}.xml
        git commit -m "[Official Release] ${DEFAULT_VER_TAG}"
        git push
    else
        if [ "$(cat $BSP_XML)" != "$(cat ${DEFAULT_VER_TAG}.xml)" ]; then
            echo "[ADV] Update the ${DEFAULT_VER_TAG}.xml"
            cp $CURR_PATH/$ROOT_DIR/.repo/manifests/${BSP_XML} ./${DEFAULT_VER_TAG}.xml
            git add ${DEFAULT_VER_TAG}.xml
            git commit -m "[Official Release] Update the ${DEFAULT_VER_TAG}"
            git push
        fi
    fi

    # check the Official release xml file
    EXISTED_VERSION=`find . -name ${VER_TAG}.xml`
    if [ -z "$EXISTED_VERSION" ] ; then
        echo "[ADV] This is a new VERSION"
        # push to github
        cp $CURR_PATH/$ROOT_DIR/.repo/manifests/$VER_TAG.xml .
        git add $VER_TAG.xml
        git commit -m "[Official Release] ${VER_TAG}"
        git push
    else
        echo "[ADV] v$RELEASE_VERSION already exists!"
        exit 1
    fi
}

# === Funciton : prepend OfficialVersion to CSV ===
function prepend_official_version_to_csv() {
    local csv_file="${DAILY_CSV_VER}.tgz.csv"
    local official_version="v${RELEASE_VERSION}"

    pushd ${CURR_PATH}/${PLATFORM_PREFIX}/${DATE} >/dev/null

    if [ ! -f "$csv_file" ]; then
        echo "[ERROR] CSV file $csv_file not found!"
        exit 1
    fi

    {
        echo "OfficialVersion"
        echo "$official_version"
        echo ""
        cat "$csv_file"
    } > "${csv_file}.tmp"

    mv "${csv_file}.tmp" "$csv_file"
    echo "[INFO] OfficialVersion $official_version prepended to $csv_file"

    popd >/dev/null
}

# === Funciton : Process daily -> official image ===
function process_image() {
    local daily_image="$1"
    local official_image="$2"
    local ini_file="rootfs/etc/OEMInfo.ini"

    echo "[INFO] Extracting ${daily_image}.tgz..."
    sudo tar -zxvf "${daily_image}.tgz"

    pushd Linux_for_Tegra >/dev/null
    
    # Update the Image_Version
    sudo sed -i "s/^Image_Version:.*/Image_Version: V${RELEASE_VERSION}/" "$ini_file"

    popd >/dev/null

    echo "[INFO] Creating ${official_image}.tgz..."
    sudo tar -zcvf "${official_image}.tgz" Linux_for_Tegra

    echo "[INFO] Generating md5 for ${official_image}.tgz..."
    md5sum "${official_image}.tgz" | awk '{print $1}' > "${official_image}.tgz.md5"
    sudo rm -rf Linux_for_Tegra
}

# === Funciton : Prepare official package ===
prepare_official_package() {
    echo "[INFO] Prepare official package"
    pushd "${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}" >/dev/null

    process_image "${DAILY_IMAGE_VER}" "${OFFICAL_IMAGE_VER}"

    # CSV
    echo "[INFO] Renaming CSV file..."
    mv "${DAILY_CSV_VER}.tgz.csv" "${OFFICAL_CSV_VER}.tgz.csv"
    echo "[INFO] Generating md5 for ${OFFICAL_CSV_VER}.tgz.csv..."
    md5sum "${OFFICAL_CSV_VER}.tgz.csv" | awk '{print $1}' > "${OFFICAL_CSV_VER}.tgz.csv.md5"

    # Log
    echo "[INFO] Renaming Log file..."
    mv "${DAILY_LOG_VER}.tgz" "${OFFICAL_LOG_VER}.tgz"
    echo "[INFO] Generating md5 for ${OFFICAL_LOG_VER}.tgz..."
    md5sum "${OFFICAL_LOG_VER}.tgz" | awk '{print $1}' > "${OFFICAL_LOG_VER}.tgz.md5"

    popd >/dev/null
}

function copy_official_files()
{
    echo "[INFO] Copy all official files to ${OUTPUT_DIR}/"

    mv -f ${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}/${VER_TAG}* $OUTPUT_DIR
}

# ================
#  Main procedure 
# ================

mkdir $ROOT_DIR
get_source_code

if [ -z "$EXISTED_VERSION" ] ; then
    # Get the dailybuild commit info
    get_csv_info

    # Prepare official files
    prepend_official_version_to_csv
    prepare_official_package
    copy_official_files

    echo "[ADV] Add tag"
    commit_tag download $BSP_BRANCH $HASH_JETSON_DOWNLOAD
    commit_tag kernel $PROJECT_BRANCH $HASH_JETSON_KERNEL
    commit_tag Linux_for_Tegra $PROJECT_BRANCH $HASH_JETSON_L4T
    commit_tag scripts $PROJECT_BRANCH $HASH_JETSON_SCRIPTS
    commit_tag tools $PROJECT_BRANCH $HASH_JETSON_TOOLS

    # Create manifests xml and commit
    create_xml_and_commit $HASH_MANIFEST

    # Create AIM_Linux_Release xml file
    create_aim_linux_release_xml

    rm -rf $ROOT_DIR
fi

echo "[ADV] build script done!"
