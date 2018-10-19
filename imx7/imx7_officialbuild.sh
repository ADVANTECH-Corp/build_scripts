#!/bin/bash

PRODUCT=$1
OFFICIAL_VER=$2
MEMORY_TYPE=$3
BACKEND_TYPE=$4

#--- [platform specific] ---
VER_PREFIX="imx7"
TMP_DIR="tmp"
DEFAULT_DEVICE="imx7debcrm01a1"
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

VER_TAG="${VER_PREFIX}LB"$(echo $RELEASE_VERSION | sed 's/[.]//')

CURR_PATH="$PWD"
ROOT_DIR="${VER_TAG}"_"$DATE"
STORAGE_PATH="$CURR_PATH/$STORED/$DATE"

MEMORY_COUT=1
MEMORY=`echo $MEMORY_TYPE | cut -d '-' -f $MEMORY_COUT`
PRE_MEMORY=""

echo "$Release_Note" > Release_Note
REALEASE_NOTE="Release_Note"

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
                        UBOOT_CPU_TYPE="mx7dl"
                        KERNEL_CPU_TYPE="imx7dl"
                        CPU_TYPE="DualLiteSolo"
                        ;;
                *)
                        UBOOT_CPU_TYPE="mx7d"
                        KERNEL_CPU_TYPE="imx7d"
                        CPU_TYPE="Dual"
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

function check_tag_and_checkout()
{
        FILE_PATH=$1

        if [ -d "$ROOT_DIR/$FILE_PATH" ];then
                cd $ROOT_DIR/$FILE_PATH
                META_TAG=`git tag | grep $VER_TAG`
                if [ "$META_TAG" != "" ]; then
                        echo "[ADV] meta-advantech has been tagged ,and check to this $VER_TAG version"
                        REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                        git checkout $VER_TAG
                        git tag --delete $VER_TAG
                        git push --delete $REMOTE_SERVER refs/tags/$VER_TAG
                else
                        echo "[ADV] meta-advantech isn't tagged ,nothing to do"
                fi
                cd $CURR_PATH
        else
                echo "[ADV] Directory $ROOT_DIR/$FILE_PATH doesn't exist"
                exit 1
        fi
}

function check_tag_and_replace()
{
        FILE_PATH=$1
        REMOTE_URL=$2
        REMOTE_BRANCH=$3

        HASH_ID=`git ls-remote $REMOTE_URL $VER_TAG | awk '{print $1}'`
        if [ "$HASH_ID" != "" ]; then
                echo "[ADV] $REMOTE_URL has been tagged ,ID is $HASH_ID"
        else
                HASH_ID=`git ls-remote $REMOTE_URL | grep "refs/heads/$REMOTE_BRANCH$" | awk '{print $1}'`
                echo "[ADV] $REMOTE_URL isn't tagged ,get latest HASH_ID is $HASH_ID"
        fi
        sed -i "s/"\$\{AUTOREV\}"/$HASH_ID/g" $ROOT_DIR/$FILE_PATH
}

function auto_add_tag()
{
        FILE_PATH=$1
	DIR=`ls $FILE_PATH`
        if [ -d "$FILE_PATH/$DIR/git" ];then
                cd $FILE_PATH/$DIR/git
                HEAD_HASH_ID=`git rev-parse HEAD`
                TAG_HASH_ID=`git tag -v $VER_TAG | grep object | cut -d ' ' -f 2`
                if [ "$HEAD_HASH_ID" == "$TAG_HASH_ID" ]; then
                        echo "[ADV] tag exists! There is no need to add tag"
                else
                        echo "[ADV] Add tag $VER_TAG"
                        REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                        git tag -a $VER_TAG -m "[Official Release] $VER_TAG"
                        git push $REMOTE_SERVER $VER_TAG
                fi
                cd $CURR_PATH
        else
                echo "[ADV] Directory $FILE_PATH doesn't exist"
                exit 1
        fi
}

function create_branch_and_commit()
{
        FILE_PATH=$1

        if [ -d "$ROOT_DIR/$FILE_PATH" ];then
                cd $ROOT_DIR/$FILE_PATH
                echo "[ADV] create branch $VER_TAG"
                REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                git checkout -b $VER_TAG
                git add .
                git commit -m "[Official Release] $VER_TAG"
                git push $REMOTE_SERVER $VER_TAG
                cd $CURR_PATH
        else
                echo "[ADV] Directory $ROOT_DIR/$FILE_PATH doesn't exist"
                exit 1
        fi
}




