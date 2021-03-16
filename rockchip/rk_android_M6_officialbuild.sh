#!/bin/bash

VER_PREFIX="rk"

for i in $MACHINE_LIST
do
        NEW_MACHINE=$i
done

RELEASE_VERSION=$1
echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST= ${MACHINE_LIST}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"
#echo "[ADV] SCRIPT_XML = ${SCRIPT_XML}"
VER_TAG="${VER_PREFIX}ABV"$(echo $RELEASE_VERSION | sed 's/[.]//')
echo "[ADV] VER_TAG = $VER_TAG"
CURR_PATH="$PWD"
ROOT_DIR="${VER_PREFIX}ABV${RELEASE_VERSION}"_"$DATE"
OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"

echo "$Release_Note" > Release_Note
REALEASE_NOTE="Release_Note"

#--------------------------------------------------
#======================
AND_BSP="android"
AND_BSP_VER="6.0"
AND_VERSION="android_M6.0.1"

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
    git clone https://github.com/rockchip-linux/repo.git
    mkdir $ROOT_DIR
    cd $ROOT_DIR

    if [ "$BSP_BRANCH" == "" ] ; then
       ../repo/repo init -u $BSP_URL
    elif [ "$BSP_XML" == "" ] ; then
       ../repo/repo init -u $BSP_URL -b $BSP_BRANCH
    else
       ../repo/repo init -u $BSP_URL -b $BSP_BRANCH -m $BSP_XML
    fi
    ../repo/repo sync

    cd $CURR_PATH
    cd $ROOT_DIR/u-boot
    REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
    git checkout -b local --track $REMOTE_SERVER/$BSP_BRANCH
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
        REMOTE_URL=$1
        REMOTE_BRANCH=$2
        FILE_PATH=$3
        
        git clone $REMOTE_URL
        
        if [ -d "$FILE_PATH" ];then
                cd $FILE_PATH
                git checkout $REMOTE_BRANCH
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
                rm -rf $FILE_PATH
        else
                echo "[ADV] Directory $FILE_PATH doesn't exist"
                exit 1
        fi
}

function create_xml_and_commit()
{
        if [ -d "$ROOT_DIR/.repo/manifests" ];then
                echo "[ADV] Create XML file"
                cd $ROOT_DIR
                # add revision into xml
                repo manifest -o $VER_TAG.xml -r
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

    #HASH_BSP=$(cd $CURR_PATH/$ROOT_DIR/.repo/manifests && git rev-parse --short HEAD)
    HASH_ANDROID_UBOOT=$(cd $CURR_PATH/$ROOT_DIR/u-boot && git rev-parse --short HEAD)
    HASH_ANDROID_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/kernel && git rev-parse --short HEAD)
    HASH_ANDROID_BIONIC=$(cd $CURR_PATH/$ROOT_DIR/bionic && git rev-parse --short HEAD)
    HASH_ANDROID_BOOTABLE=$(cd $CURR_PATH/$ROOT_DIR/bootable && git rev-parse --short HEAD)
    HASH_ANDROID_BUILD=$(cd $CURR_PATH/$ROOT_DIR/build && git rev-parse --short HEAD)
    HASH_ANDROID_DEVICE=$(cd $CURR_PATH/$ROOT_DIR/device && git rev-parse --short HEAD)
    HASH_ANDROID_EXTERNAL=$(cd $CURR_PATH/$ROOT_DIR/external && git rev-parse --short HEAD)
    HASH_ANDROID_FRAMEWORKS=$(cd $CURR_PATH/$ROOT_DIR/frameworks && git rev-parse --short HEAD)
    HASH_ANDROID_HARDWARE=$(cd $CURR_PATH/$ROOT_DIR/hardware && git rev-parse --short HEAD)
    HASH_ANDROID_PACKAGES=$(cd $CURR_PATH/$ROOT_DIR/packages && git rev-parse --short HEAD)
    HASH_ANDROID_PREBUILTS=$(cd $CURR_PATH/$ROOT_DIR/prebuilts/gcc/linux-x86/arm/arm-eabi-4.6 && git rev-parse --short HEAD)
    HASH_ANDROID_RKST=$(cd $CURR_PATH/$ROOT_DIR/rkst && git rev-parse --short HEAD)
    HASH_ANDROID_SYSTEM=$(cd $CURR_PATH/$ROOT_DIR/system && git rev-parse --short HEAD)
    HASH_ANDROID_VENDOR=$(cd $CURR_PATH/$ROOT_DIR/vendor && git rev-parse --short HEAD)
    
    

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

