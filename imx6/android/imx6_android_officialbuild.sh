#!/bin/bash

VER_PREFIX="imx6"


echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST= ${MACHINE_LIST}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"
#echo "[ADV] SCRIPT_XML = ${SCRIPT_XML}"
#echo "[ADV] KERNEL_VERSION = ${KERNEL_VERSION}"
echo "[ADV] KERNEL_URL = ${KERNEL_URL}"
echo "[ADV] KERNEL_BRANCH = ${KERNEL_BRANCH}"
echo "[ADV] KERNEL_PATH = ${KERNEL_PATH}"
#echo "[ADV] UBOOT_VERSION = ${UBOOT_VERSION}"
echo "[ADV] UBOOT_URL = ${UBOOT_URL}"
echo "[ADV] UBOOT_BRANCH = ${UBOOT_BRANCH}"
echo "[ADV] UBOOT_PATH = ${UBOOT_PATH}"



VER_TAG="${VER_PREFIX}AB"$(echo $RELEASE_VERSION | sed 's/[.]//')
echo "[ADV] VER_TAG = $VER_TAG"



CURR_PATH="$PWD"
ROOT_DIR="${VER_PREFIX}AB${RELEASE_VERSION}"_"$DATE"
OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"


#-- Advantech github android source code repository
echo "[ADV-ROOT]  $ROOT_DIR"
echo "[ADV] ANDROID_BUILD_PATH = $CURR_PATH/$ROOT_DIR/build"
echo "[ADV] ANDROID_BIONIC_PATH = $CURR_PATH/$ROOT_DIR/bionic"
echo "[ADV] ANDROID_BOOTABLE_PATH = $CURR_PATH/$ROOT_DIR/bootable"
echo "[ADV] ANDROID_DEVICE_PATH = $CURR_PATH/$ROOT_DIR/device"
echo "[ADV] ANDROID_HARDWARE_PATH = $CURR_PATH/$ROOT_DIR/hardware"
echo "[ADV] ANDROID_LIBCORE_PATH = $CURR_PATH/$ROOT_DIR/libcore"
echo "[ADV] ANDROID_PACKAGES_PATH = $CURR_PATH/$ROOT_DIR/packages"
echo "[ADV] ANDROID_SYSTEM_PATH = $CURR_PATH/$ROOT_DIR/system"
echo "[ADV] ANDROID_EXTERNAL_PATH = $CURR_PATH/$ROOT_DIR/external"
echo "[ADV] ANDROID_FRAMEWORKS_PATH = $CURR_PATH/$ROOT_DIR/frameworks"
echo "[ADV] ANDROID_PREBUILTS = $CURR_PATH/$ROOT_DIR/prebuilts"
echo "[ADV] ANDROID_VENDOR = $CURR_PATH/$ROOT_DIR/vendor"
#--------------------------------------------------
echo "[ADV] ANDROID_BUILD_URL = ${ANDROID_BUILD_URL}"
echo "[ADV] ANDROID_PATCH = $CURR_PATH/$ROOT_DIR/patches_android_6.0.1"



