#!/bin/bash
PRODUCT=$1

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

OFFICAL_DEFAULT_VER_TAG="${PROJECT}_${OS_DISTRO}_v0.0.0_${KERNEL_VERSION}_${CHIP_NAME}"
OFFICAL_VER_TAG="${PROJECT}_${OS_DISTRO}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}"
OFFICAL_NO_RAM_SIZE_VER="${OFFICAL_VER_TAG}_${STORAGE}_${DATE}"
OFFICAL_BSP_VER="${OFFICAL_NO_RAM_SIZE_VER}"_bsp
OFFICAL_LOG_VER="${OFFICAL_NO_RAM_SIZE_VER}"_log
OFFICAL_MODULES_VER="${OFFICAL_NO_RAM_SIZE_VER}"_modules
OFFICAL_CVE_VER="${OFFICAL_NO_RAM_SIZE_VER}"_cve
OFFICAL_SPDX_VER="${OFFICAL_NO_RAM_SIZE_VER}"_spdx
OFFICAL_SBOM_VER="${OFFICAL_NO_RAM_SIZE_VER}"_sbom

DAILY_VER="${PROJECT}_${OS_DISTRO}_v${DAILY_RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}"
DAILY_NO_RAM_SIZE_VER="${DAILY_VER}_${STORAGE}_${DATE}"
DAILY_BSP_VER="${DAILY_NO_RAM_SIZE_VER}"_bsp
DAILY_LOG_VER="${DAILY_NO_RAM_SIZE_VER}"_log
DAILY_MODULES_VER="${DAILY_NO_RAM_SIZE_VER}"_modules
DAILY_CVE_VER="${DAILY_NO_RAM_SIZE_VER}"_cve
DAILY_SPDX_VER="${DAILY_NO_RAM_SIZE_VER}"_spdx
DAILY_SBOM_VER="${DAILY_NO_RAM_SIZE_VER}"_sbom

echo "$Release_Note" > Release_Note
RELEASE_NOTE="Release_Note"

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

    EXISTED_VERSION=`find .repo/manifests -name ${OFFICAL_VER_TAG}.xml`
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
    for MEMORY in $MEMORY_LIST; do
        DAILY_CSV_VER="${DAILY_VER}_${MEMORY}_${STORAGE}_${DATE}"
        CSV_FILE="${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}/${DAILY_CSV_VER}.img.csv"
    done

    echo "[ADV] Show HASH in ${CSV_FILE}"
    if [ -e ${CSV_FILE} ] ; then
        HASH_META_ADVANTECH=`cat ${CSV_FILE} | grep "meta-advantech" | cut -d ',' -f 2`
        echo "[ADV] HASH_META_ADVANTECH : ${HASH_META_ADVANTECH}"
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
        HASH_ID=`git tag -v $OFFICAL_VER_TAG | grep object | cut -d ' ' -f 2`
        if [ "x$HASH_ID" != "x" ] ; then
            echo "[ADV] tag exists! There is no need to add tag"
        else
            echo "[ADV] Add tag $OFFICAL_VER_TAG"
            REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
            git tag -a $OFFICAL_VER_TAG -m "[Official Release] $OFFICAL_VER_TAG"
            git push $REMOTE_SERVER $OFFICAL_VER_TAG
        fi
    else
        echo "[ADV] Directory $CURR_PATH/$ROOT_DIR/$FILE_PATH doesn't exist"
	exit 1
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
        repo manifest -o $OFFICAL_VER_TAG.xml -r

        # push to github
        REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
        git add $OFFICAL_VER_TAG.xml
        git commit -m "[Official Release] ${OFFICAL_VER_TAG}"
        git fetch
        git rebase
        git push
        git tag -a $OFFICAL_VER_TAG -F $CURR_PATH/$RELEASE_NOTE
        git push $REMOTE_SERVER $OFFICAL_VER_TAG
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
    EXISTED_VERSION=`find . -name ${OFFICAL_DEFAULT_VER_TAG}.xml`
    if [ -z "$EXISTED_VERSION" ] ; then
        echo "[ADV] No the default latest xml file"
        # push to github
        cp $CURR_PATH/$ROOT_DIR/.repo/manifests/${BSP_XML} ./${OFFICAL_DEFAULT_VER_TAG}.xml
        git add ${OFFICAL_DEFAULT_VER_TAG}.xml
        git commit -m "[Official Release] ${OFFICAL_DEFAULT_VER_TAG}"
        git push
    else
        if [ "$(cat $BSP_XML)" != "$(cat ${OFFICAL_DEFAULT_VER_TAG}.xml)" ]; then
            echo "[ADV] Update the ${OFFICAL_DEFAULT_VER_TAG}.xml"
            cp $CURR_PATH/$ROOT_DIR/.repo/manifests/${BSP_XML} ./${OFFICAL_DEFAULT_VER_TAG}.xml
            git add ${OFFICAL_DEFAULT_VER_TAG}.xml
            git commit -m "[Official Release] Update the ${OFFICAL_DEFAULT_VER_TAG}"
            git push
        fi
    fi

    # check the Official release xml file
    EXISTED_VERSION=`find . -name ${OFFICAL_VER_TAG}.xml`
    if [ -z "$EXISTED_VERSION" ] ; then
        echo "[ADV] This is a new VERSION"
        # push to github
        cp $CURR_PATH/$ROOT_DIR/.repo/manifests/$OFFICAL_VER_TAG.xml .
        git add $OFFICAL_VER_TAG.xml
        git commit -m "[Official Release] ${OFFICAL_VER_TAG}"
        git push
    else
        echo "[ADV] v$RELEASE_VERSION already exists!"
        exit 1
    fi
}

