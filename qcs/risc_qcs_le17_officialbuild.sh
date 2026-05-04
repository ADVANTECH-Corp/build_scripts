#!/bin/bash
PRODUCT=$1

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] PROJECT_BRANCH = ${PROJECT_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] DAILY_RELEASE_VERSION = ${DAILY_RELEASE_VERSION}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] Release_Note = ${Release_Note}"
echo "[ADV] KERNEL_GIT_URL_BRANCH = ${KERNEL_GIT_URL_BRANCH}"

CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${PROJECT}_v${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
VER_TAG="${PROJECT}_${OS_DISTRO}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}"

# LE 1.7 特有的命名規則 (比照 le17_dailybuild.sh)
DAILY_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${DAILY_RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_${STORAGE}_${DATE}"
OFFICIAL_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_${STORAGE}_${DATE}"

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
    # LE 1.7 只有單一 IMAGE_VER
    CSV_FILE=${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}/${DAILY_IMAGE_VER}.csv

    if [ -e ${CSV_FILE} ] ; then
        HASH_MANIFEST=`cat ${CSV_FILE} | grep "Manifest" | cut -d ',' -f 2`
        HASH_KERNEL=`cat ${CSV_FILE} | grep "QCS_LINUX_QCOM" | cut -d ',' -f 2`
        # 注意：LE 1.7 使用 meta-advantech-qualcomm
        HASH_META_ADVANTECH=`cat ${CSV_FILE} | grep "META_ADVANTECH" | cut -d ',' -f 2`

        echo "[ADV] HASH_MANIFEST : ${HASH_MANIFEST}"
        echo "[ADV] HASH_KERNEL : ${HASH_KERNEL}"
        echo "[ADV] HASH_META_ADVANTECH : ${HASH_META_ADVANTECH}"
    else
        echo "[ADV] Cannot find ${CSV_FILE}"
        exit 1
    fi
}

function check_tag_and_checkout()
{
    FILE_PATH=$1
    META_BRANCH=$2
    HASH_CSV=$3

    if [ -d "$CURR_PATH/$ROOT_DIR/$FILE_PATH" ]; then
        cd $CURR_PATH/$ROOT_DIR/$FILE_PATH
        META_TAG=`git tag | grep $VER_TAG`
        if [ "$META_TAG" != "" ]; then
            echo "[ADV] $FILE_PATH has been tagged ($VER_TAG). Nothing to do."
        else
            echo "[ADV] Set $FILE_PATH to $HASH_CSV"
            # 取得原始分支名 (例如: m/lbp2.0 -> lbp2.0)
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
        echo "[ADV] $REMOTE_URL has been tagged, ID is $HASH_ID"
    else
        HASH_ID=$HASH_CSV
        echo "[ADV] $REMOTE_URL isn't tagged, set HASH_ID to $HASH_ID"
    fi
    sed -i "s/"\$\{AUTOREV\}"/$HASH_ID/g" $ROOT_DIR/$FILE_PATH
}

function commit_tag_and_rollback()
{
    FILE_PATH=$1
    if [ -d "$CURR_PATH/$ROOT_DIR/$FILE_PATH" ]; then
        cd $CURR_PATH/$ROOT_DIR/$FILE_PATH
        META_TAG=`git tag | grep $VER_TAG`
        if [ "x$META_TAG" != "x" ]; then
            echo "[ADV] $FILE_PATH has been tagged ($VER_TAG). Nothing to do."
        else
            echo "[ADV] create tag $VER_TAG"
            git add .
            git commit -m "[Official Release] $VER_TAG"
            git tag -a $VER_TAG -m "[Official Release] $VER_TAG"
            git push --follow-tags
            # Rollback to avoid local diffs
            HEAD_HASH_ID=`git rev-parse HEAD`
            git revert $HEAD_HASH_ID --no-edit
            git push
            git reset --hard $HEAD_HASH_ID
        fi
        cd $CURR_PATH
    fi
}

function commit_tag_and_package()
{
    REMOTE_URL=$1
    META_BRANCH=$2
    HASH_CSV=$3

    git clone $REMOTE_URL
    SOURCE_DIR=${REMOTE_URL##*/}
    SOURCE_DIR=${SOURCE_DIR/.git}
    cd $SOURCE_DIR
    git checkout $META_BRANCH
    git reset --hard $HASH_CSV

    HASH_ID=`git tag -v $VER_TAG | grep object | cut -d ' ' -f 2`
    if [ "x$HASH_ID" != "x" ] ; then
        echo "[ADV] tag exists! No need to add tag"
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
        repo manifest -o $VER_TAG.xml -r
        git add $VER_TAG.xml
        git commit -m "[Official Release] ${VER_TAG}"
        git fetch && git rebase
        git push
        git tag -a $VER_TAG -F $CURR_PATH/$REALEASE_NOTE
        git push origin $VER_TAG
        cd $CURR_PATH
    fi
}

function prepend_official_version_to_csv() {
    local csv_file="${DAILY_IMAGE_VER}.csv"
    local official_version="v${RELEASE_VERSION}"

    pushd ${CURR_PATH}/${PLATFORM_PREFIX}/${DATE} >/dev/null
    if [ -f "$csv_file" ]; then
        {
            echo "OfficialVersion"
            echo "$official_version"
            echo ""
            cat "$csv_file"
        } > "${csv_file}.tmp"
        mv "${csv_file}.tmp" "$csv_file"
    fi
    popd >/dev/null
}

function process_image() {
    local daily_image="$1"
    local official_image="$2"
    
    echo "[INFO] Processing ${daily_image} to ${official_image}..."
    sudo tar -zxvf "${daily_image}.tgz"

    pushd "${daily_image}" >/dev/null
    mkdir -p rootfs
    # 根據 LE 1.7 檔案結構掛載 system.img
    sudo mount -o loop,offset=0 system.img rootfs

    # LE 1.7 的 OEMInfo.ini 路徑
    mapfile -t ini_files < <(sudo find rootfs -type f -name "OEMInfo.ini")

    for ini_file in "${ini_files[@]}"; do
        echo "[INFO] Updating $ini_file..."
        sudo sed -i "/^\(Dailybuild_Image_Version\|Image_Version\):[[:space:]]*/a Officialbuild_Image_Version: V${RELEASE_VERSION}" "$ini_file"
    done

    sudo umount rootfs
    sudo rm -rf rootfs
    popd >/dev/null

    mv "${daily_image}" "${official_image}"
    sudo tar -zcvf "${official_image}.tgz" "${official_image}"
    md5sum "${official_image}.tgz" | awk '{print $1}' > "${official_image}.tgz.md5"
    sudo rm -rf ${official_image}
}

function prepare_official_package() {
    pushd "${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}" >/dev/null
    
    # 處理主要 Image
    process_image "${DAILY_IMAGE_VER}" "${OFFICIAL_IMAGE_VER}"

    # 處理 CSV
    mv "${DAILY_IMAGE_VER}.csv" "${OFFICIAL_IMAGE_VER}.csv"
    md5sum "${OFFICIAL_IMAGE_VER}.csv" | awk '{print $1}' > "${OFFICIAL_IMAGE_VER}.csv.md5"

    popd >/dev/null
}

function copy_official_files() {
    mv -f ${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}/${VER_TAG}* $OUTPUT_DIR
}

# ================
#  Main procedure 
# ================

mkdir $ROOT_DIR
get_source_code

if [ -z "$EXISTED_VERSION" ] ; then
    get_csv_info
    prepend_official_version_to_csv
    prepare_official_package
    copy_official_files

    echo "[ADV] Add tags to repositories"

    # 注意：LE 1.7 使用 layers/meta-advantech-qualcomm
    check_tag_and_checkout layers/meta-advantech-qualcomm "scarthgap-qli.1.7" $HASH_META_ADVANTECH

    # 更新 Kernel bbappend (路徑比照 le17_dailybuild)
    check_tag_and_replace $KERNEL_PATH/linux-kernel-headers-install_%.bbappend $KERNEL_URL $HASH_KERNEL
    check_tag_and_replace $KERNEL_PATH/linux-kernel-qcom-headers_%.bbappend $KERNEL_URL $HASH_KERNEL
    check_tag_and_replace $KERNEL_PATH/linux-qcom-custom_%.bbappend $KERNEL_URL $HASH_KERNEL

    commit_tag_and_rollback layers/meta-advantech-qualcomm

#    echo "[ADV] Add kernel tag and Package kernel"
#    commit_tag_and_package $KERNEL_URL $PROJECT_BRANCH $HASH_KERNEL
    echo "[ADV] Add kernel tag and Package kernel to branch $KERNEL_GIT_URL_BRANCH"
    commit_tag_and_package "$KERNEL_URL" "$KERNEL_GIT_URL_BRANCH" "$HASH_KERNEL"

    create_xml_and_commit

    rm -rf $ROOT_DIR
fi

echo "[ADV] build script done!"
