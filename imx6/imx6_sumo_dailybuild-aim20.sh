#!/bin/bash

PRODUCT=$1
OFFICIAL_VER=$2
MEMORY_TYPE=$3

#--- [platform specific] ---
VER_PREFIX="imx6"
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
echo "[ADV] MEMORY_TYPE=$MEMORY_TYPE"

echo "[ADV] U_BOOT_VERSION = ${U_BOOT_VERSION}"
echo "[ADV] U_BOOT_URL = ${U_BOOT_URL}"
echo "[ADV] U_BOOT_BRANCH = ${U_BOOT_BRANCH}"
echo "[ADV] U_BOOT_PATH = ${U_BOOT_PATH}"
echo "[ADV] META_ADVANTECH_PATH = ${META_ADVANTECH_PATH}"
echo "[ADV] KERNEL_VERSION = ${KERNEL_VERSION}"
echo "[ADV] KERNEL_URL = ${KERNEL_URL}"
echo "[ADV] KERNEL_BRANCH = ${KERNEL_BRANCH}"
echo "[ADV] KERNEL_PATH = ${KERNEL_PATH}"

SDCARD_SIZE=7200

VER_TAG="${VER_PREFIX}LBV${RELEASE_VERSION}"

CURR_PATH="$PWD"
ROOT_DIR="${VER_TAG}"_"$DATE"
STORAGE_PATH="$CURR_PATH/$STORED/$DATE"

MEMORY_COUT=1
MEMORY=`echo $MEMORY_TYPE | cut -d '-' -f $MEMORY_COUT`
PRE_MEMORY=""

# Make storage folder
if [ -e $STORAGE_PATH ] ; then
	echo "[ADV] $STORAGE_PATH had already been created"
else
	echo "[ADV] mkdir $STORAGE_PATH"
	mkdir -p $STORAGE_PATH
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
                "solo")
                        PRODUCT=`expr $1 : '\(.*\).*-'`
                        UBOOT_CPU_TYPE="mx6dl"
                        KERNEL_CPU_TYPE="imx6dl"
                        CPU_TYPE="DualLiteSolo"
                        ;;
                "plus")
                        PRODUCT=`expr $1 : '\(.*\).*-'`
                        UBOOT_CPU_TYPE="mx6qp"
                        KERNEL_CPU_TYPE="imx6qp"
                        CPU_TYPE="DualQuadPlus"
                        ;;
                *)
                        UBOOT_CPU_TYPE="mx6q"
                        KERNEL_CPU_TYPE="imx6q"
                        CPU_TYPE="DualQuad"
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
    HASH_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/work/${KERNEL_CPU_TYPE}${PRODUCT}-poky-linux-gnueabi/linux-imx/$KERNEL_VERSION*/git && git rev-parse HEAD) 
    HASH_UBOOT=$(cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/work/${KERNEL_CPU_TYPE}${PRODUCT}-poky-linux-gnueabi/u-boot-imx/$U_BOOT_VERSION*/git && git rev-parse HEAD) 
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
	echo "UBOOT_LOCALVERSION = \"-$OFFICIAL_VER\"" >> $ROOT_DIR/$U_BOOT_PATH
	
	# Set Linux version
	sed -i "/LOCALVERSION/d" $ROOT_DIR/$KERNEL_PATH
	echo "LOCALVERSION = \"-$OFFICIAL_VER\"" >> $ROOT_DIR/$KERNEL_PATH
}

function building()
{
        echo "[ADV] building $1 $2..."
        LOG_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_"$DATE"_log

        if [ "$1" == "populate_sdk" ]; then
                if [ "$DEPLOY_IMAGE_NAME" == "fsl-image-validation-imx" ]; then
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
		EULA=1 DISTRO=$BACKEND_TYPE MACHINE=${KERNEL_CPU_TYPE}${PRODUCT} source fsl-setup-release.sh -b $BUILDALL_DIR
	fi
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

	# Build full image
        building $DEPLOY_IMAGE_NAME
}

