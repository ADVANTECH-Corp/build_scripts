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
echo "[ADV] OS_BSP=$OS_BSP"
echo "[ADV] DISTRO=$DISTRO"
echo "[ADV] KERNEL_VERSION=$KERNEL_VERSION"
echo "[ADV] CHIP_NAME=$CHIP_NAME"
echo "[ADV] RAM_SIZE=$RAM_SIZE"
echo "[ADV] STORAGE=$STORAGE"
echo "[ADV] KERNEL_PATH = ${KERNEL_PATH}"
echo "[ADV] YOCTO_MACHINE_NAME=$YOCTO_MACHINE_NAME"
echo "[ADV] DISTRO_IMAGE = ${DISTRO_IMAGE}"

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

if [ ${#STORAGE} -ne 4 ]; then
    echo "${STORAGE} storage is not 4 characters"
    exit 1
fi

if [ ${#DATE} -ne 10 ]; then
    echo "${DATE} date is not 10 characters"
    exit 1
fi

CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${PROJECT}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
IMAGE_VER=""
UFS_IMAGE_VER=""
EMMC_IMAGE_VER=""

# QIMP
#YOCTO_IMAGE_DIR="$CURR_PATH/$ROOT_DIR/build-qcom-wayland/tmp-glibc/deploy/images/${YOCTO_MACHINE_NAME}"
# QIRP
YOCTO_IMAGE_DIR="$CURR_PATH/$ROOT_DIR/build-qcom-robotics-ros2-humble/tmp-glibc/deploy/images/${YOCTO_MACHINE_NAME}"

# ===========
#  Functions
# ===========
function get_source_code()
{
	echo "[ADV] get qcs source code"
	mkdir $ROOT_DIR
	pushd $ROOT_DIR 2>&1 > /dev/null
	repo init -u $BSP_URL -b main -m ${BSP_XML}
	repo sync -c -j8
	repo sync -c -j8
	repo sync -c -j8
	popd
}

function get_release_version_and_set_image_version()
{
	pushd $CURR_PATH/$ROOT_DIR/.repo/manifests 2>&1 > /dev/null
	RELEASE_VERSION="01"

	for file in *; do
		if echo "$file" | grep -q "${PROJECT}_${OS_BSP}${DISTRO}"; then
			RELEASE_VERSION=$(($(echo "ibase=10; $(echo "$file" | cut -c16-17)" | bc) + 1))
			if ((RELEASE_VERSION >= 2 && RELEASE_VERSION <= 9)); then
				RELEASE_VERSION=$(printf "%02d" $RELEASE_VERSION)
			fi
		fi
	done

	echo "RELEASE_VERSION = $RELEASE_VERSION"
	popd 2>&1 > /dev/null

	IMAGE_VER="${PROJECT}_${OS_BSP}${DISTRO}${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_${DATE}"
	UFS_IMAGE_VER="${PROJECT}_${OS_BSP}${DISTRO}${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_${STORAGE}_${DATE}"
	EMMC_IMAGE_VER="${PROJECT}_${OS_BSP}${DISTRO}${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_emmc_${DATE}"
}

function add_version()
{
	# Set Linux version
	echo "[ADV] add linux version"
	OFFICIAL_VER="${OS_BSP}${DISTRO}${RELEASE_VERSION}"
	sed -i "/LINUX_VERSION_EXTENSION =/d" $ROOT_DIR/$KERNEL_PATH
	echo "LINUX_VERSION_EXTENSION = \"-$OFFICIAL_VER\"" >> $ROOT_DIR/$KERNEL_PATH
	cat $ROOT_DIR/$KERNEL_PATH
}

function get_downloads()
{
	echo "[ADV] get yocto downloads"
	sudo mv $CURR_PATH/downloads $CURR_PATH/$ROOT_DIR/downloads
}

function set_environment()
{
	cd $CURR_PATH/$ROOT_DIR 2>&1 > /dev/null
	echo "[ADV] set environment"
	source scripts/env.sh
}

function build_image()
{
	cd $CURR_PATH/$ROOT_DIR 2>&1 > /dev/null
	echo "[ADV] building ..."
	scripts/build_release.sh -all -${YOCTO_MACHINE_NAME} -${DISTRO_IMAGE}
}

function generate_md5()
{
	FILENAME=$1

	if [ -e $FILENAME ]; then
		MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
		echo $MD5_SUM > $FILENAME.md5
	fi
}

function prepare_and_copy_images()
{
	echo "[ADV] creating ${UFS_IMAGE_VER}.tgz and ${EMMC_IMAGE_VER}.tgz..."

	pushd $YOCTO_IMAGE_DIR 2>&1 > /dev/null
	# QIMP
	#mv qcom-multimedia-image ${UFS_IMAGE_VER}
	#mv qcom-multimedia-image-emmc ${EMMC_IMAGE_VER}
	
	# QIRP
	mv qcom-robotics-full-image ${UFS_IMAGE_VER}
        mv qcom-robotics-full-image-emmc ${EMMC_IMAGE_VER}
	sudo tar czf ${UFS_IMAGE_VER}.tgz $UFS_IMAGE_VER
	sudo tar czf ${EMMC_IMAGE_VER}.tgz $EMMC_IMAGE_VER
	generate_md5 ${UFS_IMAGE_VER}.tgz
	generate_md5 ${EMMC_IMAGE_VER}.tgz
	mv -f ${UFS_IMAGE_VER}.tgz* $OUTPUT_DIR
	mv -f ${EMMC_IMAGE_VER}.tgz* $OUTPUT_DIR
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

	HASH_AMSS=$(cd amss && git rev-parse HEAD)
	HASH_BSP=$(cd .repo/manifests && git rev-parse HEAD)
	HASH_DOWNLOAD=$(cd download && git rev-parse HEAD)
	HASH_KERNEL=$(cd build-qcom-robotics-ros2-humble/tmp-glibc/work-shared/${YOCTO_MACHINE_NAME}/kernel-source && git rev-parse HEAD)
	HASH_META_ADVANTECH=$(cd layers/meta-advantech && git rev-parse HEAD)
	HASH_META_QCOM_EXTRAS=$(cd layers/meta-qcom-extras && git rev-parse HEAD)
	HASH_META_QCOM_ROBOTICS_EXTRAS=$(cd layers/meta-qcom-robotics-extras && git rev-parse HEAD)
	HASH_SCRIPTS=$(cd scripts && git rev-parse HEAD)

	cat > ${FILENAME}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Qualcomm linux ${OS_BSP}${DISTRO}
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

QCS_AMSS, ${HASH_AMSS}
QCS_DOWNLOAD, ${HASH_DOWNLOAD}
QCS_LINUX_QCOM, ${HASH_KERNEL}
QCS_META_ADVANTECH, ${HASH_META_ADVANTECH}
QCS_META_QCOM_EXTRAS, ${HASH_META_QCOM_EXTRAS}
QCS_META_QCOM_ROBOTICS_EXTRAS, ${HASH_META_QCOM_ROBOTICS_EXTRAS}
QCS_SCRIPTS, ${HASH_SCRIPTS}

END_OF_CSV

	popd
}

function prepare_and_copy_csv()
{
	echo "[ADV] creating csv files ..."
	pushd $CURR_PATH/$ROOT_DIR/ 2>&1 > /dev/null
	generate_csv ${IMAGE_VER}
	generate_md5 ${IMAGE_VER}.csv
	mv -f ${IMAGE_VER}.csv* $OUTPUT_DIR
	popd
}

function prepare_and_copy_log()
{
	LOG_DIR="log"
	LOG_FILE="${IMAGE_VER}"_log
	pushd $CURR_PATH/$ROOT_DIR 2>&1 > /dev/null
	echo "[ADV] creating ${LOG_FILE}.tgz ..."
	sudo tar czf $LOG_FILE.tgz $LOG_DIR
	generate_md5 $LOG_FILE.tgz
	mv -f $LOG_FILE.tgz* $OUTPUT_DIR
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

#prepare source code and build environment
get_source_code
get_release_version_and_set_image_version
add_version
get_downloads
set_environment
build_image
prepare_and_copy_images
prepare_and_copy_csv
prepare_and_copy_log

cd $CURR_PATH
echo "[ADV] build script done!"
