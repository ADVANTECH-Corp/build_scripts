#!/bin/bash

PLATFORM_PREFIX="RK3568_RISC_"
VER_PREFIX="DIV"
BSP_VER_PREFIX="DBV"


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

RELEASE_VERSION=$1
echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST= ${MACHINE_LIST}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"
VER_TAG="${PLATFORM_PREFIX}${VER_PREFIX}"$(echo $RELEASE_VERSION | sed 's/[.]//')
echo "[ADV] VER_TAG = $VER_TAG"
OFFICIAL_VER="${MODEL_NAME}${HW_VER}${AIM_VERSION}${VER_PREFIX}"$(echo $RELEASE_VERSION | sed 's/[.]//')
BSP_VER="${MODEL_NAME}${HW_VER}${AIM_VERSION}${BSP_VER_PREFIX}"$(echo $RELEASE_VERSION | sed 's/[.]//')
echo "[ADV] OFFICIAL_VER = $OFFICIAL_VER"
echo "[ADV] BSP_VER = $BSP_VER"
echo "[ADV] isFirstMachine = $isFirstMachine"
CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}${VER_PREFIX}${RELEASE_VERSION}"_"$DATE"
OUTPUT_DIR="$CURR_PATH/$STORED/$DATE/V"$(echo $RELEASE_VERSION | sed 's/[.]//')

echo "$Release_Note" > Release_Note
REALEASE_NOTE="Release_Note"

#--------------------------------------------------
#======================
AND_BSP="debian"
AND_BSP_VER="10.x"
AND_VERSION="debian_V10.x"

#======================

# Make storage folder
if [ -e $OUTPUT_DIR ] ; then
    echo "[ADV] $OUTPUT_DIR had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR"
    mkdir -p $OUTPUT_DIR
fi

if [ -e $OUTPUT_DIR/${MODEL_NAME}/bsp ] ; then
    echo "[ADV] $OUTPUT_DIR/${MODEL_NAME}/bsp  had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR/${MODEL_NAME}/bsp"
    mkdir -p $OUTPUT_DIR/${MODEL_NAME}/bsp
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

function auto_add_tag()
{
    echo "[ADV] auto_add_tag"
    cd $CURR_PATH/$ROOT_DIR/kernel
    HEAD_HASH_ID=`git rev-parse HEAD`
    TAG_HASH_ID=`git tag -v $VER_TAG | grep object | cut -d ' ' -f 2`
    REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
    if [ "$HEAD_HASH_ID" == "$TAG_HASH_ID" ]; then
        echo "[ADV] tag exists! There is no need to add tag"
    else
        echo "[ADV] Add tag $VER_TAG"
        cd $CURR_PATH/$ROOT_DIR
	../repo/repo forall -c git tag -a $VER_TAG -m "[Official Release] $VER_TAG"
	../repo/repo forall -c git push $REMOTE_SERVER $VER_TAG

		if [ -d "debian_$MODEL_NAME" ];then
			cd debian_$MODEL_NAME/
			REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
			git tag -a $VER_TAG -m "[Official Release] $VER_TAG"
			git push $REMOTE_SERVER $VER_TAG
		fi
    fi
    cd $CURR_PATH
}

