#!/bin/bash

PRODUCT=$1
OFFICIAL_VER=$2
MEMORY_LIST=$3
BOOT_DEVICE_LIST=$4

#--- [platform specific] ---
VER_PREFIX="imx9"
TMP_DIR="tmp"
#---------------------------
echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] DEPLOY_IMAGE_NAME = ${DEPLOY_IMAGE_NAME}"
echo "[ADV] BACKEND_TYPE = ${BACKEND_TYPE}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"
echo "[ADV] MEMORY_LIST=${MEMORY_LIST}"
echo "[ADV] BOOT_DEVICE_LIST=${BOOT_DEVICE_LIST}"
echo "[ADV] U_BOOT_VERSION = ${U_BOOT_VERSION}"
echo "[ADV] U_BOOT_URL = ${U_BOOT_URL}"
echo "[ADV] U_BOOT_BRANCH = ${U_BOOT_BRANCH}"
echo "[ADV] U_BOOT_PATH = ${U_BOOT_PATH}"
echo "[ADV] META_ADVANTECH_PATH = ${META_ADVANTECH_PATH}"
echo "[ADV] KERNEL_VERSION = ${KERNEL_VERSION}"
echo "[ADV] KERNEL_URL = ${KERNEL_URL}"
echo "[ADV] KERNEL_BRANCH = ${KERNEL_BRANCH}"
echo "[ADV] KERNEL_PATH = ${KERNEL_PATH}"

VER_TAG="${VER_PREFIX}LBV${RELEASE_VERSION}"

CURR_PATH="$PWD"
ROOT_DIR="${VER_TAG}"_"$DATE"
STORAGE_PATH="$CURR_PATH/$STORED/$DATE"

PRE_MEMORY=""

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

# Make mnt folder
MOUNT_POINT="$CURR_PATH/mnt"
if [ -e $MOUNT_POINT ]; then
	echo "[ADV] $MOUNT_POINT had already been created"
else
	echo "[ADV] mkdir $MOUNT_POINT"
	mkdir $MOUNT_POINT
fi


# ===========
#  Functions
# ===========
function define_cpu_type()
{
        CPU_TYPE=`expr $1 : '.*-\(.*\)$'`
        case $CPU_TYPE in
                "93")
			PRODUCT=`expr $1 : '\(.*\).*-'`
			KERNEL_CPU_TYPE="imx93"
			CPU_TYPE="iMX93"
			;;
                *)
                        # Do nothing
                        ;;
        esac
}

function do_repo_init()
{
    REPO_OPT="-u $BSP_URL"

    if [ ! -z "$BSP_BRANCH" ] ; then
        REPO_OPT="$REPO_OPT -b $BSP_BRANCH"
    fi
    if [ ! -z "$BSP_XML" ] ; then
        REPO_OPT="$REPO_OPT -m $BSP_XML"
    fi

    repo init $REPO_OPT
}

