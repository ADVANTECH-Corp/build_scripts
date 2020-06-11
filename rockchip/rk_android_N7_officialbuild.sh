#!/bin/bash

VER_PREFIX="rk"


echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST= ${MACHINE_LIST}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"
#echo "[ADV] SCRIPT_XML = ${SCRIPT_XML}"
echo "[ADV] KERNEL_CONFIG = ${KERNEL_CONFIG}"
echo "[ADV] KERNEL_DTB = ${KERNEL_DTB}"
VER_TAG="${VER_PREFIX}AB"$(echo $RELEASE_VERSION | sed 's/[.]//')
echo "[ADV] VER_TAG = $VER_TAG"
CURR_PATH="$PWD"
ROOT_DIR="${VER_PREFIX}AB${RELEASE_VERSION}"_"$DATE"
OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"

#-- Advantech/rk3399 gitlab android source code repository
echo "[ADV-ROOT]  $ROOT_DIR"
echo "[ADV] ANDROID_RKTOOLS_PATH = $CURR_PATH/$ROOT_DIR/RKTools"
echo "[ADV] ANDROID_ABI_PATH = $CURR_PATH/$ROOT_DIR/abi"
echo "[ADV] ANDROID_ART_PATH = $CURR_PATH/$ROOT_DIR/art"
echo "[ADV] ANDROID_BIONIC_PATH = $CURR_PATH/$ROOT_DIR/bionic"
echo "[ADV] ANDROID_BOOTABLE_PATH = $CURR_PATH/$ROOT_DIR/bootable"
echo "[ADV] ANDROID_BUILD_PATH = $CURR_PATH/$ROOT_DIR/build"
echo "[ADV] ANDROID_CTS_PATH = $CURR_PATH/$ROOT_DIR/cts"
echo "[ADV] ANDROID_DALVIK_PATH = $CURR_PATH/$ROOT_DIR/dalvik"
echo "[ADV] ANDROID_DEVELOPERS_PATH = $CURR_PATH/$ROOT_DIR/developers"
echo "[ADV] ANDROID_DEVELOPMENT_PATH = $CURR_PATH/$ROOT_DIR/development"
echo "[ADV] ANDROID_DEVICE_PATH = $CURR_PATH/$ROOT_DIR/device"
echo "[ADV] ANDROID_DOCS_PATH = $CURR_PATH/$ROOT_DIR/docs"
echo "[ADV] ANDROID_EXTERNAL_PATH = $CURR_PATH/$ROOT_DIR/external"
echo "[ADV] ANDROID_FRAMEWORKS_PATH = $CURR_PATH/$ROOT_DIR/frameworks"
echo "[ADV] ANDROID_HARDWARE_PATH = $CURR_PATH/$ROOT_DIR/hardware"
echo "[ADV] ANDROID_KERNEL_PATH = $CURR_PATH/$ROOT_DIR/kernel"
echo "[ADV] ANDROID_LIBCORE_PATH = $CURR_PATH/$ROOT_DIR/libcore"
echo "[ADV] ANDROID_LIBNATIVEHELPER_PATH = $CURR_PATH/$ROOT_DIR/libnativehelper"
echo "[ADV] ANDROID_NDK_PATH = $CURR_PATH/$ROOT_DIR/ndk"
echo "[ADV] ANDROID_PACKAGES_PATH = $CURR_PATH/$ROOT_DIR/packages"
echo "[ADV] ANDROID_PDK_PATH = $CURR_PATH/$ROOT_DIR/pdk"
echo "[ADV] ANDROID_PLATFORM_TESTING_PATH = $CURR_PATH/$ROOT_DIR/platform_testing"
echo "[ADV] ANDROID_PREBUILTS_PATH = $CURR_PATH/$ROOT_DIR/prebuilts"
echo "[ADV] ANDROID_REPO_PATH = $CURR_PATH/$ROOT_DIR/repo"
echo "[ADV] ANDROID_RKST_PATH = $CURR_PATH/$ROOT_DIR/rkst"
echo "[ADV] ANDROID_ROCKDEV_PATH = $CURR_PATH/$ROOT_DIR/rockdev"
echo "[ADV] ANDROID_SDK_PATH = $CURR_PATH/$ROOT_DIR/sdk"
echo "[ADV] ANDROID_SYSTEM_PATH = $CURR_PATH/$ROOT_DIR/system"
echo "[ADV] ANDROID_TOOLCHAIN_PATH = $CURR_PATH/$ROOT_DIR/toolchain"
echo "[ADV] ANDROID_TOOLS_PATH = $CURR_PATH/$ROOT_DIR/tools"
echo "[ADV] ANDROID_UBOOT_PATH = $CURR_PATH/$ROOT_DIR/u-boot"
echo "[ADV] ANDROID_VENDOR_PATH = $CURR_PATH/$ROOT_DIR/vendor"
#--------------------------------------------------
#======================
AND_BSP="android"
AND_BSP_VER="7.1"
AND_VERSION="android_N7.1.2"