ANDROID_UBOOT, ${HASH_ANDROID_UBOOT}
ANDROID_KERNEL, ${HASH_ANDROID_KERNEL}
ANDROID_BIONIC, ${HASH_ANDROID_BIONIC}
ANDROID_BOOTABLE, ${HASH_ANDROID_BOOTABLE}
ANDROID_BUILD, ${HASH_ANDROID_BUILD}
ANDROID_DEVICE, ${HASH_ANDROID_DEVICE}
ANDROID_EXTERNAL, ${HASH_ANDROID_EXTERNAL}
ANDROID_FRAMEWORKS, ${HASH_ANDROID_FRAMEWORKS}
ANDROID_HARDWARE, ${HASH_ANDROID_HARDWARE}
ANDROID_PACKAGES, ${HASH_ANDROID_PACKAGES}
ANDROID_PREBUILTS, ${HASH_ANDROID_PREBUILTS}
ANDROID_RKST, ${HASH_ANDROID_RKST}
ANDROID_SYSTEM, ${HASH_ANDROID_SYSTEM}
ANDROID_VENDOR, ${HASH_ANDROID_VENDOR}



END_OF_CSV
}

function save_temp_log()
{
    LOG_PATH="$CURR_PATH/$ROOT_DIR"
    cd $LOG_PATH

    LOG_DIR="AIV${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"_log
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
		cd $CURR_PATH/$ROOT_DIR/u-boot
		echo "[ADV] UBOOT_DEFCONFIG=$UBOOT_DEFCONFIG"
		echo " V$RELEASE_VERSION" > .scmversion
		make $UBOOT_DEFCONFIG
		make 2>> $CURR_PATH/$ROOT_DIR/$LOG_FILE
	elif [ "$1" == "kernel" ]; then
		cd $CURR_PATH/$ROOT_DIR/kernel
		make rk3288_adv_defconfig 
		make $KERNEL_DTB >> $CURR_PATH/$ROOT_DIR/$LOG2_FILE
    elif [ "$1" == "android" ]; then
		cd $CURR_PATH/$ROOT_DIR
		source build/envsetup.sh
		lunch $ANDROID_CONFIG
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

function build_android_OTA_images()
{
    LOG4_FILE="$NEW_MACHINE"_Build4.log
    cd $CURR_PATH/$ROOT_DIR
    set_environment
    ./mkimage.sh ota
    make -j4 otapackage 2>> $CURR_PATH/$ROOT_DIR/$LOG4_FILE
}

function prepare_images()
{
    cd $CURR_PATH

    echo "[ADV] clone rk3288 tools"
    git clone https://github.com/ADVANTECH-Rockchip/rk3288_tools.git
    cd rk3288_tools/Linux_rockdev
    
    chmod 777 afptool mkupdate.sh rkImageMaker unpack.sh
    cp -a $CURR_PATH/$ROOT_DIR/rockdev/*/*.img ./Image
    cp -a $CURR_PATH/$ROOT_DIR/kernel/*.img ./Image
    cp -a $CURR_PATH/$ROOT_DIR/u-boot/RK3288UbootLoader_V2.30.10.bin ./
    echo "[ADV] make update.img"
    ./mkupdate.sh
    
    cd $CURR_PATH

    IMAGE_DIR="AIV${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR
	mkdir -p $IMAGE_DIR/rockdev/image

    # Copy image files to image directory
	cp -a $CURR_PATH/$ROOT_DIR/rockdev/*/*.img $IMAGE_DIR/rockdev/image
	cp -a $CURR_PATH/$ROOT_DIR/kernel/*.img $IMAGE_DIR/rockdev/image	
	cp -a $CURR_PATH/$ROOT_DIR/u-boot/RK3288UbootLoader_V2.30.10.bin $IMAGE_DIR/rockdev
	cp -a $CURR_PATH/rk3288_tools/Linux_rockdev/*.img $IMAGE_DIR/rockdev

    build_android_OTA_images
    cd $CURR_PATH
        cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/*.zip $IMAGE_DIR/rockdev

    echo "[ADV] creating ${IMAGE_DIR}.tgz ..."
    tar czf ${IMAGE_DIR}.tgz $IMAGE_DIR
    generate_md5 ${IMAGE_DIR}.tgz
    rm -rf $IMAGE_DIR
}

function copy_image_to_storage()
{
    echo "[ADV] copy images to $OUTPUT_DIR"

    generate_csv ${IMAGE_DIR}.tgz
    mv ${IMAGE_DIR}.csv $OUTPUT_DIR

    mv -f ${IMAGE_DIR}.tgz $OUTPUT_DIR
    mv -f *.md5 $OUTPUT_DIR

}

function uboot_version_commit()
{
    cd $CURR_PATH
    cd $ROOT_DIR/u-boot

    # push to github
    REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
    git add .scmversion -f
    git commit -m "[Official Release] ${VER_TAG}"
    git push $REMOTE_SERVER local:$BSP_BRANCH
    cd $CURR_PATH
}
# ================
#  Main procedure 
# ================
    mkdir $ROOT_DIR
    get_source_code

    echo "[ADV] add tag"
    auto_add_tag $RK_UBOOT_URL $BRANCH uboot-rk
    auto_add_tag $RK_KERNEL_URL $BRANCH kernel-rk
    auto_add_tag $RK_DEVICE_URL $ANDROID_BRANCH android_rk_device
    auto_add_tag $RK_VENDOR_URL $ANDROID_BRANCH android_rk_vendor
    auto_add_tag $RK_HARDWARE_URL $ANDROID_BRANCH android_rk_hardware
    auto_add_tag $RK_PACKAGES_URL $ANDROID_BRANCH android_rk_packages
    auto_add_tag $RK_BUILD_URL $ANDROID_BRANCH android_rk_build
    auto_add_tag $RK_FRAMEWORKS_URL $ANDROID_BRANCH android_rk_frameworks
#    auto_add_tag $RK_MANIFEST_URL $BRANCH android-rk-manifest
    auto_add_tag $RK_BOOTABLE_URL $ANDROID_BRANCH android_rk_bootable
    auto_add_tag $RK_SYSTEM_URL $ANDROID_BRANCH android_rk_system
    auto_add_tag $RK_EXTERNAL_URL $ANDROID_BRANCH android_rk_external
    auto_add_tag $RK_PREBUILTS_URL $ANDROID_BRANCH android_rk_prebuilts
    auto_add_tag $RK_RKST_URL $ANDROID_BRANCH android_rk_rkst
    auto_add_tag $RK_BIONIC_URL $ANDROID_BRANCH android_rk_bionic
    

   # Create manifests xml and commit
	echo "[ADV] create_xml_and_commit"
    create_xml_and_commit

echo "[ADV] build images"
	 build_android_images
echo "[ADV] prepare_images"
     prepare_images
echo "[ADV] copy_image_to_storage"
     copy_image_to_storage
     save_temp_log

    uboot_version_commit
cd $CURR_PATH
rm -rf $ROOT_DIR

echo "[ADV] build script done!"