function create_xml_and_commit()
{
    echo "[ADV] create_xml_and_commit"
    cd $CURR_PATH
    if [ -d "$ROOT_DIR/.repo/manifests" ];then
        echo "[ADV] Create XML file"
        cd $ROOT_DIR
        # add revision into xml
        ../repo/repo manifest -o $VER_TAG.xml -r
        sed -i '/remote="advantech-azure-priv"/d' $VER_TAG.xml
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

function uboot_version_commit()
{
    echo "[ADV] uboot_version_commit"
    cd $CURR_PATH
	cd $ROOT_DIR/u-boot

	# push to github
	REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
	echo " V$RELEASE_VERSION" > .scmversion
	git add .scmversion -f
	git commit -m "[Official Release] ${VER_TAG}"
	git push $REMOTE_SERVER local:$BSP_BRANCH
	cd $CURR_PATH

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

    HASH_DEBIAN_UBOOT=$(cd $CURR_PATH/$ROOT_DIR/u-boot && git rev-parse --short HEAD)
    HASH_DEBIAN_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/kernel && git rev-parse --short HEAD)
    HASH_DEBIAN_APP=$(cd $CURR_PATH/$ROOT_DIR/app && git rev-parse --short HEAD)
    HASH_DEBIAN_BUILDROOT=$(cd $CURR_PATH/$ROOT_DIR/buildroot && git rev-parse --short HEAD)
    HASH_DEBIAN_DEVICE=$(cd $CURR_PATH/$ROOT_DIR/device && git rev-parse --short HEAD)
    HASH_DEBIAN_EXTERNAL=$(cd $CURR_PATH/$ROOT_DIR/external && git rev-parse --short HEAD)
    HASH_DEBIAN_PREBUILTS=$(cd $CURR_PATH/$ROOT_DIR/prebuilts && git rev-parse --short HEAD)
    HASH_DEBIAN_RKBIN=$(cd $CURR_PATH/$ROOT_DIR/rkbin && git rev-parse --short HEAD)
    HASH_DEBIAN_ROOTFS=$(cd $CURR_PATH/$ROOT_DIR/debian && git rev-parse --short HEAD)
    HASH_DEBIAN_ROOTFS_ADV=$(cd $CURR_PATH/$ROOT_DIR/debian_adv && git rev-parse --short HEAD)
    HASH_DEBIAN_TOOLS=$(cd $CURR_PATH/$ROOT_DIR/tools && git rev-parse --short HEAD)

    cd $CURR_PATH


    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Debian GNU/Linux 10.x (buster)
Version,V${RELEASE_VERSION}

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
Manifest, ${HASH_BSP}

DEBIAN_UBOOT, ${HASH_DEBIAN_UBOOT}
DEBIAN_KERNEL, ${HASH_DEBIAN_KERNEL}
DEBIAN_APP, ${HASH_DEBIAN_APP}
DEBIAN_BUILDROOT, ${HASH_DEBIAN_BUILDROOT}
DEBIAN_DEVICE, ${HASH_DEBIAN_DEVICE}
DEBIAN_EXTERNAL, ${HASH_DEBIAN_EXTERNAL}
DEBIAN_PREBUILTS, ${HASH_DEBIAN_PREBUILTS}
DEBIAN_RKBIN, ${HASH_DEBIAN_RKBIN}
DEBIAN_ROOTFS, ${HASH_DEBIAN_ROOTFS}
DEBIAN_ROOTFS_ADV, ${HASH_DEBIAN_ROOTFS_ADV}
DEBIAN_TOOLS, ${HASH_DEBIAN_TOOLS}



END_OF_CSV
}

function generate_manifest()
{
    cd $CURR_PATH/$ROOT_DIR/
    ../repo/repo manifest -o ${VER_TAG}.xml -r
}

function save_temp_log()
{
    LOG_PATH="$CURR_PATH/$ROOT_DIR"
    cd $LOG_PATH

    LOG_DIR="${OFFICIAL_VER}"_"$DATE"_log
    echo "[ADV] mkdir $LOG_DIR"
    mkdir $LOG_DIR

    # Backup conf, run script & log file
    cp -a *.log $LOG_DIR

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
    echo "[ADV] get rk3568 debian10 source code"
    cd $CURR_PATH

    git clone https://github.com/ADVANTECH-Rockchip/repo.git

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

    cd u-boot
    REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
    cd ..
    ../repo/repo forall -c git checkout -b local --track $REMOTE_SERVER/$BSP_BRANCH

    if [ "$MODEL_NAME" == "EBCRB07" ] ; then
        git clone https://AIM-Linux@dev.azure.com/AIM-Linux/risc-private-bsp/_git/rk3568_linux_debian_ebcrb07 ./debian_$MODEL_NAME
        cd ./debian_$MODEL_NAME
        REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
        git checkout -b local --track $REMOTE_SERVER/$BSP_BRANCH
        cd ..
    fi

    cd $CURR_PATH
}