# === Funciton : prepend OfficialVersion to CSV ===
function prepend_official_version_to_csv() {
    for MEMORY in $MEMORY_LIST; do
        DAILY_CSV_VER="${DAILY_VER}_${MEMORY}_${STORAGE}_${DATE}"
        local csv_file="${DAILY_CSV_VER}.img.csv"
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
    done
}

# === Funciton : Process daily -> official image ===
function process_image() {
    local daily_image="$1"
    local official_image="$2"
    local ini_file="rootfs/etc/OEMInfo.ini"
	BLOCK_SIZE="512"

	pushd image >/dev/null

	# .img.tgz file
    echo "[INFO] Extracting ${daily_image}.img.tgz..."
    sudo tar -zxvf "${daily_image}.img.tgz"

    pushd "${daily_image}" >/dev/null

    sudo mkdir -p rootfs
	WIC_FILE=$(ls | grep "rootfs\.wic" | head -n 1)
	LAST_START=$(sudo fdisk -l "$WIC_FILE" | awk '/^'"$WIC_FILE"'/ {start=$2} END {print start}')
	BYTE_OFFSET=$((LAST_START * BLOCK_SIZE))
    sudo mount -o loop,offset=${BYTE_OFFSET} ${WIC_FILE} rootfs

    # Add the Officialbuild_Image_Version
    echo "[INFO] Add the Officialbuild_Image_Version in $ini_file..."
    sudo sed -i "/^\(Dailybuild_Image_Version\|Image_Version\):[[:space:]]*/a Officialbuild_Image_Version: V${RELEASE_VERSION}" "$ini_file"

	sleep 1
    sudo umount rootfs
    sudo rm -rf rootfs

    popd >/dev/null

    mv "${daily_image}" "${official_image}"

    echo "[INFO] Creating ${official_image}.img.tgz..."
    sudo tar -zcvf "${official_image}.img.tgz" "${official_image}"

    echo "[INFO] Generating md5 for ${official_image}.img.tgz..."
    md5sum "${official_image}.img.tgz" | awk '{print $1}' > "${official_image}.img.tgz.md5"
	mv "${official_image}.img.tgz.md5" ../

	# flash_tool file
	echo "[INFO] Extracting ${daily_image}_flash_tool.tgz..."
    sudo tar -zxvf "${daily_image}_flash_tool.tgz"

	cp ${official_image}/$WIC_FILE ${daily_image}_flash_tool/image/
	mv "${daily_image}_flash_tool" "${official_image}_flash_tool"

	echo "[INFO] Creating ${official_image}_flash_tool.tgz..."
    sudo tar -zcvf "${official_image}_flash_tool.tgz" "${official_image}_flash_tool"

    echo "[INFO] Generating md5 for ${official_image}_flash_tool.tgz..."
    md5sum "${official_image}_flash_tool.tgz" | awk '{print $1}' > "${official_image}_flash_tool.tgz.md5"
	mv "${official_image}_flash_tool.tgz.md5" ../

	sudo rm -rf ${official_image}
	sudo rm -rf ${official_image}_flash_tool
	sudo rm ${daily_image}.img.tgz
	sudo rm ${daily_image}_flash_tool.tgz

	popd >/dev/null

	sudo rm "${daily_image}.img.tgz.md5"
	sudo rm "${daily_image}_flash_tool.tgz.md5"
}

