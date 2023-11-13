#!/bin/bash

VER_PREFIX="imx8"

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
echo "[ADV] MACHINE_LIST= ${MACHINE_LIST}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"

VER_TAG="${VER_PREFIX}ABV"$(echo $RELEASE_VERSION | sed 's/[.]//')
echo "[ADV] VER_TAG = $VER_TAG"

CURR_PATH="$PWD"
ROOT_DIR="${VER_PREFIX}ABV${RELEASE_VERSION}"_"$DATE"
OUTPUT_DIR="$CURR_PATH/$STORED/$DATE/V"$(echo $RELEASE_VERSION | sed 's/[.]//')

#-- Advantech github android source code repository
echo "[ADV-ROOT]  $ROOT_DIR"
ANDROID_KERNEL_PATH=$CURR_PATH/$ROOT_DIR/android/vendor/nxp-opensource/kernel_imx
ANDROID_UBOOT_PATH=$CURR_PATH/$ROOT_DIR/android/vendor/nxp-opensource/uboot-imx
ANDROID_BSP_PATH=$CURR_PATH/$ROOT_DIR/android
ANDROID_CTS_PATH=$CURR_PATH/$ROOT_DIR/android/cts
ANDROID_DEVELOPMENT_PATH=$CURR_PATH/$ROOT_DIR/android/development
ANDROID_DEVICE_PATH=$CURR_PATH/$ROOT_DIR/android/device
ANDROID_EXTERNAL_PATH=$CURR_PATH/$ROOT_DIR/android/external
ANDROID_FRAMEWORKS_PATH=$CURR_PATH/$ROOT_DIR/android/frameworks
ANDROID_PACKAGES_PATH=$CURR_PATH/$ROOT_DIR/android/packages
ANDROID_SYSTEM_PATH=$CURR_PATH/$ROOT_DIR/android/system
ANDROID_TEST_PATH=$CURR_PATH/$ROOT_DIR/android/test
ANDROID_TOOLS_PATH=$CURR_PATH/$ROOT_DIR/android/tools
ANDROID_VENDOR_PATH=$CURR_PATH/$ROOT_DIR/android/vendor

#======================
AND_BSP="android"
AND_BSP_VER="11.0.0"
AND_VERSION="android_11.0.0_2.6.0"

#======================

# Make storage folder
if [ -e $OUTPUT_DIR ] ; then
	echo "[ADV] $OUTPUT_DIR had already been created"
else
	echo "[ADV] mkdir $OUTPUT_DIR"
	mkdir -p $OUTPUT_DIR
fi

if [ -e $OUTPUT_DIR/${MODEL_NAME}/image ] ; then
    echo "[ADV] $OUTPUT_DIR/${MODEL_NAME}/image  had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR/${MODEL_NAME}/image"
    mkdir -p $OUTPUT_DIR/${MODEL_NAME}/image
fi

if [ -e $OUTPUT_DIR/${MODEL_NAME}/others ] ; then
    echo "[ADV] $OUTPUT_DIR/${MODEL_NAME}/others  had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR/${MODEL_NAME}/others"
    mkdir -p $OUTPUT_DIR/${MODEL_NAME}/others
fi

# ===========
#  Functions
# ===========
function get_source_code()
{
	echo "[ADV] get android source code"

	curl https://storage.googleapis.com/git-repo-downloads/repo > repo
	chmod 777 repo

	mkdir $ROOT_DIR
	cd $ROOT_DIR

	if [ "$BSP_BRANCH" == "" ] ; then
	   ../repo init -u $BSP_URL
	elif [ "$BSP_XML" == "" ] ; then
	   ../repo init -u $BSP_URL -b $BSP_BRANCH
	else
	   ../repo init -u $BSP_URL -b $BSP_BRANCH -m $BSP_XML
	fi
	../repo sync -j8
    
	cd $CURR_PATH
	
	tar zxvf prebuilts-imx8-android11*.tar.gz -C $CURR_PATH/$ROOT_DIR/android
}

