#!/bin/bash

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] PROJECT=${PROJECT}"
echo "[ADV] OS_DISTRO=${OS_DISTRO}"
echo "[ADV] KERNEL_VERSION=${KERNEL_VERSION}"
echo "[ADV] CHIP_NAME=${CHIP_NAME}"
echo "[ADV] MEMORY_LIST=${MEMORY_LIST}"
echo "[ADV] STORAGE=${STORAGE}"
echo "[ADV] RELEASE_VERSION=${RELEASE_VERSION}"
echo "[ADV] DEPLOY_IMAGE_NAME = ${DEPLOY_IMAGE_NAME}"
echo "[ADV] BACKEND_TYPE = ${BACKEND_TYPE}"
echo "[ADV] U_BOOT_VERSION = ${U_BOOT_VERSION}"
echo "[ADV] META_ADVANTECH_PATH = ${META_ADVANTECH_PATH}"
echo "[ADV] IMX_IMAGE_CORE_BB_PATH = ${IMX_IMAGE_CORE_BB_PATH}"
echo "[ADV] IMX_IMAGE_FULL_BB_PATH = ${IMX_IMAGE_FULL_BB_PATH}"
echo "[ADV] YOCTO_BUILD_DIR = ${YOCTO_BUILD_DIR}"

CURR_PATH="$PWD"
AIM_LINUX_TAG_VER="${PROJECT}_${OS_DISTRO}_v${RELEASE_VERSION}_kernel-${KERNEL_VERSION}_${CHIP_NAME}"
AIM_LINUX_NO_RAM_SIZE_VER="${PROJECT}_${OS_DISTRO}_v${RELEASE_VERSION}_kernel-${KERNEL_VERSION}_${CHIP_NAME}_${STORAGE}_${DATE}"

ROOT_DIR="${AIM_LINUX_TAG_VER}"
BSP_DIR="${AIM_LINUX_NO_RAM_SIZE_VER}"_bsp
LOG_DIR="${AIM_LINUX_NO_RAM_SIZE_VER}"_log
MODULES_DIR="${AIM_LINUX_NO_RAM_SIZE_VER}"_modules
CVE_DIR="${AIM_LINUX_NO_RAM_SIZE_VER}"_cve
SPDX_DIR="${AIM_LINUX_NO_RAM_SIZE_VER}"_spdx
IMAGE_DIR=""
FLASH_DIR=""
IMX_BOOT_DIR=""

DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/$YOCTO_BUILD_DIR/$TMP_DIR/deploy/images/${CHIP_NAME}${PROJECT}"
DEPLOY_IMX_BOOT_PATH="$CURR_PATH/$ROOT_DIR/$YOCTO_BUILD_DIR/$TMP_DIR/work/${CHIP_NAME}${PROJECT}-poky-linux/imx-boot/*/git"
DEPLOY_CVE_PATH="$CURR_PATH/$ROOT_DIR/$YOCTO_BUILD_DIR/$TMP_DIR/deploy/cve"
DEPLOY_MODULES_PATH="$CURR_PATH/$ROOT_DIR/$YOCTO_BUILD_DIR/$TMP_DIR/deploy/images/${CHIP_NAME}${PROJECT}"
DEPLOY_SPDX_PATH="$CURR_PATH/$ROOT_DIR/$YOCTO_BUILD_DIR/$TMP_DIR/deploy/spdx"

STORAGE_PATH="$CURR_PATH/$STORED/$DATE"
LOG_PATH="$CURR_PATH/$ROOT_DIR/$YOCTO_BUILD_DIR"
PRE_MEMORY=""
MEMORY=""

# ===========
#  Functions
# ===========
function get_source_code()
{
    echo "[ADV] get yocto source code"
    cd $ROOT_DIR

    REPO_OPT="-u $BSP_URL"

    if [ ! -z "$BSP_BRANCH" ] ; then
        REPO_OPT="$REPO_OPT -b $BSP_BRANCH"
    fi
    if [ ! -z "$BSP_XML" ] ; then
        REPO_OPT="$REPO_OPT -m $BSP_XML"
    fi

    repo init $REPO_OPT 2>&1
    repo sync 2>&1

    cd $CURR_PATH
}