function rebuild_u-boot()
{
        #rebuild u-boot because of different memory
        echo "[ADV] rebuild u-boot for DDR $MEMORY"
	echo "[ADV] rebuild u-boot PRE_MEMORY $PRE_MEMORY"
	#sed -i "s/${PRE_MEMORY}/${MEMORY}/g" $ROOT_DIR/$META_ADVANTECH_PATH/meta-fsl-imx6/conf/machine/${KERNEL_CPU_TYPE}${PRODUCT}.conf
        cd  $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR
        building u-boot-imx cleansstate
        building u-boot-imx
	ln -sf ${DEPLOY_IMAGE_PATH}/u-boot-${MEMORY}-*.imx ${DEPLOY_IMAGE_PATH}/u-boot-${KERNEL_CPU_TYPE}${PRODUCT}.imx
        bitbake $DEPLOY_IMAGE_NAME -c rootfs -f
        bitbake $DEPLOY_IMAGE_NAME -c image_sdcard -f
        cd  $CURR_PATH
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
                        cp $DEPLOY_MISC_PATH/zImage-${KERNEL_CPU_TYPE}*.dtb $OUTPUT_DIR
                        cp $DEPLOY_MISC_PATH/zImage $OUTPUT_DIR
                        cp $DEPLOY_MISC_PATH/u-boot_crc.bin $OUTPUT_DIR
                        cp $DEPLOY_MISC_PATH/u-boot_crc.bin.crc $OUTPUT_DIR
                        cp $DEPLOY_MISC_PATH/u-boot.imx $OUTPUT_DIR
                        ;;
                "modules")
                        FILE_NAME="modules-imx6*.tgz"
                        cp $DEPLOY_MODULES_PATH/$FILE_NAME $OUTPUT_DIR
                        ;;
                "normal")
                        FILE_NAME=${DEPLOY_IMAGE_NAME}"-"${KERNEL_CPU_TYPE}${PRODUCT}"*.rootfs.sdcard"
                        bunzip2 -f $DEPLOY_IMAGE_PATH/$FILE_NAME.bz2
                        cp $DEPLOY_IMAGE_PATH/$FILE_NAME $OUTPUT_DIR
			cp $DEPLOY_IMAGE_PATH/$FILE_NAME $STORAGE_PATH
                        ;;
		"ota")
                        FILE_NAME=${OTA_IMAGE_NAME}"-"${KERNEL_CPU_TYPE}${PRODUCT}"*.rootfs.sdcard"
                        cp $DEPLOY_IMAGE_PATH/$FILE_NAME $OUTPUT_DIR
			cp $DEPLOY_IMAGE_PATH/$FILE_NAME $STORAGE_PATH
			generate_OTA_update_package
                        ;;
                "eng")
                        FILE_NAME="SPL-"${KERNEL_CPU_TYPE}${PRODUCT}"-"${MEMORY}
                        echo "[ADV] Copy eng $FILE_NAME"
                        cp $DEPLOY_IMAGE_PATH/$FILE_NAME $STORAGE_PATH
                        FILE_NAME=`readlink $DEPLOY_IMAGE_PATH/"${DEPLOY_IMAGE_NAME}-${KERNEL_CPU_TYPE}${PRODUCT}.sdcard" | cut -d '.' -f 1`"*.rootfs.eng.sdcard"
                        echo "[ADV] Copy eng $FILE_NAME"
                        cp $DEPLOY_IMAGE_PATH/$FILE_NAME $OUTPUT_DIR
                        ;;
                *)
                        echo "[ADV] prepare_images: invalid parameter #1!"
                        exit 1;
                        ;;
        esac

        # Package image file
        case $IMAGE_TYPE in
                "modules" | "misc")
                        echo "[ADV] creating ${OUTPUT_DIR}.tgz ..."
			tar czf ${OUTPUT_DIR}.tgz $OUTPUT_DIR
			generate_md5 ${OUTPUT_DIR}.tgz
                        ;;
                *) # Normal, Eng images
                        echo "[ADV] creating ${OUTPUT_DIR}.img.gz ..."
                        gzip -c9 $OUTPUT_DIR/$FILE_NAME > $OUTPUT_DIR.img.gz
                        generate_md5 $OUTPUT_DIR.img.gz
                        ;;
        esac
        rm -rf $OUTPUT_DIR
}