#======================

# Make storage folder
if [ -e $OUTPUT_DIR ] ; then
    echo "[ADV] $OUTPUT_DIR had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR"
    mkdir -p $OUTPUT_DIR
fi

# ===========
#  Functions
# ===========
function get_source_code()
{
    echo "[ADV] get android source code"
    mkdir $ROOT_DIR
    cd $ROOT_DIR

    if [ "$BSP_BRANCH" == "" ] ; then
       repo init -u $BSP_URL
    elif [ "$BSP_XML" == "" ] ; then
       repo init -u $BSP_URL -b $BSP_BRANCH
    else
       repo init -u $BSP_URL -b $BSP_BRANCH -m $BSP_XML
    fi
    repo sync

    cd $CURR_PATH
}

function check_tag_and_checkout()
{
        FILE_PATH=$1

        if [ -d "$CURR_PATH/$ROOT_DIR/$FILE_PATH" ];then
                cd $CURR_PATH/$ROOT_DIR/$FILE_PATH
                RESPOSITORY_TAG=`git tag | grep $VER_TAG`
                if [ "$RESPOSITORY_TAG" != "" ]; then
                        echo "[ADV] [FILE_PATH] repository has been tagged ,and check to this $VER_TAG version"
                        REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                        git checkout $VER_TAG
                        #git tag --delete $VER_TAG
                        #git push --delete $REMOTE_SERVER refs/tags/$VER_TAG
                else
                        echo "[ADV] [FILE_PATH] repository isn't tagged ,nothing to do"
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
        REMOTE_BRANCH=$3

        HASH_ID=`git ls-remote $REMOTE_URL $VER_TAG | awk '{print $1}'`
        if [ "$HASH_ID" != "" ]; then
                echo "[ADV] $REMOTE_URL has been tagged ,ID is $HASH_ID"
        else
                HASH_ID=`git ls-remote $REMOTE_URL | grep refs/heads/$REMOTE_BRANCH | awk '{print $1}'`
                echo "[ADV] $REMOTE_URL isn't tagged ,get latest HASH_ID is $HASH_ID"
        fi
        sed -i "s/"\$\{AUTOREV\}"/$HASH_ID/g" $ROOT_DIR/$FILE_PATH
}

function auto_add_tag()
{
        FILE_PATH=$1
        echo "[ADV] $FILE_PATH"
        cd $CURR_PATH
        if [ -d "$FILE_PATH" ];then
                cd $FILE_PATH
				echo "[ADV] get HEAD_HASH_ID"
                HEAD_HASH_ID=`git rev-parse HEAD`
				echo "[ADV] TAG_HASH_ID"
                TAG_HASH_ID=`git tag -v $VER_TAG | grep object | cut -d ' ' -f 2`
                if [ "$HEAD_HASH_ID" == "$TAG_HASH_ID" ]; then
                        echo "[ADV] tag exists! There is no need to add tag"
                else
                        echo "[ADV] Add tag $VER_TAG"
                        REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                        git tag -a $VER_TAG -m "[Official Release] $VER_TAG"
                        git push $REMOTE_SERVER $VER_TAG
                fi
                cd $CURR_PATH
        else
                echo "[ADV] Directory $FILE_PATH doesn't exist"
                exit 1
        fi
}


function update_revision_for_xml()
{
        FILE_PATH=$1
        PROJECT_LIST=`grep "path=" $FILE_PATH`
        XML_PATH="$PWD"

        # Delete old revision
        for PROJECT in $PROJECT_LIST
        do
                REV=`expr ${PROJECT} : 'revision="\([a-zA-Z0-9_.-]*\)"'`
                if [ "$REV" != "" ]; then
                        echo "[ADV] delete revision : $REV"
                        sed -i "s/ revision=\"${REV}\"//g" $FILE_PATH
                fi
        done

        # Add new revision
        for PROJECT in $PROJECT_LIST
        do
                LAYER=`expr ${PROJECT} : 'path="\([a-zA-Z0-9/-]*\)"'`
                if [ "$LAYER" != "" ]; then
                        echo "[ADV] add revision for $LAYER"
                        cd ../../$LAYER
                        HASH_ID=`git rev-parse HEAD`
                        cd $XML_PATH
                        sed -i "s:path=\"${LAYER}\":path=\"${LAYER}\" revision=\"${HASH_ID}\":g" $FILE_PATH
                fi
        done
}

