#!/bin/bash
PRODUCT=$1

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] PLATFORM_PREFIX = ${PLATFORM_PREFIX}"
echo "[ADV] VERSION_NUMBER=$VERSION_NUMBER"

CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
IMAGE_DIR="out"
IMAGE_VER="${MODEL_NAME}${BOARD_VER}${AIM_VERSION}UIV${RELEASE_VERSION}_${DATE}"

# ===========
#  Functions
# ===========
function get_source_code()
{
	echo "[ADV] get source code"
	mkdir $ROOT_DIR
	pushd $ROOT_DIR 2>&1 > /dev/null
	repo init -u $BSP_URL -b main -m ${BSP_XML}
	repo sync -c -j8
	popd
}

function build_image()
{
	cd $CURR_PATH/$ROOT_DIR 2>&1 > /dev/null
	echo "[ADV] building ..."
	scripts/build_release.sh -a
}

function generate_md5()
{
	FILENAME=$1

	if [ -e $FILENAME ]; then
		MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
		echo $MD5_SUM > $FILENAME.md5
	fi
}

function prepare_images()
{
	echo "[ADV] creating ${IMAGE_VER}.tgz ..."
	pushd $CURR_PATH/$ROOT_DIR/ 2>&1 > /dev/null
	mv ${IMAGE_DIR} ./${IMAGE_VER}
	sudo tar czf ${IMAGE_VER}.tgz $IMAGE_VER
	generate_md5 ${IMAGE_VER}.tgz
	popd
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
	
	pushd $CURR_PATH/$ROOT_DIR 2>&1 > /dev/null

	HASH_BOOT_FW=$(cd boot-firmware && git rev-parse --short HEAD)
	HASH_BSP=$(cd .repo/manifests && git rev-parse --short HEAD)
	HASH_DOWNLOAD=$(cd download && git rev-parse --short HEAD)
	HASH_KERNEL=$(cd kernel && git rev-parse --short HEAD)
	HASH_IOT_YOCTO=$(cd iot-yocto-v23.1 && git rev-parse --short HEAD)
	HASH_SCRIPTS=$(cd scripts && git rev-parse --short HEAD)

	cat > ${FILENAME}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Ubuntu 22.04
Part Number,N/A
Author,
Date,${DATE}
Build Number,"${BUILD_NUMBER}"
TAG,
Tested Platform,${PRODUCT}
MD5 Checksum,TGZ: ${MD5_SUM}
Image Size,${FILE_SIZE}B (${FILE_SIZE_BYTE} bytes)
Issue description, N/A
Function Addition,
Manifest, ${HASH_BSP}

MTK_UBUNTU_BOOT_FW, ${HASH_BOOT_FW}
MTK_UBUNTU_DOWNLOAD, ${HASH_DOWNLOAD}
MTK_UBUNTU_KERNEL, ${HASH_KERNEL}
MTK_UBUNTU_IOT_YOCTO, ${HASH_IOT_YOCTO}
MTK_UBUNTU_SCRIPTS, ${HASH_SCRIPTS}

END_OF_CSV

	popd
}

function copy_image_to_storage()
{
	echo "[ADV] copy images to $OUTPUT_DIR"
	pushd $CURR_PATH/$ROOT_DIR 2>&1 > /dev/null
	generate_csv ${IMAGE_VER}.tgz
	mv ${IMAGE_VER}.tgz.csv $OUTPUT_DIR
	mv -f ${IMAGE_VER}.tgz $OUTPUT_DIR
	mv -f *.md5 $OUTPUT_DIR
	popd
}

function save_temp_log()
{
	LOG_DIR="log"
	LOG_FILE="${IMAGE_VER}"_log
	pushd $CURR_PATH/$ROOT_DIR 2>&1 > /dev/null
	echo "[ADV] creating ${LOG_FILE}.tgz ..."
	sudo tar czf $LOG_FILE.tgz $LOG_DIR
	generate_md5 $LOG_FILE.tgz
	mv -f $LOG_FILE.tgz $OUTPUT_DIR
	mv -f $LOG_FILE.tgz.md5 $OUTPUT_DIR
	sudo rm -rf $LOG_DIR
	popd
}

# ================
#  Main procedure
# ================

# Make storage folder
if [ -e $OUTPUT_DIR ] ; then
	echo "[ADV] $OUTPUT_DIR had already been created"
else
	echo "[ADV] mkdir $OUTPUT_DIR"
	mkdir -p $OUTPUT_DIR
fi

get_source_code
build_image
prepare_images
copy_image_to_storage
save_temp_log
cd $CURR_PATH
echo "[ADV] build script done!"