function update_oeminfo()
{
	cd $CURR_PATH

	# Set the folder
	case "${DEPLOY_IMAGE_NAME}" in
		imx-image-core)
			BASE_DIR="${CURR_PATH}/${ROOT_DIR}/${IMX_IMAGE_CORE_BB_PATH}"
			;;
		imx-image-full)
			BASE_DIR="${CURR_PATH}/${ROOT_DIR}/${IMX_IMAGE_FULL_BB_PATH}"
			;;
		*)
			echo "DEPLOY_IMAGE_NAME is neither imx-image-core nor imx-image-full, exit function."
			return 0
			;;
	esac

	FILES_DIR="${BASE_DIR}/files"
	INI_FILE="${FILES_DIR}/OEMInfo.ini"
	BB_FILE="${BASE_DIR}/${DEPLOY_IMAGE_NAME}.bbappend"

	# Create path
	mkdir -p "${FILES_DIR}"

	# Convert STORAGE format
	STORAGE_FORMATTED=$(echo "$STORAGE" | tr '[:lower:]' '[:upper:]' | sed 's/+/\, /g')

	if [ -f "${INI_FILE}" ]; then
		# OEMInfo.ini exists → only update Ram_Size
		echo "[INFO] Updating Ram_Size in existing OEMInfo.ini ..."
		sed -i "s/^Ram_Size:.*/Ram_Size: ${MEMORY^^}/" "${INI_FILE}"
		sed -i "s/^Storage:.*/Storage: ${STORAGE_FORMATTED}/" "${INI_FILE}"
		echo "[INFO] Done updating Ram_Size and Storage."
	else
		# OEMInfo.ini does not exist → create OEMInfo.ini and bbappend
		echo "[INFO] Creating new OEMInfo.ini and ${DEPLOY_IMAGE_NAME}.bbappend ..."

		cat > "${INI_FILE}" <<EOF
[General]
Manufacturer: Advantech, Inc.
Support_URL: www.advantech.com
[AIM_Linux_Release]
Platform_Name: NXP
Chip_Name: ${CHIP_NAME^^}
Product_Name: ${PROJECT^^}
Ram_Size: ${MEMORY^^}
Storage: ${STORAGE_FORMATTED}
OS_Distro: ${OS_DISTRO^^}
Image_Version: V${RELEASE_VERSION^^}
Kernel_Version: ${KERNEL_VERSION^^}
Build_Date: ${DATE^^}
EOF

		# Create bbappend
		cat > "${BB_FILE}" <<EOF
ADDON_FILES_DIR = "\${THISDIR}/files"

install_utils() {
	install -m 0644 \${ADDON_FILES_DIR}/OEMInfo.ini \${IMAGE_ROOTFS}/etc
}

ROOTFS_POSTPROCESS_COMMAND += "install_utils;"
EOF

		echo "[INFO] Files created successfully:"
		echo " - ${INI_FILE}"
		echo " - ${BB_FILE}"
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

function save_temp_log()
{
	cd $LOG_PATH

	echo "[ADV] mkdir $LOG_DIR"
	mkdir $LOG_DIR

	# Backup conf, run script & log file
	cp -a conf $LOG_DIR
	find $TMP_DIR/work -name "log.*_*" -o -name "run.*_*" | xargs -i cp -a --parents {} $LOG_DIR

	echo "[ADV] creating ${LOG_DIR}.tgz ..."
	tar czf $LOG_DIR.tgz $LOG_DIR
	generate_md5 $LOG_DIR.tgz

	mv -f $LOG_DIR.tgz $STORAGE_PATH
	mv -f $LOG_DIR.tgz.md5 $STORAGE_PATH

	# Remove all temp logs
	sudo rm -rf $LOG_DIR
	find . -name "temp" | xargs sudo rm -rf
}

