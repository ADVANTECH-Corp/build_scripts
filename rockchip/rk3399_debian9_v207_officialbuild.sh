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
VER_TAG="${VER_PREFIX}3399LB"$(echo $RELEASE_VERSION | sed 's/[.]//')
echo "[ADV] VER_TAG = $VER_TAG"
CURR_PATH="$PWD"
ROOT_DIR="${VER_PREFIX}3399LB${RELEASE_VERSION}"_"$DATE"
OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"

#-- Advantech/rk3399 github debian source code repository
echo "[ADV-ROOT]  $ROOT_DIR"
echo "[ADV] ANDROID_KERNEL_PATH = $CURR_PATH/$ROOT_DIR/kernel"
echo "[ADV] ANDROID_UBOOT_PATH = $CURR_PATH/$ROOT_DIR/u-boot"

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
    echo "[ADV] get debian source code"
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
    HASH_ANDROID_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/kernel && git rev-parse --short HEAD)
    HASH_ANDROID_UBOOT=$(cd $CURR_PATH/$ROOT_DIR/u-boot && git rev-parse --short HEAD)
    cd $CURR_PATH


    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Debian 9
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
ANDROID_KERNEL, ${HASH_ANDROID_KERNEL}
ANDROID_UBOOT, ${HASH_ANDROID_UBOOT}


END_OF_CSV
}