#======================
AND_BSP="android"
AND_BSP_VER="6.0"
AND_VERSION="android_M6.0.1_2.1.0"

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
........echo "[ADV] $FILE_PATH"
........cd $CURR_PATH
        if [ -d "$FILE_PATH" ];then
                cd $FILE_PATH
                HEAD_HASH_ID=`git rev-parse HEAD`
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

    HASH_BSP=$(cd $CURR_PATH/$ROOT_DIR/.repo/manifests && git rev-parse --short HEAD)
    HASH_UBOOT=$(cd $CURR_PATH/$ROOT_DIR/bootable/bootloader/uboot-imx && git rev-parse --short HEAD)
    HASH_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/kernel_imx && git rev-parse --short HEAD)
    HASH_BUILD=$(cd $CURR_PATH/$ROOT_DIR/build && git rev-parse --short HEAD)
    HASH_DEVICE=$(cd $CURR_PATH/$ROOT_DIR/device && git rev-parse --short HEAD)
    HASH_PATCH=$(cd $CURR_PATH/$ROOT_DIR/patches_android_6.0.1 && git rev-parse --short HEAD)
    HASH_BIONIC=$(cd $CURR_PATH/$ROOT_DIR/bionic && git rev-parse --short HEAD)
    HASH_HARDWARE=$(cd $CURR_PATH/$ROOT_DIR/hardware && git rev-parse --short HEAD)
    HASH_FRAMEWORKS=$(cd $CURR_PATH/$ROOT_DIR/frameworks && git rev-parse --short HEAD)
    HASH_EXTERNAL=$(cd $CURR_PATH/$ROOT_DIR/external && git rev-parse --short HEAD)
    HASH_PACKAGES=$(cd $CURR_PATH/$ROOT_DIR/packages && git rev-parse --short HEAD)
    HASH_SYSTEM=$(cd $CURR_PATH/$ROOT_DIR/system && git rev-parse --short HEAD)
    HASH_LIBCORE=$(cd $CURR_PATH/$ROOT_DIR/libcore && git rev-parse --short HEAD)

    cd $CURR_PATH

    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Android 6.0.1
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
Andorid-UBOOT, ${HASH_UBOOT}
Andorid-KERNEL, ${HASH_KERNEL}
Andorid-BUILD, ${HASH_BUILD}
Andorid-DEVICE, ${HASH_DEVICE}
Andorid-BIONIC, ${HASH_BIONIC}
Andorid-HARDWARE, ${HASH_HARDWARE}
Andorid-FRAMEWORKS, ${HASH_FRAMEWORKS}
Andorid-EXTERNAL, ${HASH_EXTERNAL}
Andorid-PACKAGES, ${HASH_PACKAGES}
Andorid-SYSTEM, ${HASH_SYSTEM}
Andorid-LIBCORE, ${HASH_LIBCORE}
Andorid-ANDROID-PACH, ${HASH_PATCH}
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

    if [ "$1" == "android" ]; then
        #make -j4 droid otapackage 2>> $CURR_PATH/$ROOT_DIR/$LOG_FILE
        make -j4 2>> $CURR_PATH/$ROOT_DIR/$LOG_FILE
    else
        make -j4 $1 2>> $CURR_PATH/$ROOT_DIR/$LOG_FILE
    fi
#    echo "[ADV] simg2img... start"
#    out/host/linux-x86/bin/simg2img out/target/product/$NEW_MACHINE/system.img out/target/product/$NEW_MACHINE/system2.img
#    echo "[ADV] simg2img... end"

    [ "$?" -ne 0 ] && echo "[ADV] Build failure! Check log file '$LOG_FILE'" && exit 1
}

function patches_android_code()
{
	echo "[ADV] patches_android_Uboot_code"
    cd $CURR_PATH/$ROOT_DIR/bootable/bootloader/uboot-imx
	patch -p1 <../../../patches_android_6.0.1/6001-Uboot_Yocto_4.1.15_1.2.0-to-Android_M6.0.1_2.1.0.patch

	echo "[ADV] patches_android_Kernel_code"
	cd $CURR_PATH/$ROOT_DIR/kernel_imx
	patch -p1 <../patches_android_6.0.1/6001-Linux_Yocto_4.1.15_1.2.0-to-Android_M6.0.1_2.1.0.patch

}

function set_environment()
{
    echo "[ADV] set environment"

    cd $CURR_PATH/$ROOT_DIR
    export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/
    source build/envsetup.sh

    if [ "$1" == "sdk" ]; then
        lunch sdk-eng
    elif [ "$NEW_MACHINE" == "imx6" ]; then
        lunch rsb_4410-eng
    else
        if [ "$TYPE" == "" ]; then
            lunch $NEW_MACHINE-eng
        else
            lunch $NEW_MACHINE-$TYPE
        fi
    fi
}

function build_android_images()
{
    cd $CURR_PATH/$ROOT_DIR

	set_environment

    # Android & OTA images
	building android
	building otapackage
}

