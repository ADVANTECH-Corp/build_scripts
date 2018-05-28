#!/bin/bash

PRODUCT=$1
OFFICIAL_VER=$2
if [ "$1" == "push_commit" ]; then
RELEASE_VERSION=V"$3"
else
RELEASE_VERSION=${2#*I}
fi
echo RELEASE_VERSION=$RELEASE_VERSION
#--- [platform specific] ---
if [ "$1" == "rsb4220a1" ] || [ "$1" == "rsb4221a1" ] || [ "$1" == "rom3310a1" ]; then
    VER_PREFIX="am335x"
    UBOOT_CPU_TYPE="am335x"
    KERNEL_CPU_TYPE="am335x"
elif [ "$1" == "rom7510a1" ] || [ "$1" == "rom7510a2" ];then
    VER_PREFIX="am57xx"
    UBOOT_CPU_TYPE="am57xx"
    KERNEL_CPU_TYPE="am57xx"
else
    if [ "$2" == "rsb4220a1" ] || [ "$2" == "rsb4221a1" ] || [ "$2" == "rom3310a1" ]; then
        VER_PREFIX="am335x"
        UBOOT_CPU_TYPE="am335x"
        KERNEL_CPU_TYPE="am335x"
    elif [ "$2" == "rom7510a1" ] || [ "$2" == "rom7510a2" ] ;then
        VER_PREFIX="am57xx"
        UBOOT_CPU_TYPE="am57xx"
        KERNEL_CPU_TYPE="am57xx"
    fi
fi
TMP_DIR="arago-tmp-external-linaro-toolchain"
DEFAULT_MACHINE="am57xxrom7510a2"
#---------------------------
echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] DEPLOY_IMAGE_NAME = ${DEPLOY_IMAGE_NAME}"
echo "[ADV] OTA_IMAGE_NAME = ${OTA_IMAGE_NAME}"
echo "[ADV] BACKEND_TYPE = ${BACKEND_TYPE}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"

echo "[ADV] U_BOOT_VERSION = ${U_BOOT_VERSION}"
echo "[ADV] U_BOOT_URL = ${U_BOOT_URL}"
echo "[ADV] U_BOOT_BRANCH = ${U_BOOT_BRANCH}"
echo "[ADV] U_BOOT_PATH = ${U_BOOT_PATH}"
echo "[ADV] META_ADVANTECH_PATH = ${META_ADVANTECH_PATH}"
echo "[ADV] KERNEL_VERSION = ${KERNEL_VERSION}"
echo "[ADV] KERNEL_URL = ${KERNEL_URL}"
echo "[ADV] KERNEL_BRANCH = ${KERNEL_BRANCH}"
echo "[ADV] KERNEL_PATH = ${KERNEL_PATH}"

VER_TAG="${VER_PREFIX}LB"$(echo $RELEASE_VERSION | sed 's/[.]//')
echo "[ADV] VER_TAG=$VER_TAG"

CURR_PATH="$PWD"
ROOT_DIR="${VER_TAG}"_"$DATE"
STORAGE_PATH="$CURR_PATH/$STORED/$DATE"

echo "$Release_Note" > Release_Note
REALEASE_NOTE="Release_Note"

# Make storage folder
if [ -e $STORAGE_PATH ] ; then
	echo "[ADV] $STORAGE_PATH had already been created"
else
	echo "[ADV] mkdir $STORAGE_PATH"
	mkdir -p $STORAGE_PATH
fi

# ===========
#  Functions
# ===========

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
                HASH_ID=`git ls-remote $REMOTE_URL | grep refs/heads/$REMOTE_BRANCH | awk '{print $1}'`
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
    HASH_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$BUILD_TMP_DIR/work-shared/${NEW_MACHINE}/kernel-source && git rev-parse --short HEAD) 
    HASH_UBOOT=$(cd $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$BUILD_TMP_DIR/work/${NEW_MACHINE}-linux-gnueabi/u-boot-ti-staging/$U_BOOT_VERSION*/git && git rev-parse --short HEAD) 
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
adv-ti-yocto-bsp, ${HASH_BSP}
meta-advantech, ${HASH_ADV}
linux-ti, ${HASH_KERNEL}
uboot-ti, ${HASH_UBOOT}
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
    if [ "x$NEW_MACHINE" != "x" ]; then
        MACHINE_OPT=$NEW_MACHINE
        echo "[ADV] building $NEW_MACHINE $1 $2..."
        LOG_DIR="LI${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"_log
    else
        MACHINE_OPT=$DEFAULT_MACHINE
        echo "[ADV] building $DEFAULT_MACHINE $1 $2..."
        LOG_DIR="LI${RELEASE_VERSION}"_"$DEFAULT_MACHINE"_"$DATE"_log
    fi

    if [ "x" != "x$2" ]; then
        MACHINE=$MACHINE_OPT bitbake $1 -c $2 -f

    else
        MACHINE=$MACHINE_OPT bitbake $1
    fi

    if [ "$?" -ne 0 ]; then
        echo "[ADV] Build failure! Check details in ${LOG_DIR}.tgz"
        save_temp_log
        exit 1
    fi
    # Remove build folder
