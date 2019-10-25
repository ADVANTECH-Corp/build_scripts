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

CURR_PATH="$PWD"
ROOT_DIR="${VER_PREFIX}AB${RELEASE_VERSION}"_"$DATE"
OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"


#======================
AND_BSP="android"
AND_BSP_VER="9.0.0"
AND_VERSION="android_p9.0.0_2.2.0"

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
	HASH_UBOOT=$(cd $CURR_PATH/$ROOT_DIR/vendor/nxp-opensource/uboot-imx && git rev-parse --short HEAD)
	HASH_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/vendor/nxp-opensource/kernel_imx && git rev-parse --short HEAD)
	HASH_PATCH=$(cd $CURR_PATH/$ROOT_DIR/patches_android_9.0.0_r35 && git rev-parse --short HEAD)
	HASH_DEVICE=$(cd $CURR_PATH/$ROOT_DIR/device && git rev-parse --short HEAD)
	HASH_VENDOR=$(cd $CURR_PATH/$ROOT_DIR/vendor && git rev-parse --short HEAD)
	HASH_ART=$(cd $CURR_PATH/$ROOT_DIR/art && git rev-parse --short HEAD)
	HASH_BUILD=$(cd $CURR_PATH/$ROOT_DIR/build && git rev-parse --short HEAD)
	HASH_BOOTABLE=$(cd $CURR_PATH/$ROOT_DIR/bootable && git rev-parse --short HEAD)
	HASH_DEVELOPMENT=$(cd $CURR_PATH/$ROOT_DIR/development && git rev-parse --short HEAD)
	HASH_EXTERNAL=$(cd $CURR_PATH/$ROOT_DIR/external && git rev-parse --short HEAD)
	HASH_FRAMEWORKS=$(cd $CURR_PATH/$ROOT_DIR/frameworks && git rev-parse --short HEAD)
	HASH_HARDWARE=$(cd $CURR_PATH/$ROOT_DIR/hardware && git rev-parse --short HEAD)
	HASH_PACKAGES=$(cd $CURR_PATH/$ROOT_DIR/packages && git rev-parse --short HEAD)
	HASH_SYSTEM=$(cd $CURR_PATH/$ROOT_DIR/system && git rev-parse --short HEAD)

	cd $CURR_PATH

    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Android 9.0.0
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
Andorid-DEVICE, ${HASH_DEVICE}
Andorid-VENDOR, ${HASH_VENDOR}
Andorid-ART, ${HASH_ART}
Andorid-BUILD, ${HASH_BUILD}
Andorid-BOOTABLE, ${HASH_BOOTABLE}
Andorid-DEVELOPMENT, ${HASH_DEVELOPMENT}
Andorid-EXTERNAL, ${HASH_EXTERNAL}
Andorid-FRAMEWORKS, ${HASH_FRAMEWORKS}
Andorid-HARDWARE, ${HASH_HARDWARE}
Andorid-PACKAGES, ${HASH_PACKAGES}
Andorid-SYSTEM, ${HASH_SYSTEM}
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
	LOG2_FILE="$NEW_MACHINE"_Build2.log
	LOG3_FILE="$NEW_MACHINE"_Build3.log

	if [ "$1" == "android" ]; then
		#make -j4 droid otapackage 2>> $CURR_PATH/$ROOT_DIR/$LOG_FILE
		make -j8 bootloader 2>> $CURR_PATH/$ROOT_DIR/$LOG_FILE
		make -j8 bootimage 2>> $CURR_PATH/$ROOT_DIR/$LOG2_FILE
		make -j8 2>> $CURR_PATH/$ROOT_DIR/$LOG3_FILE
	else
		make -j8 $1 2>> $CURR_PATH/$ROOT_DIR/$LOG_FILE
	fi
	[ "$?" -ne 0 ] && echo "[ADV] Build failure! Check log file '$LOG_FILE'" && exit 1
}

function patches_android_code()
{
	echo "[ADV] patches_android_Uboot_code [STEP1]"
	cd $CURR_PATH/$ROOT_DIR/vendor/nxp-opensource/uboot-imx
	patch -p1 <../../../patches_android_9.0.0_r35/9001-Uboot_Yocto_4.14.98_2.0.0-to-android-9.0.0_r35.patch

	echo "[ADV] patches_android_Kernel_code"
	cd $CURR_PATH/$ROOT_DIR/vendor/nxp-opensource/kernel_imx
	patch -p1 <../../../patches_android_9.0.0_r35/9001-Linux_Yocto_4.14.98_2.0.0-to-android-9.0.0_r35.patch
}

function set_environment()
{
	echo "[ADV] set environment"

	cd $CURR_PATH/$ROOT_DIR
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/
	source build/envsetup.sh

	if [ "$1" == "sdk" ]; then
		lunch sdk-userdebug
	elif [ "$NEW_MACHINE" == "imx6" ]; then
		lunch rsb_4411_a1-userdebug
	else
		if [ "$TYPE" == "" ]; then
			lunch $NEW_MACHINE-userdebug
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
	#building otapackage
}

function prepare_images()
{
	cd $CURR_PATH

	IMAGE_DIR="AI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
	echo "[ADV] mkdir $IMAGE_DIR"
	mkdir $IMAGE_DIR
	mkdir $IMAGE_DIR/image

	# Copy image files to image directory
	cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/obj/UBOOT_OBJ/u-boot_crc.bin $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/obj/UBOOT_OBJ/u-boot_crc.bin.crc $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/boot.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/dtbo-imx6q.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/partition-table.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/recovery-imx6q.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/system.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/vbmeta-imx6q.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/vendor.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/out/target/product/$NEW_MACHINE/fsl-sdcard-partition.sh $IMAGE_DIR/image
	cp -a /usr/bin/simg2img $IMAGE_DIR/image

	echo "[ADV] creating ${IMAGE_DIR}.tgz ..."
	tar -zcvf ${IMAGE_DIR}.tar.gz $IMAGE_DIR
	generate_md5 ${IMAGE_DIR}.tar.gz
}

function copy_image_to_storage()
{
	echo "[ADV] copy images to $OUTPUT_DIR"
	generate_csv ${IMAGE_DIR}.tar.gz
	mv ${IMAGE_DIR}.csv $OUTPUT_DIR
	mv -f ${IMAGE_DIR}.tar.gz $OUTPUT_DIR
	mv -f *.md5 $OUTPUT_DIR
}

# ================
#  Main procedure 
# ================
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

echo "[ADV] patches android source code"
patches_android_code

echo "[ADV] build images"
for NEW_MACHINE in $MACHINE_LIST
do
	echo "[ADV] build android images"
	build_android_images
	echo "[ADV] perpare_image"
	prepare_images
	echo "[ADV] copy_image_to_storage"
	copy_image_to_storage
	echo "[ADV] save_temp_log"
	save_temp_log
done

# Copy downloads to backup
#if [ ! -e $CURR_PATH/downloads ] ; then
#    echo "[ADV] backup 'downloads' directory"
#    cp -a $CURR_PATH/$ROOT_DIR/downloads $CURR_PATH
#fi

cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