# ===============================
#  Functions [platform specific]
# ===============================
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

    HASH_BSP=$(cd ${CURR_PATH}/${ROOT_DIR}/.repo/manifests && git rev-parse HEAD)
    HASH_ADV=$(cd ${CURR_PATH}/${ROOT_DIR}/${META_ADVANTECH_PATH} && git rev-parse HEAD)
    HASH_KERNEL=$(cd ${CURR_PATH}/${ROOT_DIR}/${YOCTO_BUILD_DIR}/${TMP_DIR}/work/${CHIP_NAME}${PROJECT}-poky-linux/linux-imx/${KERNEL_VERSION}*/git && git rev-parse HEAD)
    HASH_UBOOT=$(cd ${CURR_PATH}/${ROOT_DIR}/${YOCTO_BUILD_DIR}/${TMP_DIR}/work/${CHIP_NAME}${PROJECT}-poky-linux/u-boot-imx/*${U_BOOT_VERSION}*/git && git rev-parse HEAD)
    cd $CURR_PATH

    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Linux ${KERNEL_VERSION}
Part Number,N/A
Author,
Date,${DATE}
Version,${AIM_LINUX_TAG_VER}
Build Number,v${RELEASE_VERSION}
TAG,
Tested Platform,${CHIP_NAME}${PROJECT}
MD5 Checksum,TGZ: ${MD5_SUM}
Image Size,${FILE_SIZE}B (${FILE_SIZE_BYTE} bytes)
Issue description, N/A
Function Addition,
adv-arm-yocto-bsp, ${HASH_BSP}
meta-advantech, ${HASH_ADV}
linux-imx, ${HASH_KERNEL}
u-boot-imx, ${HASH_UBOOT}
END_OF_CSV
}

function building()
{
	echo "[ADV] building $1 $2..."

	if [ "x" != "x$2" ]; then
		bitbake $1 -c $2 -f
	else
		bitbake $1
	fi

	if [ "$?" -ne 0 ]; then
		echo "[ADV] Build failure! Check details in ${LOG_DIR}.tgz"
		save_temp_log
		exit 1
	fi
}

function set_environment()
{
	cd $CURR_PATH/$ROOT_DIR
	echo "[ADV] set environment"

	EULA=1 DISTRO=$BACKEND_TYPE MACHINE=${CHIP_NAME}${PROJECT} UBOOT_CONFIG=${PRE_MEMORY} source imx-setup-release.sh -b $YOCTO_BUILD_DIR
	echo 'BB_NUMBER_THREADS = "16"' >> conf/local.conf
	echo 'PARALLEL_MAKE = "-j 4"' >> conf/local.conf
}

function clean_yocto_packages()
{
	echo "[ADV] build_yocto_image: clean for virtual_libg2d"
	PACKAGE_LIST=" \
		gstreamer1.0-rtsp-server gst-examples freerdp \
		gstreamer1.0-plugins-good gstreamer1.0-plugins-base \
		gstreamer1.0-plugins-bad kmscube opencv imx-gst1.0-plugin \
		weston "

	for PACKAGE in ${PACKAGE_LIST}
	do
		building ${PACKAGE} cleansstate
	done

	echo "[ADV] build_yocto_image: clean for qt5"
	PACKAGE_LIST=" \
		qtbase-native qtbase qtdeclarative-native qtdeclarative qtwayland-native \
		qtwayland qt3d qt5compat qtquick3d-native qtquick3d qtshadertools-native \
		qtshadertools qtlanguageserver-native qtlanguageserver qtconnectivity \
		qtquicktimeline qtsvg "

	for PACKAGE in ${PACKAGE_LIST}
	do
		building ${PACKAGE} cleansstate
	done

	echo "[ADV] build_yocto_image: clean for other packages"
	building spirv-tools cleansstate
	building fmt cleansstate
}

function rebuild_bootloader()
{
	#rebuild bootloader
	BOOTLOADER_TYPE=$1

	echo "[ADV] Rebuild image for $BOOTLOADER_TYPE"
	echo "UBOOT_CONFIG = \"$BOOTLOADER_TYPE\"" >> $CURR_PATH/$ROOT_DIR/$YOCTO_BUILD_DIR/conf/local.conf
	building imx-atf cleansstate
	building optee-os cleansstate
	building $DEPLOY_IMAGE_NAME clean
	building $DEPLOY_IMAGE_NAME 

	sed -i "/UBOOT_CONFIG/d" $CURR_PATH/$ROOT_DIR/$YOCTO_BUILD_DIR/conf/local.conf
	cd  $CURR_PATH
}