#    [ "$?" -ne 0 ] && echo "[ADV] Build failure! Check details in ${LOG_DIR}.tgz" && save_temp_log && rm -rf $CURR_PATH/$ROOT_DIR && exit 1
}

function set_environment()
{
        cd $CURR_PATH/$ROOT_DIR
	echo "[ADV] set environment"

        ./oe-layertool-setup.sh
        cd build
        source conf/setenv
}
function build_yocto_sdk()
{
        set_environment sdk

        # Build am335xrsb4220 full image first
	echo DEPLOY_IMAGE_NAME=$DEPLOY_IMAGE_NAME
        building $DEPLOY_IMAGE_NAME

}
function build_yocto_images()
{
        set_environment

        # Re-build U-Boot & kernel
        echo "[ADV] build_yocto_image: build u-boot"
        building u-boot-ti-staging cleansstate
        building u-boot-ti-staging

        echo "[ADV] build_yocto_image: build kernel"
        building linux-processor-sdk cleansstate
        building linux-processor-sdk

	echo "[ADV] Build recovery image!"
	building initramfs-debug-image
        
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
                "sdk")
			cp $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$BUILD_TMP_DIR/deploy/sdk/* $OUTPUT_DIR
                        ;;
                "modules")
                        echo "[ADV]  Copy modules"
                        FILE_NAME="modules-*${KERNEL_CPU_TYPE}${PRODUCT}.tgz"
                        cp $DEPLOY_MODULES_PATH/$FILE_NAME $OUTPUT_DIR
                        echo "[ADV]  Copy modules finish"
                        ;;
                "firmware")
                        mkdir $OUTPUT_DIR/firmware_all
                        mkdir $OUTPUT_DIR/firmware_product
                        echo "[ADV]  Copy firmware"
                        FILE_NAME="*.ipk"
                        cp -rf $DEPLOY_FIRMWARE_PATH/$FILE_NAME $OUTPUT_DIR/firmware_all
                        cp -rf $DEPLOY_FIRMWARE_PATH $OUTPUT_DIR/firmware_all
                        echo "[ADV]  Copy firmware finish"
                        cp -rf "$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$BUILD_TMP_DIR/deploy/ipk/${KERNEL_CPU_TYPE}${PRODUCT}" $OUTPUT_DIR/firmware_product
                        ;;
                "normal")
                        FILE_NAME=${SDK_IMAGE_NAME}"-"${KERNEL_CPU_TYPE}${PRODUCT}"*.tar.xz"
                        cp $DEPLOY_IMAGE_PATH/$FILE_NAME $OUTPUT_DIR
			cp $DEPLOY_IMAGE_PATH/$FILE_NAME $STORAGE_PATH
                        ;;
                *)
                        echo "[ADV] prepare_images: invalid parameter #1!"
                        exit 1;
                        ;;
        esac

        # Package image file
        case $IMAGE_TYPE in
                "sdk" | "modules" | "firmware"| "normal" )
                        echo "[ADV] creating ${OUTPUT_DIR}.tgz ..."
			tar czf ${OUTPUT_DIR}.tgz $OUTPUT_DIR
			generate_md5 ${OUTPUT_DIR}.tgz
                        ;;
        esac
        rm -rf $OUTPUT_DIR
}

function copy_image_to_storage()
{
	echo "[ADV] copy $1 images to $STORAGE_PATH"

	case $1 in
		"sdk")
			mv -f ${ROOT_DIR}.tgz $STORAGE_PATH
			mv -f ${SDK_DIR}.tgz $STORAGE_PATH
		;;
		"modules")
			mv -f ${MODULES_DIR}.tgz $STORAGE_PATH
		;;
		"firmware")
			mv -f ${FIRMWARE_DIR}.tgz $STORAGE_PATH
		;;
		"normal")
			generate_csv $IMAGE_DIR.img.gz
			mv ${IMAGE_DIR}.img.csv $STORAGE_PATH
			mv -f $IMAGE_DIR.img.gz $STORAGE_PATH
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

	mkdir $ROOT_DIR
        echo "[ADV] ls ./"
	ls ./
	echo "[ADV] ls ../"
	ls ../
	echo "[ADV] ls ../../"
	ls ../../
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
	rm -r $ROOT_DIR/configs $ROOT_DIR/oe-layertool-setup.sh $ROOT_DIR/sample-files
	cp -r $ROOT_DIR/.repo/manifests/configs $ROOT_DIR/configs
	cp -r $ROOT_DIR/.repo/manifests/sample-files $ROOT_DIR/sample-files
	cp $ROOT_DIR/.repo/manifests/oe-layertool-setup.sh $ROOT_DIR/oe-layertool-setup.sh
	tar czf $ROOT_DIR.tgz $ROOT_DIR --exclude-vcs --exclude .repo
        generate_md5 $ROOT_DIR.tgz

        # Package kernel & u-boot
	echo KERNEL_URL=$KERNEL_URL
	echo KERNEL_BRANCH=$KERNEL_BRANCH
	echo U_BOOT_URL=$U_BOOT_URL
	echo U_BOOT_BRANCH=$U_BOOT_BRANCH
        wrap_source_code $KERNEL_URL $KERNEL_BRANCH linux-ti
        wrap_source_code $U_BOOT_URL $U_BOOT_BRANCH uboot-ti

        NEW_MACHINE=${VER_PREFIX}"$1"          
        echo "[ADV] add version"
        add_version

	# Link downloads directory from backup
	cd $CURR_PATH
	if [ -e $CURR_PATH/downloads ] ; then
   		 echo "[ADV] link downloads directory"
   		 ln -s $CURR_PATH/downloads downloads
	fi
		
	echo "[ADV] build images"
        build_yocto_images

        echo "[ADV] generate normal image"
	DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$BUILD_TMP_DIR/deploy/images/${KERNEL_CPU_TYPE}${PRODUCT}"

        IMAGE_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_"$DATE"
        prepare_images normal $IMAGE_DIR
        copy_image_to_storage normal

        echo "[ADV] create module"
        DEPLOY_MODULES_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$BUILD_TMP_DIR/deploy/images/${KERNEL_CPU_TYPE}${PRODUCT}"
        MODULES_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_modules
        prepare_images modules $MODULES_DIR
        copy_image_to_storage modules

        echo "[ADV] create firmware"
        DEPLOY_FIRMWARE_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/$BUILD_TMP_DIR/deploy/ipk/all"
        FIRMWARE_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_firmware
        prepare_images firmware $FIRMWARE_DIR
        copy_image_to_storage firmware

	save_temp_log

	EXISTED_VERSION=`find $ROOT_DIR/.repo/manifests -name ${VER_TAG}.xml`

        if [ -z "$EXISTED_VERSION" ] ; then
                #Define for $KERNEL_CPU_TYPE
                cd $CURR_PATH

                # Commit and create meta-advantech branch
                create_branch_and_commit $META_ADVANTECH_PATH

                # Add git tag
                echo "[ADV] Add tag"
                auto_add_tag $ROOT_DIR/$BUILDALL_DIR/$BUILD_TMP_DIR/work/${KERNEL_CPU_TYPE}${PRODUCT}-linux-gnueabi/u-boot-ti-staging
                auto_add_tag $ROOT_DIR/$BUILDALL_DIR/$BUILD_TMP_DIR/work/${KERNEL_CPU_TYPE}${PRODUCT}-linux-gnueabi/linux-processor-sdk

                # Create manifests xml and commit
                create_xml_and_commit
        fi

# Copy downloads to backup
if [ ! -e $CURR_PATH/downloads ] ; then
    echo "[ADV] backup 'downloads' directory"
    cp -a $CURR_PATH/$ROOT_DIR/downloads $CURR_PATH
fi

cd $CURR_PATH
echo "[ADV] remove $ROOT_DIR"
rm -rf $ROOT_DIR

echo "[ADV] build script done!"