function create_xml_and_commit()
{
        if [ -d "$ROOT_DIR/.repo/manifests" ];then
                echo "[ADV] Create XML file"
                cd $ROOT_DIR/.repo
                cp manifest.xml manifests/$VER_TAG.xml
                cd manifests
				git checkout $BSP_BRANCH

                # add revision into xml
                update_revision_for_xml $VER_TAG.xml

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

    #HASH_BSP=$(cd $CURR_PATH/$ROOT_DIR/.repo/manifests && git rev-parse --short HEAD)
    HASH_ANDROID_RKTOOLS=$(cd $CURR_PATH/$ROOT_DIR/RKTools && git rev-parse --short HEAD)
    HASH_ANDROID_ABI=$(cd $CURR_PATH/$ROOT_DIR/abi && git rev-parse --short HEAD)
    HASH_ANDROID_ART=$(cd $CURR_PATH/$ROOT_DIR/art && git rev-parse --short HEAD)
    HASH_ANDROID_BIONIC=$(cd $CURR_PATH/$ROOT_DIR/bionic && git rev-parse --short HEAD)
    HASH_ANDROID_BOOTABLE=$(cd $CURR_PATH/$ROOT_DIR/bootable && git rev-parse --short HEAD)
    HASH_ANDROID_BUILD=$(cd $CURR_PATH/$ROOT_DIR/build && git rev-parse --short HEAD)
    HASH_ANDROID_CTS=$(cd $CURR_PATH/$ROOT_DIR/cts && git rev-parse --short HEAD) 
    HASH_ANDROID_DALVIK=$(cd $CURR_PATH/$ROOT_DIR/dalvik && git rev-parse --short HEAD)
    HASH_ANDROID_DEVELOPERS=$(cd $CURR_PATH/$ROOT_DIR/developers && git rev-parse --short HEAD)
    HASH_ANDROID_DEVELOPMENT=$(cd $CURR_PATH/$ROOT_DIR/development && git rev-parse --short HEAD)
    HASH_ANDROID_DEVICE=$(cd $CURR_PATH/$ROOT_DIR/device && git rev-parse --short HEAD)
    HASH_ANDROID_DOCS=$(cd $CURR_PATH/$ROOT_DIR/docs && git rev-parse --short HEAD)
    HASH_ANDROID_EXTERNAL=$(cd $CURR_PATH/$ROOT_DIR/external && git rev-parse --short HEAD)
    HASH_ANDROID_FRAMEWORKS=$(cd $CURR_PATH/$ROOT_DIR/frameworks && git rev-parse --short HEAD)
    HASH_ANDROID_HARDWARE=$(cd $CURR_PATH/$ROOT_DIR/hardware && git rev-parse --short HEAD)
    HASH_ANDROID_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/kernel && git rev-parse --short HEAD)
    HASH_ANDROID_LIBCORE=$(cd $CURR_PATH/$ROOT_DIR/libcore && git rev-parse --short HEAD)
    HASH_ANDROID_LIBNATIVEHELPER=$(cd $CURR_PATH/$ROOT_DIR/libnativehelper && git rev-parse --short HEAD)
    HASH_ANDROID_NDK=$(cd $CURR_PATH/$ROOT_DIR/ndk && git rev-parse --short HEAD)
    HASH_ANDROID_PACKAGES=$(cd $CURR_PATH/$ROOT_DIR/packages && git rev-parse --short HEAD)
    HASH_ANDROID_PDK=$(cd $CURR_PATH/$ROOT_DIR/pdk && git rev-parse --short HEAD)
    HASH_ANDROID_PLATFORM_TESTING=$(cd $CURR_PATH/$ROOT_DIR/platform_testing && git rev-parse --short HEAD)
    HASH_ANDROID_PREBUILTS=$(cd $CURR_PATH/$ROOT_DIR/prebuilts && git rev-parse --short HEAD)
    HASH_ANDROID_REPO=$(cd $CURR_PATH/$ROOT_DIR/repo && git rev-parse --short HEAD)
    HASH_ANDROID_RKST=$(cd $CURR_PATH/$ROOT_DIR/rkst && git rev-parse --short HEAD)
    HASH_ANDROID_SDK=$(cd $CURR_PATH/$ROOT_DIR/sdk && git rev-parse --short HEAD)
    HASH_ANDROID_SYSTEM=$(cd $CURR_PATH/$ROOT_DIR/system && git rev-parse --short HEAD)
    HASH_ANDROID_TOOLCHAIN=$(cd $CURR_PATH/$ROOT_DIR/toolchain && git rev-parse --short HEAD)
    HASH_ANDROID_TOOLS=$(cd $CURR_PATH/$ROOT_DIR/tools && git rev-parse --short HEAD)
    HASH_ANDROID_UBOOT=$(cd $CURR_PATH/$ROOT_DIR/u-boot && git rev-parse --short HEAD)
    HASH_ANDROID_VENDOR=$(cd $CURR_PATH/$ROOT_DIR/vendor && git rev-parse --short HEAD)
    cd $CURR_PATH


    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Android 7.1.1
