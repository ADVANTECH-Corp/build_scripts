#!/bin/bash
PRODUCT=$1

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] PLATFORM_PREFIX = ${PLATFORM_PREFIX}"
echo "[ADV] PROJECT=$PROJECT"
echo "[ADV] OS_DISTRO=$OS_DISTRO"
echo "[ADV] KERNEL_VERSION=$KERNEL_VERSION"
echo "[ADV] CHIP_NAME=$CHIP_NAME"
echo "[ADV] RAM_SIZE=$RAM_SIZE"
echo "[ADV] STORAGE=$STORAGE"
echo "[ADV] RELEASE_VERSION=$RELEASE_VERSION"
echo "[ADV] KERNEL_PATH = ${KERNEL_PATH}"
echo "[ADV] DISTRO_IMAGE = ${DISTRO_IMAGE}"
echo "[ADV] SDK_TYPE = $SDK_TYPE"

CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${PROJECT}_v${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_${STORAGE}_${DATE}"
SPDX_DIR="${IMAGE_VER}_spdx"

if [[ "$CHIP_NAME" == *"qcs6490"* ]]; then
    YOCTO_MACHINE_NAME="qcs6490${PROJECT}"
fi

YOCTO_IMAGE_DIR="$CURR_PATH/$ROOT_DIR/build-qcom-robotics-ros2-humble/tmp-glibc/deploy/images/${YOCTO_MACHINE_NAME}"

# ===========
#  Functions
# ===========
function get_source_code()
{
	echo "[ADV] get qcs source code"
	mkdir $ROOT_DIR
	pushd $ROOT_DIR 2>&1 > /dev/null
	repo init -u $BSP_URL -b ${BSP_BRANCH} -m ${BSP_XML}
	repo sync -c -j8
	repo sync -c -j8
	popd
}

function update_oeminfo()
{
    local ini_file="$ROOT_DIR/layers/meta-advantech-qualcomm/recipes-products/images/files/common/rootfs/etc/OEMInfo.ini"

    if [ ! -f "$ini_file" ]; then
        echo "[ERROR] File $ini_file not found!"
        return 1
    fi

    echo "[INFO] Updating OEMInfo.ini ..."
    echo "[INFO] Chip_Name: ${CHIP_NAME}"
    echo "[INFO] Product_Name: ${PROJECT}"
    echo "[INFO] Ram_Size: ${RAM_SIZE}"
    echo "[INFO] OS_Distro: ${OS_DISTRO}"
    echo "[INFO] Kernel_Version: ${KERNEL_VERSION}"
    echo "[INFO] Build_Date: $DATE"
    echo "[INFO] Image_Version: v${RELEASE_VERSION}"
    echo "[INFO] STORAGE: $STORAGE"

    # Convert values: replace + with ", " and uppercase
    local chip_name_value=$(echo "$CHIP_NAME" | sed 's/+/, /g' | tr '[:lower:]' '[:upper:]')
    local ram_size_value=$(echo "$RAM_SIZE" | sed 's/+/, /g' | tr '[:lower:]' '[:upper:]')
    local storage_value=$(echo "$STORAGE" | sed 's/+/, /g' | tr '[:lower:]' '[:upper:]')

    # Update Chip_Name
    sed -i "s/^Chip_Name:.*/Chip_Name: ${chip_name_value}/" "$ini_file"
    # Update Product_Name
    sed -i "s/^Product_Name:.*/Product_Name: ${PROJECT^^}/" "$ini_file"
    # Update Ram_Size
    sed -i "s/^Ram_Size:.*/Ram_Size: ${ram_size_value}/" "$ini_file"
    # Update OS_Distro
    sed -i "s/^OS_Distro:.*/OS_Distro: ${OS_DISTRO^^}/" "$ini_file"
    # Update Kernel_Version
    sed -i "s/^Kernel_Version:.*/Kernel_Version: ${KERNEL_VERSION#kernel-}/" "$ini_file"
    # Update Build_Date
    sed -i "s/^Build_Date:.*/Build_Date: $DATE/" "$ini_file"
    # Update Image_Version
    sed -i "s/^Image_Version:.*/Dailybuild_Image_Version: V${RELEASE_VERSION}/" "$ini_file"
    # Update Storage
    sed -i "s/^Storage:.*/Storage: ${storage_value}/" "$ini_file"

    echo "[INFO] Done updating $ini_file."
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

	if [ "$DISTRO_IMAGE" = "debug" ]; then
		export DEBUG_BUILD=1
	fi

	MACHINE=${YOCTO_MACHINE_NAME} DISTRO=qcom-robotics-ros2-humble QCOM_SELECTED_BSP=custom source setup-robotics-environment
}

function build_image()
{
	echo "[ADV] Check cuurent path"
	pwd
	
	echo "[ADV] building ..."
	bitbake-layers add-layer ../layers/meta-advantech-qualcomm

	if [ "$SDK_TYPE" = "QIMP" ]; then
		bitbake qcom-multimedia-image
	elif [ "$SDK_TYPE" = "QIRP" ]; then
		echo "[ADV] building QIRP ..."
		../qirp-build qcom-robotics-full-image
	else
		echo "Error: Unknown SDK_TYPE ($SDK_TYPE)"
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

function prepare_and_copy_images()
{
	echo "[ADV] creating ${IMAGE_VER}.tgz..."

	pushd $YOCTO_IMAGE_DIR 2>&1 > /dev/null
	if [ "$SDK_TYPE" = "QIMP" ]; then
		mv qcom-multimedia-image ${IMAGE_VER}
	elif [ "$SDK_TYPE" = "QIRP" ]; then
		mv qcom-robotics-full-image ${IMAGE_VER}
	else
		echo "Error: Unknown SDK_TYPE ($SDK_TYPE)"
		popd
		exit 1
	fi

	sudo tar czf ${IMAGE_VER}.tgz ${IMAGE_VER}

	generate_md5 ${IMAGE_VER}.tgz

	mv -f ${IMAGE_VER}.tgz* $OUTPUT_DIR

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

	HASH_BSP=$(cd .repo/manifests && git rev-parse HEAD)
	HASH_KERNEL=$(cd build-qcom-robotics-ros2-humble/tmp-glibc/work-shared/${YOCTO_MACHINE_NAME}/kernel-source && git rev-parse HEAD)
	HASH_META_ADVANTECH=$(cd layers/meta-advantech-qualcomm && git rev-parse HEAD)

	cat > ${FILENAME}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Qualcomm linux ${OS_BSP}${DISTRO}
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

QCS_LINUX_QCOM, ${HASH_KERNEL}
QCS_META_ADVANTECH, ${HASH_META_ADVANTECH}

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

function prepare_and_copy_spdx()
{
	echo "[ADV] create sbom SPDX files"

	if compgen -G "${YOCTO_IMAGE_DIR}/*.spdx.tar.zst" > /dev/null; then
		cp -fpv "$YOCTO_IMAGE_DIR"/*.spdx.tar.zst "$SPDX_DIR/"
	fi

	echo "[ADV] creating ${SPDX_DIR}.tgz ..."
	tar czf "${SPDX_DIR}.tgz" "$SPDX_DIR"
	generate_md5 "${SPDX_DIR}.tgz"
	mv -f "${SPDX_DIR}.tgz"* "$OUTPUT_DIR"
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
get_downloads
set_environment
build_image
prepare_and_copy_images
prepare_and_copy_csv
prepare_and_copy_spdx

cd $CURR_PATH
echo "[ADV] build script done!"
