#!/bin/bash

ADV_PATH="\
foundation \
kernel \
. \
test \
docs \
"

VER_PREFIX="RK3568_OH5.0_"

idx=0
isFirstMachine="true"

for i in $MACHINE_LIST
do
    let idx=$idx+1
    NEW_MACHINE=$i
done

if [ $idx -gt 1 ];then
    isFirstMachine="false"
fi

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"

echo "[ADV] openharmony_PRODUCT = ${openharmony_PRODUCT}"
VER_TAG="${VER_PREFIX}OIV"$(echo $RELEASE_VERSION | sed 's/[.]//')
echo "[ADV] VER_TAG = $VER_TAG"
echo "[ADV] isFirstMachine = $isFirstMachine"
CURR_PATH="$PWD"
ROOT_DIR="${VER_TAG}"_"$DATE"
SUB_DIR="OpenHarmony5.0.2"
OUTPUT_DIR="$CURR_PATH/$STORED/$DATE/V"$(echo $RELEASE_VERSION | sed 's/[.]//')


echo "[ADV-ROOT]  $ROOT_DIR"
for TEMP_PATH in ${ADV_PATH}
do
	echo "[ADV] ${TEMP_PATH} = $CURR_PATH/$ROOT_DIR/${TEMP_PATH}"
done
#--------------------------------------------------
#======================
AND_BSP="openharmony"
AND_BSP_VER="5.0"
AND_VERSION="openharmony_5.0"

#======================

# Make storage folder
if [ -e $OUTPUT_DIR ] ; then
    echo "[ADV] $OUTPUT_DIR had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR"
    mkdir -p $OUTPUT_DIR
fi

if [ -e $OUTPUT_DIR/${MODEL_NAME}/image ] ; then
    echo "[ADV] $OUTPUT_DIR/${MODEL_NAME}/image  had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR/${MODEL_NAME}/image"
    mkdir -p $OUTPUT_DIR/${MODEL_NAME}/image
fi

if [ -e $OUTPUT_DIR/${MODEL_NAME}/others ] ; then
    echo "[ADV] $OUTPUT_DIR/${MODEL_NAME}/others  had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR/${MODEL_NAME}/others"
    mkdir -p $OUTPUT_DIR/${MODEL_NAME}/others
fi

# ===========
#  Functions
# ===========


function check_tag_and_checkout()
{
    for TEMP_PATH in ${ADV_PATH}
    do
	cd $CURR_PATH/$ROOT_DIR/$SUB_DIR
        if [ -d "${TEMP_PATH}" ];then
            cd ${TEMP_PATH}
            RESPOSITORY_TAG=`git tag | grep $VER_TAG`
            if [ "$RESPOSITORY_TAG" != "" ]; then
                echo "[ADV] [${TEMP_PATH}] repository has been tagged ,and check to this $VER_TAG version"
                REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                git checkout $VER_TAG
            else
                echo "[ADV] [${TEMP_PATH}] repository isn't tagged ,nothing to do"
            fi
            
        else
            echo "[ADV] Directory ${TEMP_PATH} doesn't exist"
        fi
    done

    cd $CURR_PATH
}

function auto_add_tag()
{
    for TEMP_PATH in ${ADV_PATH}
    do
	cd $CURR_PATH/$ROOT_DIR/$SUB_DIR
        if [ -d "${TEMP_PATH}" ];then
            cd ${TEMP_PATH}
            HEAD_HASH_ID=`git rev-parse HEAD`
            TAG_HASH_ID=`git tag -v $VER_TAG | grep object | cut -d ' ' -f 2`
            REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
            if [ "$HEAD_HASH_ID" == "$TAG_HASH_ID" ]; then
                echo "[ADV] tag exists! There is no need to add tag"
            else
                git tag -a $VER_TAG -m "[Official Release] $VER_TAG"
                git push $REMOTE_SERVER $VER_TAG
            fi
            
        else
            echo "[ADV] Directory ${TEMP_PATH} doesn't exist"
        fi
    done

    cd $CURR_PATH
}