Part Number,N/A
Author,
Date,${DATE}
Build Number,${BUILD_NUMBER}
TAG,
Tested Platform,${NEW_MACHINE}
MD5 Checksum,TGZ: ${MD5_SUM}
Image Size,${FILE_SIZE}B (${FILE_SIZE_BYTE} bytes)
Issue description, N/A
Function Addition,
Android-manifest, ${HASH_BSP}

ANDROID_RKTOOLS, ${HASH_ANDROID_RKTOOLS}
ANDROID_ABI, ${HASH_ANDROID_ABI}
ANDROID_ART, ${HASH_ANDROID_ART}
ANDROID_BIONIC, ${HASH_ANDROID_BIONIC}
ANDROID_BOOTABLE, ${HASH_ANDROID_BOOTABLE}
ANDROID_BUILD, ${HASH_ANDROID_BUILD}
ANDROID_CTS, ${HASH_ANDROID_CTS}
ANDROID_DALVIK, ${HASH_ANDROID_DALVIK}
ANDROID_DEVELOPERS, ${HASH_ANDROID_DEVELOPERS}
ANDROID_DEVELOPMENT, ${HASH_ANDROID_DEVELOPMENT}
ANDROID_DEVICE, ${HASH_ANDROID_DEVICE}
ANDROID_DOCS, ${HASH_ANDROID_DOCS}
ANDROID_EXTERNAL, ${HASH_ANDROID_EXTERNAL}
ANDROID_FRAMEWORKS, ${HASH_ANDROID_FRAMEWORKS}
ANDROID_HARDWARE, ${HASH_ANDROID_HARDWARE}
ANDROID_KERNEL, ${HASH_ANDROID_KERNEL}
ANDROID_LIBCORE, ${HASH_ANDROID_LIBCORE}
ANDROID_LIBNATIVEHELPER, ${HASH_ANDROID_LIBNATIVEHELPER}
ANDROID_NDK, ${HASH_ANDROID_NDK}
ANDROID_PACKAGES, ${HASH_ANDROID_PACKAGES}
ANDROID_PDK, ${HASH_ANDROID_PDK}
ANDROID_PLATFORM_TESTING, ${HASH_ANDROID_PLATFORM_TESTING}
ANDROID_PREBUILTS, ${HASH_ANDROID_PREBUILTS}
ANDROID_REPO, ${HASH_ANDROID_REPO}
ANDROID_RKST, ${HASH_ANDROID_RKST}
ANDROID_SDK, ${HASH_ANDROID_SDK}
ANDROID_SYSTEM, ${HASH_ANDROID_SYSTEM}
ANDROID_TOOLCHAIN, ${HASH_ANDROID_TOOLCHAIN}
ANDROID_TOOLS, ${HASH_ANDROID_TOOLS}
ANDROID_UBOOT, ${HASH_ANDROID_UBOOT}
ANDROID_VENDOR, ${HASH_ANDROID_VENDOR}

END_OF_CSV
}

