#!/bin/bash
PRODUCT=$1

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] PLATFORM_PREFIX = ${PLATFORM_PREFIX}"
echo "[ADV] OS_DISTRO=$OS_DISTRO"
echo "[ADV] KERNEL_VERSION=$KERNEL_VERSION"
echo "[ADV] CHIP_NAME=$CHIP_NAME"
echo "[ADV] RAM_SIZE=$RAM_SIZE"
echo "[ADV] STORAGE=$STORAGE"
echo "[ADV] RELEASE_VERSION=$RELEASE_VERSION"
echo "[ADV] UBUNTU_MACHINE=$UBUNTU_MACHINE"
echo "[ADV] DISTRO_IMAGE = ${DISTRO_IMAGE}"
echo "[ADV] BUILD_RELEASE_TYPE=$BUILD_RELEASE_TYPE"

CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${UBUNTU_MACHINE}_v${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
IMAGE_VER="${UBUNTU_MACHINE}_${OS_DISTRO}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_${DATE}"
UFS_IMAGE_VER="${UBUNTU_MACHINE}_${OS_DISTRO}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_${STORAGE}_${DATE}"
EMMC_IMAGE_VER="${UBUNTU_MACHINE}_${OS_DISTRO}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_emmc_${DATE}"

# Ubuntu
UBUNTU_IMAGE_DIR="$CURR_PATH/$ROOT_DIR/images/${UBUNTU_MACHINE}"

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

function update_oeminfo()
{
    local ini_file="$ROOT_DIR/tools/oeminfo/OEMInfo.ini"

    if [ ! -f "$ini_file" ]; then
        echo "[ERROR] File $ini_file not found!"
        return 1
    fi

    echo "[INFO] Updating OEMInfo.ini ..."
    echo "[INFO] Chip_Name: ${CHIP_NAME}"
    echo "[INFO] Product_Name: ${UBUNTU_MACHINE}"
    echo "[INFO] Ram_Size: ${RAM_SIZE}"
    echo "[INFO] OS_Distro: ${OS_DISTRO}"
    echo "[INFO] Kernel_Version: ${KERNEL_VERSION}"
    echo "[INFO] Build_Date: $DATE"
    echo "[INFO] Image_Version: v${RELEASE_VERSION}"

    # 更新 Chip_Name
    sed -i "s/^Chip_Name:.*/Chip_Name: ${CHIP_NAME^^}/" "$ini_file"
    # 更新 Product_Name
    sed -i "s/^Product_Name:.*/Product_Name: ${UBUNTU_MACHINE^^}/" "$ini_file"
    # 更新 Ram_Size
    sed -i "s/^Ram_Size:.*/Ram_Size: ${RAM_SIZE^^}/" "$ini_file"
    # 更新 OS_Distro
    sed -i "s/^OS_Distro:.*/OS_Distro: ${OS_DISTRO^^}/" "$ini_file"
    # 更新 Kernel_Version
    sed -i "s/^Kernel_Version:.*/Kernel_Version: ${KERNEL_VERSION#kernel-}/" "$ini_file"
    # 更新 Build_Date
    sed -i "s/^Build_Date:.*/Build_Date: $DATE/" "$ini_file"
    # 更新 Image_Version
    sed -i "s/^Image_Version:.*/Dailybuild_Image_Version: V${RELEASE_VERSION}/" "$ini_file"

    echo "[INFO] Done updating $ini_file."
}

function build_image()
{
	cd $CURR_PATH/$ROOT_DIR 2>&1 > /dev/null
	echo "[ADV] building ..."
	scripts/build_release.sh -${BUILD_RELEASE_TYPE} -${UBUNTU_MACHINE} -${DISTRO_IMAGE}
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
	echo "[ADV] creating ${UFS_IMAGE_VER}.tgz."

	pushd $UBUNTU_IMAGE_DIR 2>&1 > /dev/null
	# QIMP
	# mv qcom-multimedia-image ${UFS_IMAGE_VER}
	# mv qcom-multimedia-image-emmc ${EMMC_IMAGE_VER}
	
	# QIRP
	# mv qcom-robotics-full-image ${UFS_IMAGE_VER}
	# mv qcom-robotics-full-image-emmc ${EMMC_IMAGE_VER}
	# sudo tar czf ${UFS_IMAGE_VER}.tgz $UFS_IMAGE_VER
	# sudo tar czf ${EMMC_IMAGE_VER}.tgz $EMMC_IMAGE_VER
	# generate_md5 ${UFS_IMAGE_VER}.tgz
	# generate_md5 ${EMMC_IMAGE_VER}.tgz
	# mv -f ${UFS_IMAGE_VER}.tgz* $OUTPUT_DIR
	# mv -f ${EMMC_IMAGE_VER}.tgz* $OUTPUT_DIR

	# Ubuntu
	# UFS
	mv qcom-ubuntu-full-image ${UFS_IMAGE_VER}
	sudo tar czf ${UFS_IMAGE_VER}.tgz $UFS_IMAGE_VER
	generate_md5 ${UFS_IMAGE_VER}.tgz
	mv -f ${UFS_IMAGE_VER}.tgz* $OUTPUT_DIR
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

	HASH_BOOT_FW=$(cd boot-firmware && git rev-parse HEAD)
	HASH_BSP=$(cd .repo/manifests && git rev-parse HEAD)
	HASH_DOWNLOAD=$(cd download && git rev-parse HEAD)
	HASH_KERNEL=$(cd noble && git rev-parse HEAD)
	HASH_SCRIPTS=$(cd scripts && git rev-parse HEAD)
	HASH_TOOLS=$(cd tools && git rev-parse HEAD)

	cat > ${FILENAME}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Ubuntu ${OS_BSP}${DISTRO}
Part Number,N/A
Author,
Date,${DATE}
Build Number,"v${RELEASE_VERSION}"
TAG,
Tested Platform,${PRODUCT}
MD5 Checksum,TGZ: ${MD5_SUM}
Image Size,${FILE_SIZE}B (${FILE_SIZE_BYTE} bytes)
Issue description, N/A
Function Addition,
Manifest, ${HASH_BSP}

QCS_BOOT_FW, ${HASH_BOOT_FW}
QCS_DOWNLOAD, ${HASH_DOWNLOAD}
QCS_UBUNTU, ${HASH_KERNEL}
QCS_SCRIPTS, ${HASH_SCRIPTS}
QCS_TOOLS, ${HASH_TOOLS}

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
update_oeminfo
build_image
prepare_and_copy_images
prepare_and_copy_csv
prepare_and_copy_log

cd $CURR_PATH
echo "[ADV] build script done!"