function save_temp_log()
{
    LOG_PATH="$CURR_PATH/$ROOT_DIR"
    cd $LOG_PATH

    LOG_DIR="DI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"_log
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
		#make clean
		./make.sh evb-rk3399 >> $CURR_PATH/$ROOT_DIR/$LOG_FILE
	elif [ "$1" == "kernel" ]; then
		echo "[ADV] build kernel  = $KERNEL_CONFIG"
        echo "[ADV] build kernel dtb  = $KERNEL_DTB"
		cd $CURR_PATH/$ROOT_DIR/kernel
		#make distclean
		make ARCH=arm64 $KERNEL_CONFIG
		make ARCH=arm64 $KERNEL_DTB -j16 >> $CURR_PATH/$ROOT_DIR/$LOG2_FILE
        echo "[ADV] build kernel Finished"
    elif [ "$1" == "recovery" ]; then
		echo "[ADV] build recovery"
		cd $CURR_PATH/$ROOT_DIR
		./build.sh recovery
    elif [ "$1" == "buildroot" ]; then
		echo "[ADV] build buildroot"
		cd $CURR_PATH/$ROOT_DIR
		./build.sh rootfs
    elif [ "$1" == "debian" ]; then
        cd $CURR_PATH/$ROOT_DIR/rootfs
        echo "[ADV] install tools for build debian"
        sudo apt-get install -y binfmt-support
        sudo apt-get install -y qemu-user-static
		sudo apt-get -y update
		sudo apt-get install -y live-build
        echo "[ADV] dpkg packages"
        sudo dpkg -i ubuntu-build-service/packages/*
        sudo apt-get install -f
        echo "[ADV]-------------FOR armhf  32-----------"
        #echo "[ADV] armhf mk-base-debian.sh"
        #RELEASE=stretch TARGET=desktop ARCH=armhf ./mk-base-debian.sh
        #echo "[ADV] mk-rootfs-stretch.sh"
        #VERSION=debug ARCH=armhf ./mk-rootfs-stretch.sh
        #echo "[ADV] mk-image.sh armhf"
        #./mk-image.sh
        #echo "[ADV]---------------------------------"
        echo "[ADV]-------------FOR arm64  64-----------"
        echo "[ADV] arm64 mk-base-debian.sh"
        RELEASE=stretch TARGET=desktop ARCH=arm64 ./mk-base-debian.sh
        echo "[ADV] mk-rootfs-stretch-arm64.sh"
        VERSION=debug ARCH=arm64 ./mk-rootfs-stretch-arm64.sh
        echo "[ADV] add advantech "
        cp -aRL $CURR_PATH/$ROOT_DIR/rootfs/adv/* $CURR_PATH/$ROOT_DIR/rootfs
        ./mk-adv.sh ARCH=arm64
        ./mk-adv-module.sh ARCH=arm64
        ./mk-adv-word.sh ARCH=arm64
	echo "[ADV] mk-image.sh arm64 "
        ./mk-image.sh
        sudo tar cvf binary.tgz $CURR_PATH/$ROOT_DIR/rootfs/binary
	echo "[ADV]---------------------------------"
    	cd $CURR_PATH/$ROOT_DIR 
    	./build.sh BoardConfig_debian.mk
	    ./mkfirmware.sh


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

function build_linux_images()
{
	cd $CURR_PATH/$ROOT_DIR
	#set_environment
	building uboot
	building kernel
#	building recovery
	building buildroot
	building debian

    #=== package image to rockdev folder ===
	cd $CURR_PATH/$ROOT_DIR
}

function prepare_images()
{
    cd $CURR_PATH

    IMAGE_DIR="DI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR

    # Copy image files to image directory

    cp -aRL $CURR_PATH/$ROOT_DIR/u-boot/rk*.bin $IMAGE_DIR
	cp -aRL $CURR_PATH/$ROOT_DIR/u-boot/trust.img $IMAGE_DIR
	cp -aRL $CURR_PATH/$ROOT_DIR/u-boot/uboot.img $IMAGE_DIR
	cp -aRL $CURR_PATH/$ROOT_DIR/kernel/boot.img $IMAGE_DIR
	cp -aRL $CURR_PATH/$ROOT_DIR/buildroot/output/rockchip_rk3399_recovery/images/recovery.img $IMAGE_DIR
    cp -aRL $CURR_PATH/$ROOT_DIR/buildroot/output/rockchip_rk3399/images/rootfs.ext4 $IMAGE_DIR
    cp -aRL $CURR_PATH/$ROOT_DIR/out/linaro-rootfs.img $IMAGE_DIR
    cp -aRL $CURR_PATH/$ROOT_DIR/rockdev/oem* $IMAGE_DIR
    cp -aRL $CURR_PATH/$ROOT_DIR/device/rockchip/rk3399/parameter* $IMAGE_DIR
    cp -aRL $CURR_PATH/$ROOT_DIR/rootfs/linaro-rootfs.img $IMAGE_DIR
	cp -aRL $CURR_PATH/out/u1604* $IMAGE_DIR
	cp -aRL $CURR_PATH/u1604* $IMAGE_DIR
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
    sudo mv -f $CURR_PATH/$ROOT_DIR/rootfs/binary.tgz $OUTPUT_DIR
}

# u1604_aarch64_release_20190813.img

function get_ubuntu_rootfs()
{
	cd $CURR_PATH
    echo "[ADV] get_ubuntu_rootfs"
    mkdir out
    pftp -v -n ${FTP_SITE} << EOF
user "ftpuser" "P@ssw0rd"
cd "Image/RK3399_Ubuntu"
prompt
binary
ls
mget u1604_aarch64_release_20190813.img
close
quit
EOF
}

# ================
#  Main procedure 
# ================
    mkdir $ROOT_DIR
    get_source_code

	echo "[ADV] check_tag_and_checkout"
    check_tag_and_checkout $ANDROID_KERNEL_PATH
    check_tag_and_checkout $ANDROID_UBOOT_PATH
# Add git tag
	echo "[ADV] Add tag"
    auto_add_tag $CURR_PATH/$ROOT_DIR/kernel
    auto_add_tag $CURR_PATH/$ROOT_DIR/u-boot


   # Create manifests xml and commit
	echo "[ADV] create_xml_and_commit"
    create_xml_and_commit

echo "[ADV] build images"

for NEW_MACHINE in $MACHINE_LIST
do
echo "[ADV] NEW_MACHINE = $NEW_MACHINE"
	build_linux_images
echo "[ADV] get ubuntu rootfs"
	get_ubuntu_rootfs
echo "[ADV] prepare_images"
	prepare_images
echo "[ADV] copy_image_to_storage"
	copy_image_to_storage
	save_temp_log
done


cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