function generate_OTA_update_package()
{
	echo "[ADV] generate OTA update package"
	cp ota-package.sh $DEPLOY_IMAGE_PATH
	cd $DEPLOY_IMAGE_PATH
	cp zImage-${KERNEL_CPU_TYPE}*.dtb `ls zImage-${KERNEL_CPU_TYPE}*.dtb | cut -d '-' -f 2-`	
	echo "[ADV] creating ${IMAGE_DIR}_kernel.zip for OTA package ..."
	./ota-package.sh -k zImage -d ${KERNEL_CPU_TYPE}*.dtb -o update_${IMAGE_DIR}_kernel.zip
	echo "[ADV] creating ${IMAGE_DIR}_rootfs.zip for OTA package ..."
	./ota-package.sh -r $OTA_IMAGE_NAME-${KERNEL_CPU_TYPE}${PRODUCT}.ext4 -o update_${IMAGE_DIR}_rootfs.zip
	echo "[ADV] creating ${IMAGE_DIR}_kernel_rootfs.zip for OTA package ..."
	./ota-package.sh -k zImage -d ${KERNEL_CPU_TYPE}*.dtb -r $OTA_IMAGE_NAME-${KERNEL_CPU_TYPE}${PRODUCT}.ext4 -o update_${IMAGE_DIR}_kernel_rootfs.zip
	mv update*.zip $CURR_PATH
	cd $CURR_PATH	
}

function copy_image_to_storage()
{
	echo "[ADV] copy $1 images to $STORAGE_PATH"

	case $1 in
		"bsp")
			mv -f ${ROOT_DIR}.tgz $STORAGE_PATH
		;;
		"eng")
			mv -f ${ENG_IMAGE_DIR}.img.gz $STORAGE_PATH
		;;
		"misc")
			mv -f ${MISC_DIR}.tgz $STORAGE_PATH
		;;
		"modules")
			mv -f ${MODULES_DIR}.tgz $STORAGE_PATH
		;;
		"normal")
			generate_csv $IMAGE_DIR.img.gz
			mv ${IMAGE_DIR}.img.csv $STORAGE_PATH
			mv -f $IMAGE_DIR.img.gz $STORAGE_PATH
		;;
		"ota")
			generate_csv $OTA_IMAGE_DIR.img.gz
			mv ${OTA_IMAGE_DIR}.img.csv $STORAGE_PATH
			mv -f $OTA_IMAGE_DIR.img.gz $STORAGE_PATH
			mv -f update*.zip $STORAGE_PATH
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

        echo "[ADV] add version"
        add_version

	echo "[ADV] build images"
        build_yocto_images

        echo "[ADV] generate normal image"
	DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/deploy/images/${KERNEL_CPU_TYPE}${PRODUCT}"

        IMAGE_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_"$DATE"
        prepare_images normal $IMAGE_DIR
        copy_image_to_storage normal

        echo "[ADV] create misc files"
        DEPLOY_MISC_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/deploy/images/${KERNEL_CPU_TYPE}${PRODUCT}"
        MISC_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_misc
        prepare_images misc $MISC_DIR
        copy_image_to_storage misc

        echo "[ADV] create module"
        DEPLOY_MODULES_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/deploy/images/${KERNEL_CPU_TYPE}${PRODUCT}"
        MODULES_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_modules
        prepare_images modules $MODULES_DIR
        copy_image_to_storage modules

        while [ "$MEMORY" != "$PRE_MEMORY" ]
        do
                if [ "$PRE_MEMORY" != "" ]; then
			rebuild_u-boot
                fi

                #ENG image
                echo "[ADV] generate $MEMORY eng image"
                ENG_IMAGE_DIR="$IMAGE_DIR"_"$MEMORY"_eng
                prepare_images eng $ENG_IMAGE_DIR
                copy_image_to_storage eng

                PRE_MEMORY=$MEMORY
                MEMORY_COUT=$(($MEMORY_COUT+1))
                MEMORY=`echo $MEMORY_TYPE | cut -d '-' -f $MEMORY_COUT`
                if [ "$MEMORY" == "" ]; then
                        break
                fi
        done

	save_temp_log
fi

#cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