function create_xml_and_commit()
{
        if [ -d "$ROOT_DIR/.repo/manifests" ];then
                echo "[ADV] Create XML file"
                cd $ROOT_DIR
                # add revision into xml
                repo manifest -o $VER_TAG.xml -r
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

    HASH_BSP=$(cd $CURR_PATH/$ROOT_DIR/.repo/manifests && git rev-parse --short HEAD)
    HASH_ADV=$(cd $CURR_PATH/$ROOT_DIR/$META_ADVANTECH_PATH && git rev-parse --short HEAD)
    HASH_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/work/${KERNEL_CPU_TYPE}${PRODUCT}-poky-linux-gnueabi/linux-imx/$KERNEL_VERSION*/git && git rev-parse --short HEAD) 
    HASH_UBOOT=$(cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/work/${KERNEL_CPU_TYPE}${PRODUCT}-poky-linux-gnueabi/u-boot-imx/$U_BOOT_VERSION*/git && git rev-parse --short HEAD) 
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

function remove_version()
{
        sed -i "/UBOOT_LOCALVERSION/d" $ROOT_DIR/$U_BOOT_PATH
        sed -i "/LOCALVERSION/d" $ROOT_DIR/$KERNEL_PATH
}

function building()
{
        echo "[ADV] building $1 $2..."
        LOG_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_"$DATE"_log

        if [ "$1" == "populate_sdk" ]; then
                if [ "$DEPLOY_IMAGE_NAME" == "fsl-image-qt5" ]; then
                        echo "[ADV] bitbake meta-toolchain-qt5"
                        bitbake meta-toolchain-qt5
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

        if [ "$1" == "sdk" ]; then
                # Link downloads directory from backup
                if [ -e $CURR_PATH/downloads ] ; then
                       echo "[ADV] link downloads directory"
                       ln -s $CURR_PATH/downloads downloads
                fi
	        # Use default device for sdk
                EULA=1 MACHINE=$DEFAULT_DEVICE source fsl-setup-release.sh -b $BUILDALL_DIR -e $BACKEND_TYPE
        else
                # Change MACHINE setting
                sed -i "s/MACHINE ??=.*/MACHINE ??= '${KERNEL_CPU_TYPE}${PRODUCT}'/g" $BUILDALL_DIR/conf/local.conf
                EULA=1 source setup-environment $BUILDALL_DIR
        fi
}
function build_yocto_sdk()
{
        set_environment sdk

	echo "[ADV] Build recovery image!"
	building initramfs-debug-image

        # Build imx7debcrm01a1 full image first
        building $DEPLOY_IMAGE_NAME

        # Generate sdk image
        building populate_sdk
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

        # Clean QMAKE configs for qt5
        if [ "$DEPLOY_IMAGE_NAME" == "fsl-image-qt5" ]; then
                echo "[ADV] build_yocto_image: qt package cleansstate!"
                building qtbase-native cleansstate
                building qtbase cleansstate
                building qtdeclarative cleansstate
                building qtxmlpatterns cleansstate
                building qtwayland cleansstate
                building qtmultimedia cleansstate
                building qt3d cleansstate
                building qtgraphicaleffects cleansstate
                building qt5nmapcarousedemo cleansstate
                building qt5everywheredemo cleansstate
                building quitbattery cleansstate
                building qtsmarthome cleansstate
                building qtsensors cleansstate
                building cinematicexperience cleansstate
                building qt5nmapper cleansstate
                building quitindicators cleansstate
                building qtlocation cleansstate
                building qtwebkit cleansstate
                building qtwebkit-examples cleansstate
        fi
        
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

function generate_mksd_linux()
{
	sudo mkdir $MOUNT_POINT/mk_inand
	chmod 755 $CURR_PATH/mksd-linux.sh
	sudo cp $CURR_PATH/mksd-linux.sh $MOUNT_POINT/mk_inand/
	sudo chown 0.0 $MOUNT_POINT/mk_inand/mksd-linux.sh
}

function insert_image_file()
{
	IMAGE_TYPE=$1
	OUTPUT_DIR=$2
	FILE_NAME=$3
	DO_RESIZE="no"

	echo "[ADV] insert file to $IMAGE_TYPE image"
	if [ "$IMAGE_TYPE" == "normal" ] || [ "$IMAGE_TYPE" == "ota" ]; then
		DO_RESIZE="yes"
	fi

	# Maybe the loop device is occuppied, unmount it first
	sudo umount $MOUNT_POINT
	sudo losetup -d $LOOP_DEV

	cd $OUTPUT_DIR

	if [ "$DO_RESIZE" == "yes" ]; then
		ORIGINAL_FILE_NAME="$FILE_NAME".original
		mv $FILE_NAME $ORIGINAL_FILE_NAME
		dd if=/dev/zero of=$FILE_NAME bs=1M count=$SDCARD_SIZE
	fi

	# Set up loop device
	sudo losetup $LOOP_DEV $FILE_NAME

	if [ "$DO_RESIZE" == "yes" ]; then
		echo "[ADV] resize $FILE_NAME"
		sudo dd if=$ORIGINAL_FILE_NAME of=$LOOP_DEV
		sudo sync
		rootfs_start=`sudo fdisk -u -l ${LOOP_DEV} | grep ${LOOP_DEV}p2 | awk '{print $2}'`
sudo fdisk -u $LOOP_DEV << EOF &>/dev/null
d
2
n
p
$rootfs_start
$PARTITION_SIZE_LIMIT
w
EOF
		sudo sync
		sudo partprobe ${LOOP_DEV}
		sudo e2fsck -f -y ${LOOP_DEV}p2
		sudo resize2fs ${LOOP_DEV}p2
	fi

	sudo mount ${LOOP_DEV}p2 $MOUNT_POINT
	sudo mkdir $MOUNT_POINT/image

	# Insert specific image file
	case $IMAGE_TYPE in
		"normal")
			sudo cp -a $ORIGINAL_FILE_NAME $MOUNT_POINT/image/$FILE_NAME
			sudo cp $DEPLOY_IMAGE_PATH/u-boot-2G*.imx $MOUNT_POINT/image/
			generate_mksd_linux
			sudo rm $ORIGINAL_FILE_NAME
			;;
		*)
                        echo "[ADV] insert_image_file: invalid parameter #1!"
                        exit 1;
                        ;;
	esac

	sudo chown -R 0.0 $MOUNT_POINT/image
	sudo umount $MOUNT_POINT
	sudo losetup -d $LOOP_DEV

	cd ..
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
                "sdk")
			cp $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/deploy/sdk/* $OUTPUT_DIR
                        ;;
                "normal")
                        FILE_NAME=u-boot-2G*.imx
                        echo "[ADV] copy normal $FILE_NAME"
                        cp $DEPLOY_IMAGE_PATH/$FILE_NAME $STORAGE_PATH
                        FILE_NAME=${DEPLOY_IMAGE_NAME}"-"${KERNEL_CPU_TYPE}${PRODUCT}"*.rootfs.sdcard"
                        cp $DEPLOY_IMAGE_PATH/$FILE_NAME $OUTPUT_DIR
			echo "[ADV] copy normal $FILE_NAME"
			cp $DEPLOY_IMAGE_PATH/$FILE_NAME $STORAGE_PATH
                        if [ -e $OUTPUT_DIR/$FILE_NAME ]; then
                                FILE_NAME=`ls $OUTPUT_DIR | grep rootfs.sdcard | grep $DEPLOY_IMAGE_NAME`

                                # Insert mksd-linux.sh for both normal
                                insert_image_file "normal" $OUTPUT_DIR $FILE_NAME
                        fi
                        ;;
		"ota")
			generate_OTA_update_package
                        ;;
                *)
                        echo "[ADV] prepare_images: invalid parameter #1!"
                        exit 1;
                        ;;
        esac

        # Package image file
        case $IMAGE_TYPE in
                "sdk")
                        echo "[ADV] creating ${OUTPUT_DIR}.tgz ..."
			tar czf ${OUTPUT_DIR}.tgz $OUTPUT_DIR
			generate_md5 ${OUTPUT_DIR}.tgz
                        ;;
                "ota")
                        echo "[ADV] ota case: Don't need to create any file ..."
                        ;;
                *) # Normal image
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
	echo "[ADV] creating ${IMAGE_DIR}_uboot_kernel.zip for OTA package ..."
	./ota-package.sh -k zImage -d ${KERNEL_CPU_TYPE}*.dtb -o update_${IMAGE_DIR}_kernel.zip
	mv update*.zip $CURR_PATH
	cd $CURR_PATH
}

function copy_image_to_storage()
{
	echo "[ADV] copy $1 images to $STORAGE_PATH"

	case $1 in
		"sdk")
			mv -f ${ROOT_DIR}.tgz $STORAGE_PATH
			mv -f ${SDK_DIR}.tgz $STORAGE_PATH
		;;
		"normal")
			generate_csv $IMAGE_DIR.img.gz
			mv ${IMAGE_DIR}.img.csv $STORAGE_PATH
			mv -f $IMAGE_DIR.img.gz $STORAGE_PATH
		;;
		"ota")
			mv -f update*.zip $STORAGE_PATH
		;;
		*)
		echo "[ADV] copy_image_to_storage: invalid parameter #1!"
		exit 1;
		;;
	esac

	mv -f *.md5 $STORAGE_PATH
}

function wrap_source_code()
{
	SOURCE_URL=$1
	SOURCE_TAG=$2
	SOURCE_DIR=$3
	git clone $SOURCE_URL
	cd $SOURCE_DIR
	git checkout $SOURCE_TAG 
	cd ..
	echo "[ADV] creating "$ROOT_DIR"_"$SOURCE_DIR".tgz ..."
	tar czf "$ROOT_DIR"_"$SOURCE_DIR".tgz $SOURCE_DIR --exclude-vcs
	generate_md5 "$ROOT_DIR"_"$SOURCE_DIR".tgz
	rm -rf $SOURCE_DIR
	mv -f "$ROOT_DIR"_"$SOURCE_DIR".tgz $STORAGE_PATH
	mv -f "$ROOT_DIR"_"$SOURCE_DIR".tgz.md5 $STORAGE_PATH
}

# ================
#  Main procedure
# ================
define_cpu_type $PRODUCT

case $BACKEND_TYPE in
    "wayland")
        DEPLOY_IMAGE_NAME="fsl-image-weston"
        ;;
    "fb")
        DEPLOY_IMAGE_NAME="fsl-image-gui"
        ;;
    *)
        # dfb & x11 are correct. Do nothing.
        ;;
esac
if [ "$PRODUCT" == "$VER_PREFIX" ]; then
	mkdir $ROOT_DIR
        get_source_code

	if [ -z "$EXISTED_VERSION" ] ; then
	        # Check meta-advantech tag exist or not, and checkout to tag version
        	check_tag_and_checkout $META_ADVANTECH_PATH

		# Check tag exist or not, and replace bbappend file SRCREV
		check_tag_and_replace $U_BOOT_PATH $U_BOOT_URL $U_BOOT_BRANCH
		check_tag_and_replace $KERNEL_PATH $KERNEL_URL $KERNEL_BRANCH
	fi
        # BSP source code
        echo "[ADV] tar $ROOT_DIR.tgz file"
	rm $ROOT_DIR/setup-environment $ROOT_DIR/fsl-setup-release.sh
	cp $ROOT_DIR/.repo/manifests/fsl-setup-release.sh $ROOT_DIR/fsl-setup-release.sh
	cp $ROOT_DIR/.repo/manifests/setup-environment $ROOT_DIR/setup-environment
	tar czf $ROOT_DIR.tgz $ROOT_DIR --exclude-vcs --exclude .repo
        generate_md5 $ROOT_DIR.tgz

        # Build Yocto SDK
        echo "[ADV] build yocto sdk"
        build_yocto_sdk

	echo "[ADV] generate sdk image"
        SDK_DIR="$ROOT_DIR"_sdk
        prepare_images sdk $SDK_DIR
	copy_image_to_storage sdk

        # Remove pre-built image & backup generic rpm packages
        rm $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/deploy/images/$DEFAULT_DEVICE/*

elif [ "$PRODUCT" == "push_commit" ]; then
        EXISTED_VERSION=`find $ROOT_DIR/.repo/manifests -name ${VER_TAG}.xml`

        if [ -z "$EXISTED_VERSION" ] ; then
                #Define for $KERNEL_CPU_TYPE
                PRODUCT=$2
                define_cpu_type $PRODUCT
                cd $CURR_PATH
                remove_version

                # Commit and create meta-advantech branch
                create_branch_and_commit $META_ADVANTECH_PATH

                # Add git tag
                echo "[ADV] Add tag"
                auto_add_tag $ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/work/${KERNEL_CPU_TYPE}${PRODUCT}-poky-linux-gnueabi/u-boot-imx
                auto_add_tag $ROOT_DIR/$BUILDALL_DIR/$TMP_DIR/work/${KERNEL_CPU_TYPE}${PRODUCT}-poky-linux-gnueabi/linux-imx

                # Create manifests xml and commit
                create_xml_and_commit

                # Package kernel & u-boot
                wrap_source_code $KERNEL_URL $VER_TAG linux-imx7
                wrap_source_code $U_BOOT_URL $VER_TAG uboot-imx7
        fi

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

        echo "[ADV] generate ota kernel image"
	OTA_IMAGE_DIR="$IMAGE_DIR"_ota
	prepare_images ota $OTA_IMAGE_DIR
	copy_image_to_storage ota

	save_temp_log
fi

# Copy downloads to backup
if [ ! -e $CURR_PATH/downloads ] ; then
    echo "[ADV] backup 'downloads' directory"
    cp -a $CURR_PATH/$ROOT_DIR/downloads $CURR_PATH
fi

cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