# === Funciton : Prepare official package ===
prepare_official_package() {
    echo "[INFO] Prepare official package"
    pushd "${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}" >/dev/null
	
    sudo apt-get update
    sudo apt-get install -y util-linux fdisk

    # image
    for MEMORY in $MEMORY_LIST; do
	    DAILY_IMAGE_VER="${DAILY_VER}_${MEMORY}_${STORAGE}_${DATE}"
        OFFICAL_IMAGE_VER="${OFFICAL_VER_TAG}_${MEMORY}_${STORAGE}_${DATE}"
        process_image "${DAILY_IMAGE_VER}" "${OFFICAL_IMAGE_VER}"
    done
	
    # CSV
    echo "[INFO] Renaming CSV file..."
    for MEMORY in $MEMORY_LIST; do
        DAILY_CSV_VER="${DAILY_VER}_${MEMORY}_${STORAGE}_${DATE}"
		OFFICAL_CSV_VER="${OFFICAL_VER_TAG}_${MEMORY}_${STORAGE}_${DATE}"
        mv "${DAILY_CSV_VER}.img.csv" "${OFFICAL_CSV_VER}.img.csv"
		sudo rm "${DAILY_CSV_VER}.img.csv.md5"
        echo "[INFO] Generating md5 for ${OFFICAL_CSV_VER}.img.csv..."
        md5sum "${OFFICAL_CSV_VER}.img.csv" | awk '{print $1}' > "${OFFICAL_CSV_VER}.img.csv.md5"
    done

    # Log
    echo "[INFO] Renaming Log file..."
    mv "${DAILY_LOG_VER}.tgz" "${OFFICAL_LOG_VER}.tgz"
	mv "${DAILY_LOG_VER}.tgz.md5" "${OFFICAL_LOG_VER}.tgz.md5"

	# BSP
	echo "[INFO] Renaming BSP file..."
    mv "bsp/${DAILY_BSP_VER}.tgz" "bsp/${OFFICAL_BSP_VER}.tgz"
	mv "${DAILY_BSP_VER}.tgz.md5" "${OFFICAL_BSP_VER}.tgz.md5"
	
	# imx-boot
	echo "[INFO] Renaming imx-boot file..."
    for MEMORY in $MEMORY_LIST; do
        DAILY_IMX_BOOT_VER="${DAILY_VER}_${MEMORY}_${STORAGE}_${DATE}"_imx-boot
		OFFICAL_IMX_BOOT_VER="${OFFICAL_VER_TAG}_${MEMORY}_${STORAGE}_${DATE}"_imx-boot
        mv "others/${DAILY_IMX_BOOT_VER}.tgz" "others/${OFFICAL_IMX_BOOT_VER}.tgz"
	    mv "${DAILY_IMX_BOOT_VER}.tgz.md5" "${OFFICAL_IMX_BOOT_VER}.tgz.md5"
    done

    # Modules
    echo "[INFO] Renaming Modules file..."
    mv "others/${DAILY_MODULES_VER}.tgz" "others/${OFFICAL_MODULES_VER}.tgz"
	mv "${DAILY_MODULES_VER}.tgz.md5" "${OFFICAL_MODULES_VER}.tgz.md5"
	
    # CVE
    echo "[INFO] Renaming CVE file..."
    mv "others/${DAILY_CVE_VER}.tgz" "others/${OFFICAL_CVE_VER}.tgz"
	mv "${DAILY_CVE_VER}.tgz.md5" "${OFFICAL_CVE_VER}.tgz.md5"
	
    # SPDX
    echo "[INFO] Renaming SPDX file..."
    mv "others/${DAILY_SPDX_VER}.tgz" "others/${OFFICAL_SPDX_VER}.tgz"
	mv "${DAILY_SPDX_VER}.tgz.md5" "${OFFICAL_SPDX_VER}.tgz.md5"

    # SBOM
    echo "[INFO] Renaming SBOM file..."
    mv "others/${DAILY_SBOM_VER}.html" "others/${OFFICAL_SBOM_VER}.html"
	mv "${DAILY_SBOM_VER}.html.md5" "${OFFICAL_SBOM_VER}.html.md5"

    popd >/dev/null
}

function copy_official_files() {
    echo "[INFO] Copy all official files to ${OUTPUT_DIR}/"
    mv -f ${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}/* $OUTPUT_DIR
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
    commit_tag sources/meta-advantech $BSP_BRANCH $HASH_META_ADVANTECH

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