function build_yocto_images()
{
	set_environment
	bitbake-layers add-layer ../sources/meta-advantech

	# Re-build U-Boot & kernel
	echo "[ADV] build_yocto_image: build u-boot"
	building u-boot-imx cleansstate
	building u-boot-imx

	echo "[ADV] build_yocto_image: build kernel"
	building linux-imx cleansstate
	building linux-imx

	# Clean package to avoid build error
	clean_yocto_packages

	# Build full image
	building $DEPLOY_IMAGE_NAME
}

function prepare_images() {
	cd $CURR_PATH

	IMAGE_TYPE=$1
	OUTPUT_DIR=$2
	echo "[ADV] prepare $IMAGE_TYPE image"

	if [ "$OUTPUT_DIR" == "" ]; then
		echo "[ADV] prepare_images: invalid parameter #2!"
		exit 1
	else
		echo "[ADV] mkdir $OUTPUT_DIR"
		mkdir $OUTPUT_DIR
	fi

	case $IMAGE_TYPE in
		"imx-boot")
			cp -a $DEPLOY_IMX_BOOT_PATH/* $OUTPUT_DIR
			chmod 755 $CURR_PATH/cp_uboot.sh
			chmod 755 $CURR_PATH/mk_imx-boot.sh
			sudo cp $CURR_PATH/cp_uboot.sh $OUTPUT_DIR
			sudo cp $CURR_PATH/mk_imx-boot.sh $OUTPUT_DIR
			;;
		"modules")
			FILE_NAME="modules-${CHIP_NAME}*.tgz"
			cp $DEPLOY_MODULES_PATH/$FILE_NAME $OUTPUT_DIR
			;;
		"normal")
			FILE_NAME=${DEPLOY_IMAGE_NAME}"-"${CHIP_NAME}${PROJECT}"*.rootfs.wic"
			unzstd -f $DEPLOY_IMAGE_PATH/$FILE_NAME.zst
			cp $DEPLOY_IMAGE_PATH/$FILE_NAME $OUTPUT_DIR
			;;
		"flash")
			mkdir $OUTPUT_DIR/image $OUTPUT_DIR/mk_inand
			# normal image
			FILE_NAME=${DEPLOY_IMAGE_NAME}"-"${CHIP_NAME}${PROJECT}"*.rootfs.wic"
			cp $DEPLOY_IMAGE_PATH/$FILE_NAME $OUTPUT_DIR/image
			chmod 755 $CURR_PATH/mksd-linux.sh
			sudo cp $CURR_PATH/mksd-linux.sh $OUTPUT_DIR/mk_inand/
			sudo rm $DEPLOY_IMAGE_PATH/$FILE_NAME && sync
			;;
		"cve")
			mkdir $OUTPUT_DIR/image
			mkdir $OUTPUT_DIR/cve
			sudo cp $DEPLOY_CVE_PATH/* $OUTPUT_DIR/cve
			sudo cp $DEPLOY_IMAGE_PATH/*.json $OUTPUT_DIR/image
			sudo cp $DEPLOY_IMAGE_PATH/*.cve $OUTPUT_DIR/image
			;;
		"spdx")
			mkdir $OUTPUT_DIR/image
			mkdir $OUTPUT_DIR/spdx
			sudo cp -r $DEPLOY_SPDX_PATH/* $OUTPUT_DIR/spdx
			sudo cp $DEPLOY_IMAGE_PATH/*.spdx.tar.zst $OUTPUT_DIR/image
			;;
		"bsp")			
			;;
		*)
			echo "[ADV] prepare_images: invalid parameter #1!"
			exit 1
			;;
	esac

	# Package image file
	case $IMAGE_TYPE in
		"flash" | "modules" | "imx-boot" | "cve" | "spdx")
			echo "[ADV] creating ${OUTPUT_DIR}.tgz ..."
			tar czf ${OUTPUT_DIR}.tgz ${OUTPUT_DIR}
			generate_md5 ${OUTPUT_DIR}.tgz
			;;
		"bsp")			
			tar czf ${OUTPUT_DIR}.tgz --exclude-vcs --exclude .repo ${ROOT_DIR}
			generate_md5 ${OUTPUT_DIR}.tgz
			;;
		*) # Normal images
			echo "[ADV] creating ${OUTPUT_DIR}.img.tgz ..."
			tar czf ${OUTPUT_DIR}.img.tgz ${OUTPUT_DIR}/${FILE_NAME}
			generate_md5 ${OUTPUT_DIR}.img.tgz
			;;
	esac

	sudo rm -rf ${OUTPUT_DIR}
}

function copy_image_to_storage()
{
	echo "[ADV] copy $1 images to $STORAGE_PATH"

	case $1 in
		"bsp")
			mv -f ${BSP_DIR}.tgz $STORAGE_PATH/bsp
		;;
		"flash")
			mv -f ${FLASH_DIR}.tgz $STORAGE_PATH/image
		;;
		"imx-boot")
			mv -f ${IMX_BOOT_DIR}.tgz $STORAGE_PATH/others
		;;
		"modules")
			mv -f ${MODULES_DIR}.tgz $STORAGE_PATH/others
		;;
		"normal")
			generate_csv ${IMAGE_DIR}.img.tgz
			mv ${IMAGE_DIR}.img.csv $STORAGE_PATH
			mv -f ${IMAGE_DIR}.img.tgz $STORAGE_PATH/image
		;;
		"cve")
			mv -f ${CVE_DIR}.tgz $STORAGE_PATH/others
		;;
		"spdx")
			mv -f ${SPDX_DIR}.tgz $STORAGE_PATH/others
		;;
		*)
		echo "[ADV] copy_image_to_storage: invalid parameter #1!"
		exit 1;
		;;
	esac

	mv -f *.md5 $STORAGE_PATH
}

# ================
#  Main procedure
# ================

mkdir $ROOT_DIR

# Make storage folder
if [ -e $STORAGE_PATH ] ; then
	echo "[ADV] $STORAGE_PATH had already been created"
else
	echo "[ADV] mkdir $STORAGE_PATH"
	mkdir -p $STORAGE_PATH
	mkdir -p $STORAGE_PATH/bsp
	mkdir -p $STORAGE_PATH/image
	mkdir -p $STORAGE_PATH/others
fi

get_source_code

echo "[ADV] tar $BSP_DIR.tgz file"
prepare_images bsp $BSP_DIR
copy_image_to_storage bsp

if [ -e $CURR_PATH/downloads ]; then
	echo "[ADV] link downloads directory from backup"
	ln -s $CURR_PATH/downloads $CURR_PATH/$ROOT_DIR/downloads
fi

for MEMORY in $MEMORY_LIST; do
	update_oeminfo

	if [ "$PRE_MEMORY" != "" ]; then
		PRE_MEMORY=$MEMORY
		rebuild_bootloader $PRE_MEMORY
	else
		PRE_MEMORY=$MEMORY
		echo "[ADV] build images"
		build_yocto_images
	fi

	echo "[ADV] generate normal image"
	IMAGE_DIR="${AIM_LINUX_TAG_VER}"_"${MEMORY,,}"_"${STORAGE}"_"${DATE}"
	prepare_images normal $IMAGE_DIR
	copy_image_to_storage normal

	echo "[ADV] create flash tool"
	FLASH_DIR="${AIM_LINUX_TAG_VER}"_"${MEMORY,,}"_"${STORAGE}"_"${DATE}"_flash_tool
	prepare_images flash $FLASH_DIR
	copy_image_to_storage flash

	echo "[ADV] create imx-boot files"
	IMX_BOOT_DIR="${AIM_LINUX_TAG_VER}"_"${MEMORY,,}"_"${STORAGE}"_"${DATE}"_imx-boot
	prepare_images imx-boot $IMX_BOOT_DIR
	copy_image_to_storage imx-boot
done

echo "[ADV] create cve files"
prepare_images cve $CVE_DIR
copy_image_to_storage cve

echo "[ADV] create sbom SPDX files"
prepare_images spdx $SPDX_DIR
copy_image_to_storage spdx
	
echo "[ADV] create module"
prepare_images modules $MODULES_DIR
copy_image_to_storage modules

save_temp_log

echo "[ADV] build script done!"