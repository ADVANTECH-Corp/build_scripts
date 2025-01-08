#!/bin/bash
PRODUCT=$1

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] PLATFORM_PREFIX = ${PLATFORM_PREFIX}"
echo "[ADV] TARGET_BOARD=$TARGET_BOARD"
echo "[ADV] PROJECT=$PROJECT"
echo "[ADV] OS_VERSION=$OS_VERSION"
echo "[ADV] KERNEL_VERSION=$KERNEL_VERSION"
echo "[ADV] SOC_MEM=$SOC_MEM"
echo "[ADV] STORAGE=$STORAGE"
echo "[ADV] RELEASE_VERSION=$RELEASE_VERSION"

CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${TARGET_BOARD}_${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
LINUX_TEGRA="Linux_for_Tegra"
IMAGE_VER="${PROJECT}_${OS_VERSION}${RELEASE_VERSION}_${KERNEL_VERSION}_${SOC_MEM}_${STORAGE}_${DATE}"

# ===========
#  Functions
# ===========
function get_source_code()
{
	echo "[ADV] get nVidia source code"
	mkdir $ROOT_DIR
	pushd $ROOT_DIR 2>&1 > /dev/null
	repo init -u $BSP_URL -m ${BSP_XML}
	repo sync -j8
	popd
}

function build_image()
{
	cd $CURR_PATH/$ROOT_DIR 2>&1 > /dev/null
	echo "[ADV] building ..."
	sudo ./scripts/build_release.sh -v ${RELEASE_VERSION}
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

	sudo tar czf ${IMAGE_VER}.tgz $LINUX_TEGRA
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

	HASH_BSP=$(cd .repo/manifests && git rev-parse --short HEAD)
	HASH_DOWNLOAD=$(cd download && git rev-parse --short HEAD)
	HASH_KERNEL=$(cd kernel && git rev-parse --short HEAD)
	HASH_LINUX_FOR_TEGRA=$(cd Linux_for_Tegra && git rev-parse --short HEAD)
	HASH_SCRIPTS=$(cd scripts && git rev-parse --short HEAD)
	HASH_TOOLS=$(cd tools && git rev-parse --short HEAD)

	cat > ${FILENAME}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Ubuntu,${OS_VERSION}
Part Number,N/A
Author,
Date,${DATE}
Build Number,"${RELEASE_VERSION}"
TAG,
Tested Platform,${PRODUCT}
MD5 Checksum,TGZ: ${MD5_SUM}
Image Size,${FILE_SIZE}B (${FILE_SIZE_BYTE} bytes)
Issue description, N/A
Function Addition,
Manifest, ${HASH_BSP}

JETSON_DOWNLOAD, ${HASH_DOWNLOAD}
JETSON_KERNEL, ${HASH_KERNEL}
JETSON_L4T, ${HASH_LINUX_FOR_TEGRA}
JETSON_SCRIPTS, ${HASH_SCRIPTS}
JETSON_TOOLS, ${HASH_TOOLS}

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

export GIT_SSL_NO_VERIFY=1
sudo apt-get update
sudo apt-get install flex bison device-tree-compiler sshpass abootimg nfs-kernel-server uuid-runtime -y

get_source_code
build_image
prepare_images
copy_image_to_storage
save_temp_log
cd $CURR_PATH
echo "[ADV] build script done!"