function save_temp_log()
{
    LOG_PATH="$CURR_PATH/$ROOT_DIR"
    cd $LOG_PATH

    LOG_DIR="AI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"_log
    echo "[ADV] mkdir $LOG_DIR"
    mkdir $LOG_DIR

    # Backup conf, run script & log file
    cp -a *.log $LOG_DIR

    echo "[ADV] creating ${LOG_DIR}.tgz ..."
    tar czf $LOG_DIR.tgz $LOG_DIR
    generate_md5 $LOG_DIR.tgz

    mv -f $LOG_DIR.tgz $OUTPUT_DIR
    mv -f $LOG_DIR.tgz.md5 $OUTPUT_DIR

    # Remove all temp logs
    rm -rf $LOG_DIR
}

function building()
{
    echo "[ADV] building $1 ..."
    LOG_FILE="$NEW_MACHINE"_Build.log
    LOG2_FILE="$NEW_MACHINE"_Build2.log
    LOG3_FILE="$NEW_MACHINE"_Build3.log

    if [ "$1" == "uboot" ]; then
        echo "[ADV] build uboot"
		cd $CURR_PATH/$ROOT_DIR/u-boot
		make clean
		make rk3399_box_defconfig
		make ARCHV=aarch64 -j12 2>> $CURR_PATH/$ROOT_DIR/$LOG_FILE
	elif [ "$1" == "kernel" ]; then
		echo "[ADV] build kernel  = $KERNEL_CONFIG"
		cd $CURR_PATH/$ROOT_DIR/kernel
		make distclean
		make ARCH=arm64 $KERNEL_CONFIG
		make ARCH=arm64 $KERNEL_DTB -j16 >> $CURR_PATH/$ROOT_DIR/$LOG2_FILE
    elif [ "$1" == "android" ]; then
		echo "[ADV] build android"
		cd $CURR_PATH/$ROOT_DIR
		source build/envsetup.sh
		if [ ${MACHINE_LIST} == "ds211" ]; then
			lunch ds211_box-userdebug
		else
			lunch rk3399_box-userdebug
		fi
		make clean
		make -j4 2>> $CURR_PATH/$ROOT_DIR/$LOG3_FILE
	else
    echo "[ADV] pass building..."
    fi
    [ "$?" -ne 0 ] && echo "[ADV] Build failure! Check log file '$LOG_FILE'" && exit 1
}

function set_environment()
{
    echo "[ADV] set environment"
    cd $CURR_PATH/$ROOT_DIR
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/
	export PATH=$JAVA_HOME/bin:$PATH
	export CLASSPATH=.:$JAVA_HOME/lib:$JAVA_HOME/lib/tools.jar
}

function build_android_images()
{
    cd $CURR_PATH/$ROOT_DIR

	set_environment
    # Android 
	building uboot
	building kernel
	building android
    # package image to rockdev folder
    ./mkimage.sh
}