function get_source_code()
{
    echo "[ADV] get yocto source code"
    cd $ROOT_DIR

    do_repo_init

    EXISTED_VERSION=`find .repo/manifests -name ${VER_TAG}.xml`
    if [ -z "$EXISTED_VERSION" ] ; then
        echo "[ADV] This is a new VERSION"
    else
        echo "[ADV] $RELEASE_VERSION already exists!"
        rm -rf .repo
        BSP_BRANCH="refs/tags/$VER_TAG"
        BSP_XML="$VER_TAG.xml"
        do_repo_init
    fi

    repo sync

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

function save_temp_log()
{
	LOG_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR"
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
	rm -rf $LOG_DIR
	find . -name "temp" | xargs rm -rf
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

    HASH_BSP=$(cd $CURR_PATH/$ROOT_DIR/.repo/manifests && git rev-parse HEAD)
    HASH_ADV=$(cd $CURR_PATH/$ROOT_DIR/$META_ADVANTECH_PATH && git rev-parse HEAD)
    HASH_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/work/${KERNEL_CPU_TYPE}${PRODUCT}-poky-linux/linux-imx/$KERNEL_VERSION*/git && git rev-parse HEAD)
    HASH_UBOOT=$(cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/work/${KERNEL_CPU_TYPE}${PRODUCT}-poky-linux/u-boot-imx/*$U_BOOT_VERSION*/git && git rev-parse HEAD)
    cd $CURR_PATH

    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Linux ${KERNEL_VERSION}
Part Number,N/A
Author,
Date,${DATE}
Version,${OFFICIAL_VER}
Build Number,${BUILD_NUMBER}
TAG,
Tested Platform,${KERNEL_CPU_TYPE}${PRODUCT}
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

function add_version()
{
	# Set U-boot version
	sed -i "/UBOOT_LOCALVERSION/d" $ROOT_DIR/$U_BOOT_PATH
	echo "UBOOT_LOCALVERSION = \"-$(echo "$OFFICIAL_VER" | tr '[:upper:]' '[:lower:]')\"" >> $ROOT_DIR/$U_BOOT_PATH

	# Set Linux version (replace)
	sed -i "0,/LOCALVERSION/ s/LOCALVERSION = .*/LOCALVERSION = \"-$(echo "$OFFICIAL_VER" | tr '[:upper:]' '[:lower:]')\"/g" $ROOT_DIR/$KERNEL_PATH
}

function building()
{
        echo "[ADV] building $1 $2..."
        LOG_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_"$DATE"_log

        if [ "$1" == "populate_sdk" ]; then
                if [ "$DEPLOY_IMAGE_NAME" == "fsl-image-full" ]; then
                        echo "[ADV] bitbake meta-toolchain"
                        bitbake meta-toolchain
                else
                        echo "[ADV] bitbake $DEPLOY_IMAGE_NAME -c populate_sdk"
                        bitbake $DEPLOY_IMAGE_NAME -c populate_sdk
                fi
        elif [ "x" != "x$2" ]; then
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

	if [ -e $BUILDALL_DIR/conf/local.conf ] ; then
		# Change MACHINE setting
		sed -i "s/MACHINE ??=.*/MACHINE ??= '${KERNEL_CPU_TYPE}${PRODUCT}'/g" $BUILDALL_DIR/conf/local.conf
		EULA=1 source setup-environment $BUILDALL_DIR
	else
		# First build
		EULA=1 DISTRO=$BACKEND_TYPE MACHINE=${KERNEL_CPU_TYPE}${PRODUCT} UBOOT_CONFIG=${PRE_MEMORY} source imx-setup-release.sh -b $BUILDALL_DIR
	fi
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
        case $BOOTLOADER_TYPE in
                "512M" | "1G" | "2G" | "4G" | "6G")
			echo "[ADV] Rebuild image for $BOOTLOADER_TYPE"
			echo "UBOOT_CONFIG = \"$BOOTLOADER_TYPE\"" >> $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/conf/local.conf
			building imx-atf cleansstate
			building optee-os cleansstate
			#building imx-boot clean
			building $DEPLOY_IMAGE_NAME clean
			building $DEPLOY_IMAGE_NAME 
			;;
                *)
			echo "[ADV] Rebuild bootloader for "$BOOTLOADER_TYPE"_"$MEMORY""
			echo "UBOOT_CONFIG = \""$BOOTLOADER_TYPE"_"$MEMORY"\"" >> $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/conf/local.conf 
			building imx-boot
                        ;;
	esac
	sed -i "/UBOOT_CONFIG/d" $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/conf/local.conf
        cd  $CURR_PATH
}


