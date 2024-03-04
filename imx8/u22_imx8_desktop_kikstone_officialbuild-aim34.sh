#!/bin/bash

PRODUCT=$1
OFFICIAL_VER=$2
MEMORY_LIST=$3
BOOT_DEVICE_LIST=$4

#--- [platform specific] ---
VER_PREFIX="imx8"
TMP_DIR="tmp"
#---------------------------
echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] DEPLOY_IMAGE_NAME = ${DEPLOY_IMAGE_NAME}"
echo "[ADV] BACKEND_TYPE = ${BACKEND_TYPE}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"
echo "[ADV] MEMORY_LIST=${MEMORY_LIST}"
echo "[ADV] BOOT_DEVICE_LIST=${BOOT_DEVICE_LIST}"
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

VER_TAG="${VER_PREFIX}UBV${RELEASE_VERSION}"

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
function define_cpu_type()
{
    CPU_TYPE=${1##*-}
    case $CPU_TYPE in
        "8MP")
            PRODUCT=${1%-*}
            KERNEL_CPU_TYPE="imx8mp"
            CPU_TYPE="iMX8MP"
            ;;
        *)
            # Do nothing
            ;;
    esac
}

function do_repo_init()
{
    repo init -u $BSP_URL ${BSP_BRANCH+"-b"} $BSP_BRANCH ${BSP_XML+"-m"} $BSP_XML
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
        echo "[ADV] ${RELEASE_VERSION} already exists!"
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
    [[ -e $1 ]] && md5sum -b $1 > $1.md5
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

    # Package
    cd ..
    echo "[ADV] creating "$ROOT_DIR"_"$SOURCE_DIR".tgz ..."
    tar czf "$ROOT_DIR"_"$SOURCE_DIR".tgz $SOURCE_DIR --exclude-vcs
    generate_md5 "$ROOT_DIR"_"$SOURCE_DIR".tgz
    rm -rf $SOURCE_DIR
    mv -f "$ROOT_DIR"_"$SOURCE_DIR".tgz $STORAGE_PATH
    mv -f "$ROOT_DIR"_"$SOURCE_DIR".tgz.md5 $STORAGE_PATH

    cd $CURR_PATH
}

function create_xml_and_commit()
{
    if [ -d "$ROOT_DIR/.repo/manifests" ];then
        echo "[ADV] Create XML file"
        cd $ROOT_DIR
        # add revision into xml
        repo manifest -o $VER_TAG.xml -r

        # revise for new branch
        BRANCH_SUFFIX=`echo $META_ADVANTECH_BRANCH | cut -d '_' -f 2`
        BRANCH_ORI="${META_ADVANTECH_BRANCH/_$BRANCH_SUFFIX}"
        sed -i "s/$BRANCH_ORI/$META_ADVANTECH_BRANCH/g" $VER_TAG.xml

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

# ===============================
#  Functions [platform specific]
# ===============================
function get_bsp_tarball()
{
	if [ -e $STORAGE_PATH/${ROOT_DIR}.tgz ] ; then
		tar zxf $STORAGE_PATH/${ROOT_DIR}.tgz
	else
		echo "[ADV] Cannot find BSP tarball"
		exit 1;
	fi
}

function get_csv_info()
{
	IMAGE_DIR="${OFFICIAL_VER}_${CPU_TYPE}_$1_$DATE"
	CSV_FILE="${STORAGE_PATH}/${IMAGE_DIR}.img.csv"

	echo "[ADV] Show HASH in ${CSV_FILE}"
	if [ -e ${CSV_FILE} ] ; then
		HASH_ADVANTECH=`sed "s/meta-advantech, //;t;d" ${CSV_FILE}`
		HASH_KERNEL=`sed "s/linux-imx, //;t;d" ${CSV_FILE}`
		HASH_UBOOT=`sed "s/u-boot-imx, //;t;d" ${CSV_FILE}`

		echo "[ADV] HASH_ADVANTECH : ${HASH_ADVANTECH}"
		echo "[ADV] HASH_KERNEL : ${HASH_KERNEL}"
		echo "[ADV] HASH_UBOOT : ${HASH_UBOOT}"
	else
		echo "[ADV] Cannot find ${CSV_FILE}"
		exit 1;
	fi
}

# ================
#  Main procedure
# ================
define_cpu_type $PRODUCT

echo PRODUCT=$PRODUCT
echo VER_PREFIX=$VER_PREFIX
echo ROOT_DIR=$ROOT_DIR
echo VER_TAG=$VER_TAG

if [ "$PRODUCT" == "$VER_PREFIX" ]; then
	echo "[ADV] get bsp tarball"
	get_bsp_tarball

	echo "[ADV]buildng yocto sdk --> skip"

	echo "[ADV] generate sdk image --> skip"

	rm -rf $ROOT_DIR

else # "$PRODUCT" != "$VER_PREFIX"
	mkdir $ROOT_DIR
	get_source_code

    if [ -z "$EXISTED_VERSION" ] ; then
        # Get info from CSV
        for MEMORY in $MEMORY_LIST;do
            get_csv_info $MEMORY
        done
        # Check meta-advantech tag exist or not, and checkout to tag version
        check_tag_and_checkout $META_ADVANTECH_PATH $META_ADVANTECH_BRANCH $HASH_ADVANTECH

        # Check tag exist or not, and replace bbappend file SRCREV
        check_tag_and_replace $U_BOOT_PATH $U_BOOT_URL $HASH_UBOOT
        check_tag_and_replace $KERNEL_PATH $KERNEL_URL $HASH_KERNEL

        commit_tag_and_rollback $META_ADVANTECH_PATH

        # Add git tag and Package kernel & u-boot
        echo "[ADV] Add tag"
        commit_tag_and_package $U_BOOT_URL $U_BOOT_BRANCH $HASH_UBOOT
        commit_tag_and_package $KERNEL_URL $KERNEL_BRANCH $HASH_KERNEL

        # Create manifests xml and commit
        create_xml_and_commit
    fi
fi

#cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