function prepare_images()
{
    cd $CURR_PATH

    IMAGE_DIR="AI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR

    # Copy image files to image directory


	cp -a $CURR_PATH/$ROOT_DIR/rockdev/* $IMAGE_DIR

    echo "[ADV] creating ${IMAGE_DIR}.tgz ..."
    tar czf ${IMAGE_DIR}.tgz $IMAGE_DIR
    generate_md5 ${IMAGE_DIR}.tgz
    #rm -rf $IMAGE_DIR
}

function copy_image_to_storage()
{
    echo "[ADV] copy images to $OUTPUT_DIR"

    generate_csv ${IMAGE_DIR}.tgz
    mv ${IMAGE_DIR}.csv $OUTPUT_DIR

    mv -f ${IMAGE_DIR}.tgz $OUTPUT_DIR
    mv -f *.md5 $OUTPUT_DIR

}
# ================
#  Main procedure 
# ================
#if [ "$PRODUCT" == "$VER_PREFIX" ]; then
    mkdir $ROOT_DIR
    get_source_code

	echo "[ADV] check_tag_and_checkout"
    check_tag_and_checkout $ANDROID_RKTOOLS_PATH
    check_tag_and_checkout $ANDROID_ABI_PATH
    check_tag_and_checkout $ANDROID_ART_PATH
    check_tag_and_checkout $ANDROID_BIONIC_PATH
    check_tag_and_checkout $ANDROID_BOOTABLE_PATH
    check_tag_and_checkout $ANDROID_BUILD_PATH
    check_tag_and_checkout $ANDROID_CTS_PATH
    check_tag_and_checkout $ANDROID_DALVIK_PATH
    check_tag_and_checkout $ANDROID_DEVELOPERS_PATH
    check_tag_and_checkout $ANDROID_DEVELOPMENT_PATH
	check_tag_and_checkout $ANDROID_DEVICE_PATH
	check_tag_and_checkout $ANDROID_DOCS_PATH
    check_tag_and_checkout $ANDROID_EXTERNAL_PATH
    check_tag_and_checkout $ANDROID_FRAMEWORKS_PATH
    check_tag_and_checkout $ANDROID_HARDWARE_PATH
    check_tag_and_checkout $ANDROID_KERNEL_PATH
    check_tag_and_checkout $ANDROID_LIBCORE_PATH
    check_tag_and_checkout $ANDROID_LIBNATIVEHELPER_PATH
    check_tag_and_checkout $ANDROID_NDK_PATH
    check_tag_and_checkout $ANDROID_PACKAGES_PATH
    check_tag_and_checkout $ANDROID_PDK_PATH
    check_tag_and_checkout $ANDROID_PLATFORM_TESTING_PATH
    check_tag_and_checkout $ANDROID_PREBUILTS_PATH
    check_tag_and_checkout $ANDROID_REPO_PATH
    check_tag_and_checkout $ANDROID_RKST_PATH
    check_tag_and_checkout $ANDROID_SDK_PATH
    check_tag_and_checkout $ANDROID_SYSTEM_PATH
    check_tag_and_checkout $ANDROID_TOOLCHAIN_PATH
    check_tag_and_checkout $ANDROID_TOOLS_PATH
    check_tag_and_checkout $ANDROID_UBOOT_PATH
    check_tag_and_checkout $ANDROID_VENDOR_PATH



# Add git tag
	echo "[ADV] Add tag"
    auto_add_tag $CURR_PATH/$ROOT_DIR/RKTools
    auto_add_tag $CURR_PATH/$ROOT_DIR/abi
    auto_add_tag $CURR_PATH/$ROOT_DIR/art
    auto_add_tag $CURR_PATH/$ROOT_DIR/bionic
    auto_add_tag $CURR_PATH/$ROOT_DIR/bootable
    auto_add_tag $CURR_PATH/$ROOT_DIR/build
    auto_add_tag $CURR_PATH/$ROOT_DIR/cts
    auto_add_tag $CURR_PATH/$ROOT_DIR/dalvik
    auto_add_tag $CURR_PATH/$ROOT_DIR/developers
    auto_add_tag $CURR_PATH/$ROOT_DIR/development
	auto_add_tag $CURR_PATH/$ROOT_DIR/device
	auto_add_tag $CURR_PATH/$ROOT_DIR/docs
    auto_add_tag $CURR_PATH/$ROOT_DIR/external
    auto_add_tag $CURR_PATH/$ROOT_DIR/frameworks
    auto_add_tag $CURR_PATH/$ROOT_DIR/hardware
    auto_add_tag $CURR_PATH/$ROOT_DIR/kernel
    auto_add_tag $CURR_PATH/$ROOT_DIR/libcore
    auto_add_tag $CURR_PATH/$ROOT_DIR/libnativehelper    
    auto_add_tag $CURR_PATH/$ROOT_DIR/ndk
    auto_add_tag $CURR_PATH/$ROOT_DIR/packages
    auto_add_tag $CURR_PATH/$ROOT_DIR/pdk
    auto_add_tag $CURR_PATH/$ROOT_DIR/platform_testing
    auto_add_tag $CURR_PATH/$ROOT_DIR/prebuilts
    auto_add_tag $CURR_PATH/$ROOT_DIR/repo
    auto_add_tag $CURR_PATH/$ROOT_DIR/rkst
    auto_add_tag $CURR_PATH/$ROOT_DIR/sdk
    auto_add_tag $CURR_PATH/$ROOT_DIR/system
    auto_add_tag $CURR_PATH/$ROOT_DIR/toolchain
    auto_add_tag $CURR_PATH/$ROOT_DIR/tools
    auto_add_tag $CURR_PATH/$ROOT_DIR/u-boot
    auto_add_tag $CURR_PATH/$ROOT_DIR/vendor


   # Create manifests xml and commit
	echo "[ADV] create_xml_and_commit"
    create_xml_and_commit

echo "[ADV] build images"

for NEW_MACHINE in $MACHINE_LIST
do
echo "[ADV] NEW_MACHINE = $NEW_MACHINE"
	build_android_images
#echo "[ADV] prepare_images"
	prepare_images
#echo "[ADV] copy_image_to_storage"
	copy_image_to_storage
	save_temp_log
done

cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

