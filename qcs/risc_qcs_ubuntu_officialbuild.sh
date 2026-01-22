#!/bin/bash
PRODUCT=$1
set -x
echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] DAILY_RELEASE_VERSION = ${DAILY_RELEASE_VERSION}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] Release_Note = ${Release_Note}"

CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${PROJECT}_v${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
VER_TAG="${PROJECT}_${OS_DISTRO}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}"
DEFAULT_VER_TAG="${PROJECT}_${OS_DISTRO}_v0.0.0_${KERNEL_VERSION}_${CHIP_NAME}"
DAILY_CSV_VER="${PROJECT}_${OS_DISTRO}_v${DAILY_RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_${DATE}"
DAILY_LOG_VER="${PROJECT}_${OS_DISTRO}_v${DAILY_RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_${DATE}_log"
DAILY_UFS_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${DAILY_RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_${STORAGE}_${DATE}"
DAILY_EMMC_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${DAILY_RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_emmc_${DATE}"
OFFICAL_CSV_VER="${PROJECT}_${OS_DISTRO}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_${DATE}"
OFFICAL_LOG_VER="${PROJECT}_${OS_DISTRO}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_${DATE}_log"
OFFICAL_UFS_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_${STORAGE}_${DATE}"
OFFICAL_EMMC_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_emmc_${DATE}"

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
    echo "[ADV] get source code"
    cd $CURR_PATH/$ROOT_DIR

    do_repo_init

    EXISTED_VERSION=`find .repo/manifests -name ${VER_TAG}.xml`
    if [ -z "$EXISTED_VERSION" ] ; then
        echo "[ADV] This is a new VERSION"
        repo sync
    else
        echo "[ADV] v$RELEASE_VERSION already exists!"
        exit 1
    fi
}

function get_csv_info()
{
    echo "[ADV] get csv info"
    CSV_FILE=${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}/${DAILY_CSV_VER}.csv

    echo "[ADV] Show HASH in ${CSV_FILE}"
    if [ -e ${CSV_FILE} ] ; then
        HASH_MANIFEST=`cat ${CSV_FILE} | grep "Manifest" | cut -d ',' -f 2`
        HASH_BOOT_FW=`cat ${CSV_FILE} | grep "BOOT_FW" | cut -d ',' -f 2`
        HASH_DOWNLOAD=`cat ${CSV_FILE} | grep "DOWNLOAD" | cut -d ',' -f 2`
        HASH_KERNEL=`cat ${CSV_FILE} | grep "QCS_UBUNTU" | cut -d ',' -f 2`
        HASH_SCRIPTS=`cat ${CSV_FILE} | grep "QCS_SCRIPTS" | cut -d ',' -f 2`
        HASH_TOOLS=`cat ${CSV_FILE} | grep "QCS_TOOLS" | cut -d ',' -f 2`

        echo "[ADV] HASH_MANIFEST : ${HASH_MANIFEST}"
        echo "[ADV] HASH_BOOT_FW : ${HASH_BOOT_FW}"
        echo "[ADV] HASH_DOWNLOAD : ${HASH_DOWNLOAD}"
        echo "[ADV] HASH_KERNEL : ${HASH_KERNEL}"
        echo "[ADV] HASH_SCRIPTS : ${HASH_SCRIPTS}"
        echo "[ADV] HASH_TOOLS : ${HASH_TOOLS}"
    else
        echo "[ADV] Cannot find ${CSV_FILE}"
        exit 1
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
	exit 1
    fi

    cd $CURR_PATH
}


function check_tag_and_checkout()
{
	FILE_PATH=$1
	META_BRANCH=$2
	HASH_CSV=$3

        if [ -d "$ROOT_DIR/$FILE_PATH" ];then
                cd $ROOT_DIR/$FILE_PATH
                META_TAG=`git tag | grep $VER_TAG`
                if [ "$META_TAG" != "" ]; then
                        echo "[ADV] meta-advantech has been tagged ($VER_TAG). Nothing to do."
                else
			echo "[ADV] Set meta-advantech to $HASH_CSV"
			BRANCH_SUFFIX=`echo $META_BRANCH | cut -d '_' -f 2`
			BRANCH_ORI="${META_BRANCH/_$BRANCH_SUFFIX}"
			git checkout $BRANCH_ORI
			git pull
			git reset --hard $HASH_CSV
			echo "[ADV] Checkout to '$META_BRANCH' and merge from '$BRANCH_ORI'"
			git checkout $META_BRANCH
			git pull
			git merge $BRANCH_ORI --no-edit --log
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
        HASH_CSV=$3

        HASH_ID=`git ls-remote $REMOTE_URL $VER_TAG | awk '{print $1}'`
        if [ "x$HASH_ID" != "x" ]; then
                echo "[ADV] $REMOTE_URL has been tagged ,ID is $HASH_ID"
        else
		HASH_ID=$HASH_CSV
                echo "[ADV] $REMOTE_URL isn't tagged , set HASH_ID to $HASH_ID"
        fi
        sed -i "s/"\$\{AUTOREV\}"/$HASH_ID/g" $ROOT_DIR/$FILE_PATH
}

function commit_tag_and_rollback()
{
        FILE_PATH=$1

        if [ -d "$ROOT_DIR/$FILE_PATH" ];then
                cd $ROOT_DIR/$FILE_PATH
                META_TAG=`git tag | grep $VER_TAG`
                if [ "x$META_TAG" != "x" ]; then
                        echo "[ADV] meta-advantech has been tagged ($VER_TAG). Nothing to do."
                else
                        echo "[ADV] create tag $VER_TAG"
                        REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                        git add .
                        git commit -m "[Official Release] $VER_TAG"
                        git tag -a $VER_TAG -m "[Official Release] $VER_TAG"
                        git push --follow-tags
                        # Rollback
                        HEAD_HASH_ID=`git rev-parse HEAD`
                        git revert $HEAD_HASH_ID --no-edit
                        git push
                        git reset --hard $HEAD_HASH_ID
                fi
                cd $CURR_PATH
        else
                echo "[ADV] Directory $ROOT_DIR/$FILE_PATH doesn't exist"
                exit 1
        fi
}

function commit_tag_and_package()
{
        REMOTE_URL=$1
        META_BRANCH=$2
        HASH_CSV=$3

        # Get source
        git clone $REMOTE_URL
        SOURCE_DIR=${REMOTE_URL##*/}
        SOURCE_DIR=${SOURCE_DIR/.git}
        cd $SOURCE_DIR
        git checkout $META_BRANCH
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

        cd $CURR_PATH
}

function create_xml_and_commit()
{
    if [ -d "$CURR_PATH/$ROOT_DIR/.repo/manifests" ];then
        echo "[ADV] Create XML file"
        cd $CURR_PATH/$ROOT_DIR/.repo/manifests
        git checkout $BSP_BRANCH

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
        cd $CURR_PATH
    else
        echo "[ADV] Directory $CURR_PATH/$ROOT_DIR/.repo/manifests doesn't exist"
        exit 1
    fi
}

function create_aim_linux_release_xml()
{
    echo "[ADV] get AIM_Linux_Release source code"
    cd $CURR_PATH/$ROOT_DIR

    git clone $AIM_LINUX_RELEASE_BSP_URL -b ${OS_DISTRO}
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
    local csv_file="${DAILY_CSV_VER}.csv"
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
    local ini_files

    echo "[INFO] Extracting ${daily_image}.tgz..."
    sudo tar -zxvf "${daily_image}.tgz"

    pushd "${daily_image}" >/dev/null

    local image=$(ls -t iot-*.img 2>/dev/null | head -1)
    local offsetp3=$((4096 * 139008))

    mkdir -p rootfs
    sudo mount -o loop,offset=$offsetp3 $image rootfs

    # Find all OEMInfo.ini files dynamically
    pushd rootfs >/dev/null
    mapfile -t ini_files < <(sudo find . -type f -name "OEMInfo.ini")

    if [ ${#ini_files[@]} -eq 0 ]; then
        echo "[ERROR] OEMInfo.ini not found"
    fi

    # Add the Officialbuild_Image_Version
    for ini_file in "${ini_files[@]}"; do
        echo "[INFO] Add the Officialbuild_Image_Version in $ini_file..."
        sudo sed -i "/^\(Dailybuild_Image_Version\|Image_Version\):[[:space:]]*/a Officialbuild_Image_Version: V${RELEASE_VERSION}" "$ini_file"
    done

    popd >/dev/null

    sleep 1
    sudo umount rootfs
    sudo rm -rf rootfs
    popd >/dev/null

    mv "${daily_image}" "${official_image}"

    echo "[INFO] Creating ${official_image}.tgz..."
    sudo tar -zcvf "${official_image}.tgz" "${official_image}"

    echo "[INFO] Generating md5 for ${official_image}.tgz..."
    md5sum "${official_image}.tgz" | awk '{print $1}' > "${official_image}.tgz.md5"
    sudo rm -rf ${official_image}
}

# === Funciton : Prepare official package ===
prepare_official_package() {
    echo "[INFO] Prepare official package"
    pushd "${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}" >/dev/null

    # UFS
    process_image "${DAILY_UFS_IMAGE_VER}" "${OFFICAL_UFS_IMAGE_VER}"

    # EMMC
    # process_image "${DAILY_EMMC_IMAGE_VER}" "${OFFICAL_EMMC_IMAGE_VER}"

    # CSV
    echo "[INFO] Renaming CSV file..."
    mv "${DAILY_CSV_VER}.csv" "${OFFICAL_CSV_VER}.csv"
    echo "[INFO] Generating md5 for ${OFFICAL_CSV_VER}.csv..."
    md5sum "${OFFICAL_CSV_VER}.csv" | awk '{print $1}' > "${OFFICAL_CSV_VER}.csv.md5"

    # Log
    echo "[INFO] Renaming Log file..."
    mv "${DAILY_LOG_VER}.tgz" "${OFFICAL_LOG_VER}.tgz"
    echo "[INFO] Generating md5 for ${OFFICAL_LOG_VER}.tgz..."
    md5sum "${OFFICAL_LOG_VER}.tgz" | awk '{print $1}' > "${OFFICAL_LOG_VER}.tgz.md5"

    popd >/dev/null
}

function copy_official_files() {
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
    commit_tag boot-firmware $BSP_BRANCH $HASH_BOOT_FW
    commit_tag download $BSP_BRANCH $HASH_DOWNLOAD
    commit_tag noble $BSP_BRANCH $HASH_KERNEL
    commit_tag scripts $BSP_BRANCH $HASH_SCRIPTS
    commit_tag tools $BSP_BRANCH $HASH_TOOLS

    # Create manifests xml and commit
    create_xml_and_commit

    # Create AIM_Linux_Release xml file
    if [ "$RELEASE_TO_BSP_LAUNCHER" = "y" ]; then
        create_aim_linux_release_xml
    else
        echo "Skip releasing .xml to AIM Linux Release"
    fi

    rm -rf $ROOT_DIR
fi

echo "[ADV] build script done!"