function check_tag_and_checkout()
{
	FILE_PATH=$1
	echo "check_tag_and_checkout FILE_PATH:${FILE_PATH}"
	if [ -d "$FILE_PATH" ];then
		cd $FILE_PATH
		RESPOSITORY_TAG=`git tag | grep $VER_TAG`
		if [ "$RESPOSITORY_TAG" != "" ]; then
			echo "[ADV] [FILE_PATH] repository has been tagged ,and check to this $VER_TAG version"
			REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
			git checkout $VER_TAG
			#git tag --delete $VER_TAG
			#git push --delete $REMOTE_SERVER refs/tags/$VER_TAG
		else
			echo "[ADV] [FILE_PATH] repository isn't tagged ,nothing to do"
		fi
		cd $CURR_PATH
	else
		echo "[ADV] Directory $FILE_PATH doesn't exist"
		exit 1
	fi
}

function check_tag_and_replace()
{
	FILE_PATH=$1
	REMOTE_URL=$2
	REMOTE_BRANCH=$3
	echo "check_tag_and_replace FILE_PATH:${FILE_PATH}"
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
	echo "[ADV] $FILE_PATH"
        cd $CURR_PATH
	if [ -d "$FILE_PATH" ];then
			cd $FILE_PATH
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


function update_revision_for_xml()
{
	FILE_PATH=$1
	PROJECT_LIST=`grep "path=" $FILE_PATH`
	XML_PATH="$PWD"

	# Delete old revision
	for PROJECT in $PROJECT_LIST
	do
		REV=`expr ${PROJECT} : 'revision="\([a-zA-Z0-9_.-]*\)"'`
		if [ "$REV" != "" ]; then
				echo "[ADV] delete revision : $REV"
				sed -i "s/ revision=\"${REV}\"//g" $FILE_PATH
		fi
	done

	# Add new revision
	for PROJECT in $PROJECT_LIST
	do
		LAYER=`expr ${PROJECT} : 'path="\([a-zA-Z0-9/-]*\)"'`
		if [ "$LAYER" != "" ]; then
				echo "[ADV] add revision for $LAYER"
				cd ../../$LAYER
				HASH_ID=`git rev-parse HEAD`
				cd $XML_PATH
				sed -i "s:path=\"${LAYER}\":path=\"${LAYER}\" revision=\"${HASH_ID}\":g" $FILE_PATH
		fi
	done
}

function create_xml_and_commit()
{
	echo "[ADV]VER_TAG=$VER_TAG"
	if [ -d "$ROOT_DIR/.repo/manifests" ];then
		echo "[ADV] Create XML file"
		cd $ROOT_DIR/.repo/manifests
		git checkout $BSP_BRANCH
                if [ ! -f "$VER_TAG.xml" ];then
                    cp default.xml $VER_TAG.xml
		    # add revision into xml
                    update_revision_for_xml $VER_TAG.xml
		    # push to github
		    REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
		    git add $VER_TAG.xml
		    git commit -m "[Official Release] ${VER_TAG}"
		    git push
		    git tag -a $VER_TAG -F $CURR_PATH/$REALEASE_NOTE
		    git push $REMOTE_SERVER $VER_TAG
		fi
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
	HASH_UBOOT=$(cd $CURR_PATH/$ROOT_DIR/android/vendor/nxp-opensource/uboot-imx && git rev-parse --short HEAD)
	HASH_KERNEL=$(cd $CURR_PATH/$ROOT_DIR/android/vendor/nxp-opensource/kernel_imx && git rev-parse --short HEAD)
	HASH_ANDROID_BSP=$(cd $CURR_PATH/$ROOT_DIR/android && git rev-parse --short HEAD)
	HASH_CTS=$(cd $CURR_PATH/$ROOT_DIR/android/cts && git rev-parse --short HEAD)
	HASH_DEVELOPMENT=$(cd $CURR_PATH/$ROOT_DIR/android/development && git rev-parse --short HEAD)
	HASH_DEVICE=$(cd $CURR_PATH/$ROOT_DIR/android/device && git rev-parse --short HEAD)
	HASH_EXTERNAL=$(cd $CURR_PATH/$ROOT_DIR/android/external && git rev-parse --short HEAD)
	HASH_FRAMEWORKS=$(cd $CURR_PATH/$ROOT_DIR/android/frameworks && git rev-parse --short HEAD)
	HASH_PACKAGES=$(cd $CURR_PATH/$ROOT_DIR/android/packages && git rev-parse --short HEAD)
	HASH_SYSTEM=$(cd $CURR_PATH/$ROOT_DIR/android/system && git rev-parse --short HEAD)
	HASH_TEST=$(cd $CURR_PATH/$ROOT_DIR/android/test && git rev-parse --short HEAD)
	HASH_TOOLS=$(cd $CURR_PATH/$ROOT_DIR/android/tools && git rev-parse --short HEAD)
	HASH_VENDOR=$(cd $CURR_PATH/$ROOT_DIR/android/vendor && git rev-parse --short HEAD)

	cd $CURR_PATH

    cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Android 11.0.0
Part Number,N/A
Author,
Date,${DATE}
Build Number,${BUILD_NUMBER}
TAG,
Tested Platform,${NEW_MACHINE}
MD5 Checksum,TGZ: ${MD5_SUM}
Image Size,${FILE_SIZE}B (${FILE_SIZE_BYTE} bytes)
Issue description, N/A
Function Addition,
Android-manifest, ${HASH_BSP}
Andorid-UBOOT, ${HASH_UBOOT}
Andorid-KERNEL, ${HASH_KERNEL}
Andorid-BSP, ${HASH_ANDROID_BSP}
Andorid-DEVELOPMENT, ${HASH_DEVELOPMENT}
Andorid-DEVICE, ${HASH_DEVICE}
Andorid-EXTERNAL, ${HASH_EXTERNAL}
Andorid-FRAMEWORKS, ${HASH_FRAMEWORKS}
Andorid-PACKAGES, ${HASH_PACKAGES}
Andorid-SYSTEM, ${HASH_SYSTEM}
Andorid-TEST, ${HASH_TEST}
Andorid-TOOLS, ${HASH_TOOLS}
Andorid-VENDOR, ${HASH_VENDOR}
END_OF_CSV
}

function save_temp_log()
{
	LOG_PATH="$CURR_PATH/$ROOT_DIR"
	cd $LOG_PATH

	LOG_DIR="AIV${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"_log
	echo "[ADV] mkdir $LOG_DIR"
	mkdir $LOG_DIR

	# Backup conf, run script & log file
	cp -a *.log $LOG_DIR

	echo "[ADV] creating ${LOG_DIR}.tgz ..."
	tar czf $LOG_DIR.tgz $LOG_DIR
	generate_md5 $LOG_DIR.tgz

    mv -f $LOG_DIR.tgz $OUTPUT_DIR/${MODEL_NAME}/others
    mv -f $LOG_DIR.tgz.md5 $OUTPUT_DIR/${MODEL_NAME}/others

	# Remove all temp logs
	rm -rf $LOG_DIR
}

function building()
{
	echo "[ADV] building $1 ..."
	LOG_FILE="$NEW_MACHINE"_Build.log
	LOG2_FILE="$NEW_MACHINE"_Build2.log
	LOG3_FILE="$NEW_MACHINE"_Build3.log

	if [ "$1" == "android" ]; then
		./imx-make.sh bootloader -j12 2>> $CURR_PATH/$ROOT_DIR/$LOG_FILE
		./imx-make.sh kernel -j12 2>> $CURR_PATH/$ROOT_DIR/$LOG2_FILE
		./imx-make.sh -j12 2>> $CURR_PATH/$ROOT_DIR/$LOG3_FILE
	else
		make -j8 $1 2>> $CURR_PATH/$ROOT_DIR/$LOG_FILE
	fi
	[ "$?" -ne 0 ] && echo "[ADV] Build failure! Check log file '$LOG_FILE'" && exit 1
}

function set_environment()
{
	echo "[ADV] set environment"

	sudo git clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 $CURR_PATH/$ROOT_DIR/prebuilt-android-clang -b master-kernel-build-2021
	cd $CURR_PATH/$ROOT_DIR/android
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/
	export AARCH64_GCC_CROSS_COMPILE=/opt/gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu/bin/aarch64-linux-gnu-
	export CLANG_PATH=$CURR_PATH/$ROOT_DIR/prebuilt-android-clang
	source build/envsetup.sh

	if [ "$1" == "sdk" ]; then
		lunch sdk-userdebug
	else
		if [ "$TYPE" == "" ]; then
			lunch $NEW_MACHINE-userdebug
		else
			lunch $NEW_MACHINE-$TYPE
		fi
	fi
}

function build_android_images()
{
	cd $CURR_PATH/$ROOT_DIR/android
	set_environment
	# Android & OTA images
	building android
	#building otapackage
}

function prepare_images()
{
	cd $CURR_PATH

	IMAGE_DIR="AIV${RELEASE_VERSION}"_"$NEW_MACHINE"_"$DATE"
	echo "[ADV] mkdir $IMAGE_DIR"
	mkdir $IMAGE_DIR
	mkdir $IMAGE_DIR/image

	# Copy image files to image directory

	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/u-boot-$SOC_NAME.imx $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/u-boot-$SOC_NAME-evk-uuu.imx $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/boot.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/partition-table.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/partition-table-28GB.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/super.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/vendor.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/vendor_boot.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/imx-sdcard-partition.sh $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/fastboot_imx_flashall.sh $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/fastboot_imx_flashall.bat $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/uuu_imx_android_flash.sh $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/uuu_imx_android_flash.bat $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/dtbo-$SOC_NAME.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/vendor.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/vbmeta-$SOC_NAME.img $IMAGE_DIR/image
	cp -a $CURR_PATH/$ROOT_DIR/android/out/target/product/$NEW_MACHINE/vbmeta.img $IMAGE_DIR/image

	cp -a /usr/bin/simg2img $IMAGE_DIR/image

	echo "[ADV] creating ${IMAGE_DIR}.tgz ..."
	tar -zcvf ${IMAGE_DIR}.tar.gz $IMAGE_DIR
	generate_md5 ${IMAGE_DIR}.tar.gz
}

function copy_image_to_storage()
{
	echo "[ADV] copy images to $OUTPUT_DIR"
	generate_csv ${IMAGE_DIR}.tar.gz
	mv ${IMAGE_DIR}.csv $OUTPUT_DIR/${MODEL_NAME}/others
    mv -f ${IMAGE_DIR}.tar.gz $OUTPUT_DIR/${MODEL_NAME}/image
    mv -f ${IMAGE_DIR}.tar.gz.md5 $OUTPUT_DIR/${MODEL_NAME}/image
}

# ================
#  Main procedure 
# ================

mkdir $ROOT_DIR
get_source_code

echo "[ADV] check_tag_and_checkout"

# Check ADVANTECH android source code tag exist or not, and checkout to tag version
check_tag_and_checkout $ANDROID_KERNEL_PATH
check_tag_and_checkout $ANDROID_UBOOT_PATH
check_tag_and_checkout $ANDROID_BSP_PATH
check_tag_and_checkout $ANDROID_CTS_PATH
check_tag_and_checkout $ANDROID_DEVELOPMENT_PATH
check_tag_and_checkout $ANDROID_DEVICE_PATH
check_tag_and_checkout $ANDROID_EXTERNAL_PATH
check_tag_and_checkout $ANDROID_FRAMEWORKS_PATH
check_tag_and_checkout $ANDROID_PACKAGES_PATH
check_tag_and_checkout $ANDROID_SYSTEM_PATH
check_tag_and_checkout $ANDROID_TEST_PATH
check_tag_and_checkout $ANDROID_TOOLS_PATH
check_tag_and_checkout $ANDROID_VENDOR_PATH

# Add git tag
echo "[ADV] Add tag"
auto_add_tag $ANDROID_KERNEL_PATH
auto_add_tag $ANDROID_UBOOT_PATH
auto_add_tag $ANDROID_BSP_PATH
auto_add_tag $ANDROID_CTS_PATH
auto_add_tag $ANDROID_DEVELOPMENT_PATH
auto_add_tag $ANDROID_DEVICE_PATH
auto_add_tag $ANDROID_EXTERNAL_PATH
auto_add_tag $ANDROID_FRAMEWORKS_PATH
auto_add_tag $ANDROID_PACKAGES_PATH
auto_add_tag $ANDROID_SYSTEM_PATH
auto_add_tag $ANDROID_TEST_PATH
auto_add_tag $ANDROID_TOOLS_PATH
auto_add_tag $ANDROID_VENDOR_PATH

# ------------REMOVE FOR TEST   ------------- #
# Create manifests xml and commit
echo "[ADV] create_xml_and_commit"
create_xml_and_commit

echo "[ADV] build images"
for NEW_MACHINE in $MACHINE_LIST
do
	echo "[ADV] build android images"
	build_android_images
	echo "[ADV] prepare_image"
	prepare_images
	echo "[ADV] copy_image_to_storage"
	copy_image_to_storage
	echo "[ADV] save_temp_log"
	save_temp_log
done

cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