function prepare_images()
{
    cd $CURR_PATH

    IMAGE_DIR="AI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR
    mkdir $IMAGE_DIR/image

    # Copy image files to image directory


    cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/boot.img $IMAGE_DIR/image
    cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/recovery.img $IMAGE_DIR/image
#    mv -f $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/system2.img $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/system.img
    cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/system.img $IMAGE_DIR/image
    cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/u-boot_crc.bin $IMAGE_DIR/image
    cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/u-boot_crc.bin.crc $IMAGE_DIR/image
    cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/update.zip $IMAGE_DIR/image
    cp -a /usr/bin/simg2img $IMAGE_DIR/image

    mkdir $IMAGE_DIR/scripts
    cp -a $CURR_PATH/mksd-android.sh $IMAGE_DIR/scripts

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

    # Check ADVANTECH android source code tag exist or not, and checkout to tag version
    check_tag_and_checkout $ANDROID_BUILD_PATH
    check_tag_and_checkout $ANDROID_BIONIC_PATH
    check_tag_and_checkout $ANDROID_BOOTABLE_PATH
    check_tag_and_checkout $ANDROID_DEVICE_PATH
    check_tag_and_checkout $ANDROID_HARDWARE_PATH
    check_tag_and_checkout $ANDROID_LIBCORE_PATH
    check_tag_and_checkout $ANDROID_PACKAGES_PATH
    check_tag_and_checkout $ANDROID_SYSTEM_PATH
    check_tag_and_checkout $ANDROID_EXTERNAL_PATH
    check_tag_and_checkout $ANDROID_FRAMEWORKS_PATH
    check_tag_and_checkout $ANDROID_PREBUILTS
	check_tag_and_checkout $ANDROID_VENDOR
    check_tag_and_checkout $ANDROID_PATCH
    # Check tag exist or not, and replace bbappend file SRCREV
	#check_tag_and_replace $UBOOT_URL $UBOOT_PATH $UBOOT_BRANCH
	#check_tag_and_replace $KERNEL_URL $KERNEL_PATH $KERNEL_BRANCH


# Add git tag
	echo "[ADV] Add tag"
	auto_add_tag $CURR_PATH/$ROOT_DIR/$UBOOT_PATH
	auto_add_tag $CURR_PATH/$ROOT_DIR/$KERNEL_PATH
	auto_add_tag $CURR_PATH/$ROOT_DIR/build
	auto_add_tag $CURR_PATH/$ROOT_DIR/bionic
	auto_add_tag $CURR_PATH/$ROOT_DIR/bootable
	auto_add_tag $CURR_PATH/$ROOT_DIR/device
	auto_add_tag $CURR_PATH/$ROOT_DIR/hardware
	auto_add_tag $CURR_PATH/$ROOT_DIR/libcore
	auto_add_tag $CURR_PATH/$ROOT_DIR/packages
	auto_add_tag $CURR_PATH/$ROOT_DIR/system
	auto_add_tag $CURR_PATH/$ROOT_DIR/external
	auto_add_tag $CURR_PATH/$ROOT_DIR/frameworks
	auto_add_tag $CURR_PATH/$ROOT_DIR/prebuilts
	auto_add_tag $CURR_PATH/$ROOT_DIR/vendor
	auto_add_tag $CURR_PATH/$ROOT_DIR/patches_android_6.0.1
# ------------REMOVE FOR TEST   ------------- #
    # Create manifests xml and commit
	echo "[ADV] create_xml_and_commit"
    create_xml_and_commit

#echo "[ADV] patches android source code"
   patches_android_code

for NEW_MACHINE in $MACHINE_LIST
do
#echo "[ADV] build images"
   build_android_images

#echo "[ADV] prepare_images"
   prepare_images

#echo "[ADV] copy_image_to_storage"
   copy_image_to_storage

#echo "[ADV] copy_image_to_storage"
   save_temp_log
done

# ------------------------------------------- #


cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