function building()
{
    echo "[ADV] building $1 ..."
    LOG_FILE="$NEW_MACHINE"_Build.log
	
	LOG_FILE_UBOOT="$NEW_MACHINE"_Build_uboot.log
	LOG_FILE_KERNEL="$NEW_MACHINE"_Build_kernel.log
	LOG_FILE_RECOVERY="$NEW_MACHINE"_Build_recovery.log
	LOG_FILE_ROOTFS="$NEW_MACHINE"_Build_rootfs.log

    if [ "$1" == "uboot" ]; then
        echo "[ADV] build uboot UBOOT_DEFCONFIG=$UBOOT_DEFCONFIG"
		cd $CURR_PATH/$ROOT_DIR/u-boot
		make clean
		echo " V$RELEASE_VERSION" > .scmversion
		./make.sh $UBOOT_DEFCONFIG >&1 | tee $CURR_PATH/$ROOT_DIR/$LOG_FILE_UBOOT
	elif [ "$1" == "kernel" ]; then
		echo "[ADV] build kernel KERNEL_DEFCONFIG = $KERNEL_DEFCONFIG KERNEL_DTB=$KERNEL_DTB"
		cd $CURR_PATH/$ROOT_DIR/
		if [ -d "debian_$MODEL_NAME/logo/$DISPLAY_DIRECTION" ];then
			cp debian_$MODEL_NAME/logo/$DISPLAY_DIRECTION/* kernel/ -rf
		fi
		cd $CURR_PATH/$ROOT_DIR/kernel

		echo "[ADV] build kernel make ARCH=arm64 $KERNEL_DEFCONFIG"
		make clean
		make ARCH=arm64 $KERNEL_DEFCONFIG >&1 | tee $CURR_PATH/$ROOT_DIR/$LOG_FILE_KERNEL
		echo "[ADV] build kernel make ARCH=arm64 $KERNEL_DTB -j12"
		make ARCH=arm64 $KERNEL_DTB -j12 >&1 | tee -a $CURR_PATH/$ROOT_DIR/$LOG_FILE_KERNEL
    elif [ "$1" == "recovery" ]; then
		sudo apt-get update
		sudo apt-get install -y expect-dev
		echo "[ADV] build recovery"
		cd $CURR_PATH/$ROOT_DIR
		if [  -d "buildroot/output/rockchip_rk356x_recovery " ];then
		    rm buildroot/output/rockchip_rk356x_recovery  -rf
		fi
		source envsetup.sh rockchip_rk356x_recovery 
		./build.sh recovery >&1 | tee $CURR_PATH/$ROOT_DIR/$LOG_FILE_RECOVERY
    elif [ "$1" == "rootfs" ]; then
		echo "[ADV] build rootfs"
		sudo apt-get update
		sudo apt-get install -y binfmt-support
		sudo apt --fix-broken install -f -y

		sudo apt-get install -y qemu-user-static
		sudo apt-get -y update
		sudo apt-get install -y live-build

		cd $CURR_PATH/$ROOT_DIR/debian
		sudo dpkg -i ubuntu-build-service/packages/*
		sudo apt-get install -f -y
		cd $CURR_PATH/$ROOT_DIR/
		sudo BUILD_IN_DOCKER=TRUE ./mk-debian.sh new >&1 | tee $CURR_PATH/$ROOT_DIR/$LOG_FILE_ROOTFS

		if [ -d "debian_$MODEL_NAME" ];then
			cd $CURR_PATH/$ROOT_DIR/
			cd debian_$MODEL_NAME
			echo "v${RELEASE_VERSION}_${DATE}_${DISPLAY_DIRECTION}" > overlay-adv/etc/version
			sudo BUILD_IN_DOCKER=TRUE ARCH=arm64 ./mk-adv.sh
			cd ../debian
			sudo ./mk-image.sh
			cd $CURR_PATH/$ROOT_DIR/
		fi

	else
        echo "[ADV] pass building..."
    fi
    [ "$?" -ne 0 ] && echo "[ADV] Build failure! Check log file '$LOG_FILE'" && exit 1
}


function build_linux_images()
{
    cd $CURR_PATH/$ROOT_DIR
	echo "[ADV] build linux images begin"

	TARGET_PRODUCT="device/rockchip/.target_product"
	TARGET_PRODUCT_DIR=$(realpath ${TARGET_PRODUCT})
	ln -rfs $TARGET_PRODUCT_DIR/$BOARD_CONFIG device/rockchip/.BoardConfig.mk

	building uboot
	building kernel
	if [ $isFirstMachine == "true" ]; then
	    building rootfs
	fi
	building recovery

    # package image to rockdev folder
	cd $CURR_PATH/$ROOT_DIR
	echo "[ADV] build link images to rockdev"
	source envsetup.sh rockchip_rk356x_recovery 
	./mkfirmware.sh
	echo "[ADV] build linux images end"
}

function prepare_images()
{
    cd $CURR_PATH

    IMAGE_DIR="${OFFICIAL_VER}"_"$DATE"
    echo "[ADV] mkdir $IMAGE_DIR"
    mkdir $IMAGE_DIR

    if [ -d $CURR_PATH/$ROOT_DIR/tools/windows/RKDevTool ];then
        cp -aRL $CURR_PATH/$ROOT_DIR/tools/windows/RKDevTool/* $IMAGE_DIR/
    else
        cp -aRL $CURR_PATH/$ROOT_DIR/tools/windows/AndroidTool/* $IMAGE_DIR/
    fi

    cp -aRL $CURR_PATH/$ROOT_DIR/tools/windows/DriverAssitant_*.zip $IMAGE_DIR/
    cp -aRL $CURR_PATH/$ROOT_DIR/tools/windows/SDDiskTool_*.zip $IMAGE_DIR/

    mkdir -p $IMAGE_DIR/rockdev/image

    # Copy image files to image directory
    cp -aRL $CURR_PATH/$ROOT_DIR/rockdev/* $IMAGE_DIR/rockdev/image
    echo "[ADV] creating ${IMAGE_DIR}.tgz ..."
    tar czf ${IMAGE_DIR}.img.tgz $IMAGE_DIR
    generate_md5 ${IMAGE_DIR}.img.tgz
    #rm -rf $IMAGE_DIR

    # BSP
    cd $CURR_PATH
    BSP_DIR="${BSP_VER}"_"$DATE"
    mkdir $BSP_DIR

    cd $CURR_PATH/$ROOT_DIR
    cd u-boot
    make clean
    git add . -f
    git reset --hard

    cd $CURR_PATH/$ROOT_DIR
    cd kernel
    make clean
    git add . -f
    git reset --hard

    cd $CURR_PATH
    cp -R $CURR_PATH/$ROOT_DIR/u-boot $BSP_DIR/
    rm -rf $BSP_DIR/u-boot/.git
    cp -R $CURR_PATH/$ROOT_DIR/kernel $BSP_DIR/
    rm -rf $BSP_DIR/kernel/.git
    cp -R $CURR_PATH/$ROOT_DIR/rkbin $BSP_DIR/
    rm -rf $BSP_DIR/rkbin/.git
    cp -R $CURR_PATH/$ROOT_DIR/prebuilts $BSP_DIR/
    rm -rf $BSP_DIR/prebuilts/.git

    tar czf ${BSP_DIR}.bsp.tgz $BSP_DIR
    generate_md5 ${BSP_DIR}.bsp.tgz
}

function copy_image_to_storage()
{
    echo "[ADV] copy images to $OUTPUT_DIR"
    cd $CURR_PATH
    IMAGE_DIR="${OFFICIAL_VER}"_"$DATE"
	BSP_DIR="${BSP_VER}"_"$DATE"
	if [ $isFirstMachine == "true" ]; then
	    generate_manifest
	    mv ${VER_TAG}.xml $OUTPUT_DIR
	fi

    generate_csv ${IMAGE_DIR}.tgz
    mv ${IMAGE_DIR}.csv $OUTPUT_DIR/${MODEL_NAME}/others

    # image
    mv -f ${IMAGE_DIR}.img.tgz $OUTPUT_DIR/${MODEL_NAME}/image
    mv -f ${IMAGE_DIR}.img.tgz.md5 $OUTPUT_DIR/${MODEL_NAME}/image

    # bsp
    mv -f ${BSP_DIR}.bsp.tgz $OUTPUT_DIR/${MODEL_NAME}/bsp
    mv -f ${BSP_DIR}.bsp.tgz.md5 $OUTPUT_DIR/${MODEL_NAME}/bsp
    #mv -f *.md5 $OUTPUT_DIR
}

# ================
#  Main procedure 
# ================
if [ $isFirstMachine == "true" ]; then
	get_source_code
fi
build_linux_images
prepare_images
copy_image_to_storage
save_temp_log
if [ $isFirstMachine == "true" ]; then
	uboot_version_commit
	create_xml_and_commit
	auto_add_tag
fi

echo "[ADV] build script done!"

