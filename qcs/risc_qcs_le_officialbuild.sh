#!/bin/bash
PRODUCT=$1

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
echo "[ADV] VER_TAG = ${VER_TAG}"
echo "[ADV] Release_Note = ${Release_Note}"

if [ ${#PROJECT} -ne 9 ]; then
    echo "${PROJECT} project is not 9 characters"
    exit 1
fi

if [ ${#OS_BSP} -ne 1 ]; then
    echo "${OS_BSP} os bsp is not 1 character"
    exit 1
fi

if [ ${#DISTRO} -ne 4 ]; then
    echo "${DISTRO} distro is not 4 characters"
    exit 1
fi

if [ ${#RELEASE_VERSION} -ne 2 ]; then
    echo "${RELEASE_VERSION} version is not 2 characters"
    exit 1
fi

if [ ${#KERNEL_VERSION} -ne 8 ]; then
    echo "${KERNEL_VERSION} kernel version is not 8 characters"
    exit 1
fi

if [ ${#CHIP_NAME} -ne 5 ]; then
    echo "${CHIP_NAME} chip name is not 5 characters"
    exit 1
fi

if [ ${#RAM_SIZE} -ne 3 ]; then
    echo "${RAM_SIZE} ram size is not 3 characters"
    exit 1
fi

CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${TARGET_BOARD}_${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
VER_TAG="${PROJECT}_${OS_BSP}${DISTRO}${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}"
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
    echo "[ADV] get source code"
    cd $CURR_PATH/$ROOT_DIR

    do_repo_init

    EXISTED_VERSION=`find .repo/manifests -name ${VER_TAG}.xml`
    if [ -z "$EXISTED_VERSION" ] ; then
        echo "[ADV] This is a new VERSION"
        repo sync
    else
        echo "[ADV] $RELEASE_VERSION already exists!"
	exit 1
    fi
}

function get_csv_info()
{
    echo "[ADV] get csv info"
    CSV_FILE=${CURR_PATH}/${PLATFORM_PREFIX}/${DATE}/${VER_TAG}_${DATE}.csv

    echo "[ADV] Show HASH in ${CSV_FILE}"
    if [ -e ${CSV_FILE} ] ; then
        HASH_MANIFEST=`cat ${CSV_FILE} | grep "Manifest" | cut -d ',' -f 2`
        HASH_AMSS=`cat ${CSV_FILE} | grep "AMSS" | cut -d ',' -f 2`
        HASH_DOWNLOAD=`cat ${CSV_FILE} | grep "DOWNLOAD" | cut -d ',' -f 2`
        HASH_KERNEL=`cat ${CSV_FILE} | grep "QCS_LINUX_QCOM" | cut -d ',' -f 2`
        HASH_META_ADVANTECH=`cat ${CSV_FILE} | grep "META_ADVANTECH" | cut -d ',' -f 2`
        HASH_META_QCOM_EXTRAS=`cat ${CSV_FILE} | grep "META_QCOM_EXTRAS" | cut -d ',' -f 2`
        HASH_META_QCOM_ROBOTICS_EXTRAS=`cat ${CSV_FILE} | grep "META_QCOM_ROBOTICS_EXTRAS" | cut -d ',' -f 2`
        HASH_SCRIPTS=`cat ${CSV_FILE} | grep "SCRIPTS" | cut -d ',' -f 2`

        echo "[ADV] HASH_MANIFEST : ${HASH_MANIFEST}"
        echo "[ADV] HASH_AMSS : ${HASH_AMSS}"
        echo "[ADV] HASH_DOWNLOAD : ${HASH_DOWNLOAD}"
        echo "[ADV] HASH_KERNEL : ${HASH_KERNEL}"
        echo "[ADV] HASH_META_ADVANTECH : ${HASH_META_ADVANTECH}"
        echo "[ADV] HASH_META_QCOM_EXTRAS : ${HASH_META_QCOM_EXTRAS}"
        echo "[ADV] HASH_META_QCOM_ROBOTICS_EXTRAS : ${HASH_META_QCOM_ROBOTICS_EXTRAS}"
        echo "[ADV] HASH_SCRIPTS : ${HASH_SCRIPTS}"
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

    git clone $AIM_LINUX_RELEASE_BSP_URL -b ${DISTRO}
    pushd $AIM_LINUX_RELEASE_BSP_PLATFORM

    EXISTED_VERSION=`find . -name ${VER_TAG}.xml`
    if [ -z "$EXISTED_VERSION" ] ; then
       	echo "[ADV] This is a new VERSION"
        # push to github
	cp $CURR_PATH/$ROOT_DIR/.repo/manifests/$VER_TAG.xml .
        git add $VER_TAG.xml
        git commit -m "[Official Release] ${VER_TAG}"
        git push
    else
        echo "[ADV] $RELEASE_VERSION already exists!"
	exit 1
    fi
}

function copy_dailybuild_files()
{
    echo "[ADV] copy dailybuild files to $OUTPUT_DIR"

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

    echo "[ADV] Add tag"
    commit_tag amss $BSP_BRANCH $HASH_AMSS
    commit_tag download $BSP_BRANCH $HASH_DOWNLOAD
    commit_tag layers/meta-qcom-extras $BSP_BRANCH $HASH_META_QCOM_EXTRAS
    commit_tag layers/meta-qcom-robotics-extras $BSP_BRANCH $HASH_META_QCOM_ROBOTICS_EXTRAS
    commit_tag scripts $BSP_BRANCH $HASH_SCRIPTS

    if [ "${DISTRO}" == "l011" ] ; then
        commit_tag layers/meta-advantech $BSP_BRANCH $HASH_META_ADVANTECH
    else
        # Check meta-advantech tag exist or not, and checkout to tag version
        check_tag_and_checkout layers/meta-advantech $BSP_BRANCH $HASH_META_ADVANTECH

        # Check tag exist or not, and replace bbappend file SRCREV
        check_tag_and_replace $KERNEL_PATH/linux-kernel-headers-install_%.bbappend $KERNEL_URL $HASH_KERNEL
        check_tag_and_replace $KERNEL_PATH/linux-kernel-qcom-headers_%.bbappend $KERNEL_URL $HASH_KERNEL
        check_tag_and_replace $KERNEL_PATH/linux-qcom-custom_%.bbappend $KERNEL_URL $HASH_KERNEL

        commit_tag_and_rollback layers/meta-advantech

        # Add git tag and Package kernel
        echo "[ADV] Add kernel tag and Package kernel"
        commit_tag_and_package $KERNEL_URL $BSP_BRANCH $HASH_KERNEL
    fi

    # Create manifests xml and commit
    create_xml_and_commit

    # Create AIM_Linux_Release xml file
    create_aim_linux_release_xml

    rm -rf $ROOT_DIR
fi

echo "[ADV] copy dailybuild files"
copy_dailybuild_files

echo "[ADV] build script done!"