function create_xml_and_commit()
{
    cd $CURR_PATH
    if [ -d "$ROOT_DIR/.repo/manifests" ];then
        echo "[ADV] Create XML file"
        cd $ROOT_DIR
        # add revision into xml
        ../repo manifest -o $VER_TAG.xml -r
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

function generate_md5()
{
    FILENAME=$1

    if [ -e $FILENAME ]; then
        MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
        echo $MD5_SUM > $FILENAME.md5
    fi
}

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

    cd $CURR_PATH

    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS, openharmony 5.0 
Part Number, N/A
Author,
Date, ${DATE}
Build Number, ${BUILD_NUMBER}
TAG,
Tested Platform, ${NEW_MACHINE}
MD5 Checksum,TGZ: ${MD5_SUM}
Image Size, ${FILE_SIZE}B (${FILE_SIZE_BYTE} bytes)
Issue description, N/A
Function Addition,
openharmony-manifest, ${HASH_BSP}

END_OF_CSV

    for TEMP_PATH in ${ADV_PATH}
    do
        HASH_openharmony=$(cd $CURR_PATH/$ROOT_DIR/$SUB_DIR/$TEMP_PATH && git rev-parse --short HEAD)
	    echo "${TEMP_PATH}, ${HASH_openharmony}" >> ${FILENAME%.*}.csv
    done
	
	cd $CURR_PATH
}

function generate_manifest()
{
    cd $CURR_PATH/$ROOT_DIR/
    ../repo manifest -o ${VER_TAG}.xml -r
}

function save_temp_log()
{
    LOG_PATH="$CURR_PATH/$ROOT_DIR/$SUB_DIR"
    cd $LOG_PATH

    LOG_DIR="${VER_TAG}"_"$NEW_MACHINE"_"$DATE"_log
    echo "[ADV] mkdir $LOG_DIR"
    mkdir $LOG_DIR

    # Backup conf, run script & log file
    cp -a "$NEW_MACHINE"_Build*.log $LOG_DIR

    echo "[ADV] creating ${LOG_DIR}.tgz ..."
    tar czf $LOG_DIR.tgz $LOG_DIR
    generate_md5 $LOG_DIR.tgz

    mv -f $LOG_DIR.tgz $OUTPUT_DIR/${MODEL_NAME}/others
    mv -f $LOG_DIR.tgz.md5 $OUTPUT_DIR/${MODEL_NAME}/others

    # Remove all temp logs
    rm -rf $LOG_DIR
}

function get_source_code()
{
    echo "[ADV] get openharmony source code"
    cd $CURR_PATH

    curl https://storage.googleapis.com/git-repo-downloads/repo > repo
    chmod 777 repo

    mkdir $ROOT_DIR
    cd $ROOT_DIR

    if [ "$BSP_BRANCH" == "" ] ; then
       ../repo init -u $BSP_URL
    elif [ "$BSP_XML" == "" ] ; then
       ../repo init -u $BSP_URL -b $BSP_BRANCH
    else
       ../repo init -u $BSP_URL -b $BSP_BRANCH -m $BSP_XML
    fi
    ../repo sync

    for TEMP_PATH in ${ADV_PATH}
    do
        cd $CURR_PATH/$ROOT_DIR/$SUB_DIR/
        if [ -d "${TEMP_PATH}" ];then
            cd ${TEMP_PATH}
		    REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
		    git checkout -b local --track $REMOTE_SERVER/$BSP_BRANCH
        else
            echo "[ADV] Directory ${TEMP_PATH} doesn't exist"
        fi
    done

    cd $CURR_PATH
    
    tar zxvf third_party.tar.gz -C $CURR_PATH/$ROOT_DIR/$SUB_DIR
}