function build_yocto_images()
{
        set_environment

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

function prepare_images()
{
        cd $CURR_PATH

        IMAGE_TYPE=$1
        OUTPUT_DIR=$2
	echo "[ADV] prepare $IMAGE_TYPE image"
        if [ "$OUTPUT_DIR" == "" ]; then
                echo "[ADV] prepare_images: invalid parameter #2!"
                exit 1;
        else
                echo "[ADV] mkdir $OUTPUT_DIR"
                mkdir $OUTPUT_DIR
        fi
	
        case $IMAGE_TYPE in
                "misc")
                        cp $DEPLOY_MISC_PATH/${KERNEL_CPU_TYPE}*.dtb $OUTPUT_DIR
                        cp $DEPLOY_MISC_PATH/Image $OUTPUT_DIR
                        cp $DEPLOY_MISC_PATH/imx-boot-imx9* $OUTPUT_DIR
                        cp $DEPLOY_MISC_PATH/tee.bin $OUTPUT_DIR
                        cp -a $DEPLOY_MISC_PATH/imx-boot-tools $OUTPUT_DIR
                        ;;
                "imx-boot")
                        cp -a $DEPLOY_IMX_BOOT_PATH/* $OUTPUT_DIR
                        chmod 755 $CURR_PATH/cp_uboot.sh
                        chmod 755 $CURR_PATH/mk_imx-boot.sh
                        sudo cp $CURR_PATH/cp_uboot.sh $OUTPUT_DIR
                        sudo cp $CURR_PATH/mk_imx-boot.sh $OUTPUT_DIR
                        ;;
                "modules")
                        FILE_NAME="modules-imx9*.tgz"
                        cp $DEPLOY_MODULES_PATH/$FILE_NAME $OUTPUT_DIR
                        ;;
                "normal")
                        FILE_NAME=${DEPLOY_IMAGE_NAME}"-"${KERNEL_CPU_TYPE}${PRODUCT}"*.rootfs.wic"
                        unzstd -f $DEPLOY_IMAGE_PATH/$FILE_NAME.zst
                        cp $DEPLOY_IMAGE_PATH/$FILE_NAME $OUTPUT_DIR
                        ;;
                "individually")
                        mkdir $OUTPUT_DIR/image $OUTPUT_DIR/mk_inand
                        sudo cp $CURR_PATH/individually-script-tool/* $OUTPUT_DIR/mk_inand/
                        sudo chmod 755 $OUTPUT_DIR/mk_inand/*
                        FILE_NAME=${DEPLOY_IMAGE_NAME}"-"${KERNEL_CPU_TYPE}${PRODUCT}"*.rootfs.tar.bz2"
                        cp $DEPLOY_IMAGE_PATH/$FILE_NAME 					$OUTPUT_DIR/image/rootfs.tar.bz2
                        cp $DEPLOY_IMAGE_PATH/${KERNEL_CPU_TYPE}*dtb				$OUTPUT_DIR/image
                        cp $DEPLOY_IMAGE_PATH/Image						$OUTPUT_DIR/image
                        cp $DEPLOY_IMAGE_PATH/imx-boot-"${KERNEL_CPU_TYPE}${PRODUCT}"-"$MEMORY".bin*	$OUTPUT_DIR/image/flash.bin
                        cp $DEPLOY_IMAGE_PATH/"${KERNEL_CPU_TYPE}"*bin				$OUTPUT_DIR/image
                        ;;
                "flash")
                        mkdir $OUTPUT_DIR/image $OUTPUT_DIR/mk_inand
                        # normal image
                        FILE_NAME=${DEPLOY_IMAGE_NAME}"-"${KERNEL_CPU_TYPE}${PRODUCT}"*.rootfs.wic"
                        cp $DEPLOY_IMAGE_PATH/$FILE_NAME $OUTPUT_DIR/image
                        chmod 755 $CURR_PATH/mksd-linux.sh
                        sudo cp $CURR_PATH/mksd-linux.sh $OUTPUT_DIR/mk_inand/
			rm $DEPLOY_IMAGE_PATH/$FILE_NAME && sync
                        ;;
                *)
                        echo "[ADV] prepare_images: invalid parameter #1!"
                        exit 1;
                        ;;
        esac

        # Package image file
        case $IMAGE_TYPE in
                "flash" | "modules" | "misc" | "imx-boot" | "individually")
                        echo "[ADV] creating ${OUTPUT_DIR}.tgz ..."
                        tar czf ${OUTPUT_DIR}.tgz $OUTPUT_DIR
                        generate_md5 ${OUTPUT_DIR}.tgz
                        ;;
                *) # Normal images
                        echo "[ADV] creating ${OUTPUT_DIR}.img.gz ..."
                        gzip -c9 $OUTPUT_DIR/$FILE_NAME > $OUTPUT_DIR.img.gz
                        generate_md5 $OUTPUT_DIR.img.gz
                        ;;
        esac
        rm -rf $OUTPUT_DIR
}

function copy_image_to_storage()
{
	echo "[ADV] copy $1 images to $STORAGE_PATH"

	case $1 in
		"bsp")
			mv -f ${ROOT_DIR}.tgz $STORAGE_PATH/bsp
		;;
		"flash")
			mv -f ${FLASH_DIR}.tgz $STORAGE_PATH/image
		;;
		"individually")
			mv -f ${INDIVIDUAL_DIR}.tgz $STORAGE_PATH/image
		;;
		"misc")
			mv -f ${MISC_DIR}.tgz $STORAGE_PATH/others
		;;
                "imx-boot")
                        mv -f ${IMX_BOOT_DIR}.tgz $STORAGE_PATH/others
                ;;
		"modules")
			mv -f ${MODULES_DIR}.tgz $STORAGE_PATH/others
		;;
		"normal")
			generate_csv $IMAGE_DIR.img.gz
			mv ${IMAGE_DIR}.img.csv $STORAGE_PATH
			mv -f $IMAGE_DIR.img.gz $STORAGE_PATH/image
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
define_cpu_type $PRODUCT

if [ "$PRODUCT" == "$VER_PREFIX" ]; then
        mkdir $ROOT_DIR
        get_source_code

        # BSP source code
        echo "[ADV] tar $ROOT_DIR.tgz file"
        tar czf $ROOT_DIR.tgz $ROOT_DIR --exclude-vcs --exclude .repo
        generate_md5 $ROOT_DIR.tgz

        copy_image_to_storage bsp

else #"$PRODUCT" != "$VER_PREFIX"
        if [ ! -e $ROOT_DIR ]; then
                echo -e "No BSP is found!\nStop building." && exit 1
        fi

        if [ -e $CURR_PATH/downloads ] ; then
                echo "[ADV] link downloads directory from backup"
                ln -s $CURR_PATH/downloads $CURR_PATH/$ROOT_DIR/downloads
        fi

        echo "[ADV] add version"
        add_version

	for MEMORY in $MEMORY_LIST;do
                if [ "$PRE_MEMORY" != "" ]; then
                        PRE_MEMORY=$MEMORY
                        rebuild_bootloader $PRE_MEMORY
                else
                        PRE_MEMORY=$MEMORY
                        echo "[ADV] build images"
                        build_yocto_images
                fi

		echo "[ADV] generate normal image"
		DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/deploy/images/${KERNEL_CPU_TYPE}${PRODUCT}"
		IMAGE_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_"$MEMORY"_"$DATE"
		prepare_images normal $IMAGE_DIR
		copy_image_to_storage normal

		echo "[ADV] create flash tool"
		FLASH_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_"$MEMORY"_flash_tool
		prepare_images flash $FLASH_DIR
		copy_image_to_storage flash

		echo "[ADV] create individually script tool "
		INDIVIDUAL_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_"$MEMORY"_individually_script_tool
		prepare_images individually $INDIVIDUAL_DIR
		copy_image_to_storage individually

		echo "[ADV] create imx-boot files"
		DEPLOY_IMX_BOOT_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/work/${KERNEL_CPU_TYPE}${PRODUCT}-poky-linux/imx-boot/*/git"
		IMX_BOOT_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_"$MEMORY"_imx-boot
		prepare_images imx-boot $IMX_BOOT_DIR
		copy_image_to_storage imx-boot

		for BOOT_DEVICE in $BOOT_DEVICE_LIST; do
                        rebuild_bootloader $BOOT_DEVICE
		done

		echo "[ADV] create misc files"
		DEPLOY_MISC_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/deploy/images/${KERNEL_CPU_TYPE}${PRODUCT}"
		MISC_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_"$MEMORY"_misc
		prepare_images misc $MISC_DIR
		copy_image_to_storage misc

        done

	echo "[ADV] create module"
	DEPLOY_MODULES_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/deploy/images/${KERNEL_CPU_TYPE}${PRODUCT}"
	MODULES_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_modules
	prepare_images modules $MODULES_DIR
	copy_image_to_storage modules

        save_temp_log
fi

#cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