function building()
{
    echo "[ADV] building $1 ..."
    LOG_FILE="$NEW_MACHINE"_Build.log

    LOG_FILE_openharmony="$NEW_MACHINE"_Build_openharmony.log

    if [ "$1" == "openharmony" ]; then
	 echo "[ADV] build openharmony openharmony_PRODUCT=$openharmony_PRODUCT"
        ./build/prebuilts_download.sh
        $CURR_PATH/$ROOT_DIR/$SUB_DIR/prebuilts/python/linux-x86/current/bin/python3 -m pip install --upgrade pip
        ./build.sh –product-name $openharmony_PRODUCT --ccache 2>> $CURR_PATH/$ROOT_DIR/$LOG_FILE_openharmony
    else
        echo "[ADV] pass building..."
    fi
    [ "$?" -ne 0 ] && echo "[ADV] Build failure! Check log file '$LOG_FILE'" && exit 1
}

function set_environment()
{
    echo "[ADV] set environment"
    cd $CURR_PATH/$ROOT_DIR/$SUB_DIR/
    apt-get install -y apt-utils binutils bison flex bc build-essential make mtd-utils gcc-arm-linux-gnueabi u-boot-tools python3.9 python3-pip git zip unzip curl wget gcc g++ ruby dosfstools mtools default-jre default-jdk scons python3-distutils perl openssl libssl-dev cpio git-lfs m4 ccache zlib1g-dev tar rsync liblz4-tool genext2fs binutils-dev device-tree-compiler e2fsprogs git-core gnupg gnutls-bin gperf lib32ncurses5-dev libffi-dev zlib* libelf-dev libx11-dev libgl1-mesa-dev lib32z1-dev xsltproc x11proto-core-dev libc6-dev-i386 libxml2-dev lib32z-dev libdwarf-dev
 
    apt-get install -y grsync xxd libglib2.0-dev libpixman-1-dev kmod jfsutils reiserfsprogs xfsprogs squashfs-tools  pcmciautils quota ppp libtinfo-dev libtinfo5 libncurses5 libncurses5-dev libncursesw5 libstdc++6  gcc-arm-none-eabi vim ssh locales doxygen
 
    apt-get install -y libxinerama-dev libxcursor-dev libxrandr-dev libxi-dev
 
    pip3 install --trusted-host https://repo.huaweicloud.com -i https://repo.huaweicloud.com/repository/pypi/simple requests setuptools pymongo kconfiglib pycryptodome ecdsa ohos-build pyyaml prompt_toolkit==1.0.14 redis json2html yagmail python-jenkins
 
    pip3 install esdk-obs-python --trusted-host pypi.org
 
    pip3 install six --upgrade --ignore-installed six
}

function build_openharmony_images()
{
    cd $CURR_PATH/$ROOT_DIR/$SUB_DIR
    set_environment
    building openharmony
}


function prepare_images()
{
    cd $CURR_PATH
    IMAGE_DIR="${VER_TAG}"_"$NEW_MACHINE"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR

    mkdir -p $IMAGE_DIR/image

    # Copy image files to image directory
    cp -aRL $CURR_PATH/$ROOT_DIR/$SUB_DIR/out/$openharmony_PRODUCT/packages/phone/images/* $IMAGE_DIR/image

    echo "[ADV] creating ${IMAGE_DIR}.tgz ..."
    tar czf ${IMAGE_DIR}.tgz $IMAGE_DIR
    generate_md5 ${IMAGE_DIR}.tgz
}

function copy_image_to_storage()
{
    echo "[ADV] copy images to $OUTPUT_DIR"
	if [ $isFirstMachine == "true" ]; then
	    generate_manifest
	    mv ${VER_TAG}.xml $OUTPUT_DIR
	fi

    generate_csv ${IMAGE_DIR}.tgz
    mv ${IMAGE_DIR}.csv $OUTPUT_DIR/${MODEL_NAME}/others

    mv -f ${IMAGE_DIR}.tgz $OUTPUT_DIR/${MODEL_NAME}/image
    mv -f ${IMAGE_DIR}.tgz.md5 $OUTPUT_DIR/${MODEL_NAME}/image

}

# ================
#  Main procedure 
# ================
if [ $isFirstMachine == "true" ]; then
    get_source_code
    check_tag_and_checkout
fi
build_openharmony_images
prepare_images
copy_image_to_storage
save_temp_log
if [ $isFirstMachine == "true" ]; then
	create_xml_and_commit
	auto_add_tag
fi

echo "[ADV] build script done!"

