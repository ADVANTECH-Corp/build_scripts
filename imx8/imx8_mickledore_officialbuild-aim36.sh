#!/bin/bash

PRODUCT=$1
OFFICIAL_VER=$2
MEMORY_LIST=$3
BOOT_DEVICE_LIST=$4

#--- [platform specific] ---
VER_PREFIX="imx8"
TMP_DIR="tmp"
DEFAULT_DEVICE="imx8mprsb3720a2"
#---------------------------
echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] DEPLOY_IMAGE_NAME = ${DEPLOY_IMAGE_NAME}"
echo "[ADV] BACKEND_TYPE = ${BACKEND_TYPE}"
echo "[ADV] VERSION = ${VERSION}"
echo "[ADV] BUILD_NUMBER = ${BUILD_NUMBER}"
echo "[ADV] MEMORY_LIST=${MEMORY_LIST}"
echo "[ADV] BOOT_DEVICE_LIST=${BOOT_DEVICE_LIST}"
echo "[ADV] U_BOOT_VERSION = ${U_BOOT_VERSION}"
echo "[ADV] U_BOOT_URL = ${U_BOOT_URL}"
echo "[ADV] U_BOOT_BRANCH = ${U_BOOT_BRANCH}"
echo "[ADV] U_BOOT_PATH = ${U_BOOT_PATH}"
echo "[ADV] META_ADVANTECH_PATH = ${META_ADVANTECH_PATH}"
echo "[ADV] META_ADVANTECH_BRANCH = ${META_ADVANTECH_BRANCH}"
echo "[ADV] KERNEL_VERSION = ${KERNEL_VERSION}"
echo "[ADV] KERNEL_URL = ${KERNEL_URL}"
echo "[ADV] KERNEL_BRANCH = ${KERNEL_BRANCH}"
echo "[ADV] KERNEL_PATH = ${KERNEL_PATH}"

VER_TAG="${VER_PREFIX}LB"$(echo ${VERSION} | sed 's/[.]//')

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
                "8X")
                        PRODUCT=`expr $1 : '\(.*\).*-'`
                        KERNEL_CPU_TYPE="imx8qxp"
                        CPU_TYPE="iMX8X"
                        ;;
                "8M")
                        PRODUCT=`expr $1 : '\(.*\).*-'`
                        KERNEL_CPU_TYPE="imx8mq"
                        CPU_TYPE="iMX8M"
                        ;;
                "8MM")
                        PRODUCT=`expr $1 : '\(.*\).*-'`
                        KERNEL_CPU_TYPE="imx8mm"
                        CPU_TYPE="iMX8MM"
                        ;;
                "8MP")
                        PRODUCT=`expr $1 : '\(.*\).*-'`
                        KERNEL_CPU_TYPE="imx8mp"
                        CPU_TYPE="iMX8MP"
                        ;;
                "8QM")
                        PRODUCT=`expr $1 : '\(.*\).*-'`
                        KERNEL_CPU_TYPE="imx8qm"
                        CPU_TYPE="iMX8QM"
                        ;;
                "8U")
			PRODUCT=`expr $1 : '\(.*\).*-'`
			KERNEL_CPU_TYPE="imx8ulp"
			CPU_TYPE="iMX8ULP"
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
        echo "[ADV] $VERSION already exists!"
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
	META_BRANCH=$2
	HASH_CSV=$3

        if [ -d "$ROOT_DIR/$FILE_PATH" ];then
                cd $ROOT_DIR/$FILE_PATH
                META_TAG=`git tag | grep $VER_TAG`
                if [ "$META_TAG" != "" ]; then
                        echo "[ADV] meta-advantech has been tagged ($VER_TAG). Nothing to do."
                else
			echo "[ADV] Set meta-advantech to $HASH_CSV"
			BRANCH_SUFFIX=`echo $META_BRANCH | cut -d '_' -f 2`
			BRANCH_ORI="${META_BRANCH/_$BRANCH_SUFFIX}"
			git checkout $BRANCH_ORI
			git pull
			git reset --hard $HASH_CSV
			echo "[ADV] Checkout to '$META_BRANCH' and merge from '$BRANCH_ORI'"
			git checkout $META_BRANCH
			git pull
			git merge $BRANCH_ORI --no-edit --log
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
        HASH_CSV=$3

        HASH_ID=`git ls-remote $REMOTE_URL $VER_TAG | awk '{print $1}'`
        if [ "x$HASH_ID" != "x" ]; then
                echo "[ADV] $REMOTE_URL has been tagged ,ID is $HASH_ID"
        else
		HASH_ID=$HASH_CSV
                echo "[ADV] $REMOTE_URL isn't tagged , set HASH_ID to $HASH_ID"
        fi
        sed -i "s/"\$\{AUTOREV\}"/$HASH_ID/g" $ROOT_DIR/$FILE_PATH
}

function commit_tag_and_rollback()
{
        FILE_PATH=$1

        if [ -d "$ROOT_DIR/$FILE_PATH" ];then
                cd $ROOT_DIR/$FILE_PATH
                META_TAG=`git tag | grep $VER_TAG`
                if [ "x$META_TAG" != "x" ]; then
                        echo "[ADV] meta-advantech has been tagged ($VER_TAG). Nothing to do."
                else
                        echo "[ADV] create tag $VER_TAG"
                        REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                        git add .
                        git commit -m "[Official Release] $VER_TAG"
                        git tag -a $VER_TAG -m "[Official Release] $VER_TAG"
                        git push --follow-tags
                        # Rollback
                        HEAD_HASH_ID=`git rev-parse HEAD`
                        git revert $HEAD_HASH_ID --no-edit
                        git push
                        git reset --hard $HEAD_HASH_ID
                fi
                cd $CURR_PATH
        else
                echo "[ADV] Directory $ROOT_DIR/$FILE_PATH doesn't exist"
                exit 1
        fi
}

function commit_tag_and_package()
{
        REMOTE_URL=$1
        META_BRANCH=$2
        HASH_CSV=$3

        # Get source
        git clone $REMOTE_URL
        SOURCE_DIR=${REMOTE_URL##*/}
        SOURCE_DIR=${SOURCE_DIR/.git}
        cd $SOURCE_DIR
        git checkout $META_BRANCH
        git reset --hard $HASH_CSV

        # Add tag
        HASH_ID=`git tag -v $VER_TAG | grep object | cut -d ' ' -f 2`
        if [ "x$HASH_ID" != "x" ] ; then
                echo "[ADV] tag exists! There is no need to add tag"
        else
                echo "[ADV] Add tag $VER_TAG"
                REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
                git tag -a $VER_TAG -m "[Official Release] $VER_TAG"
                git push $REMOTE_SERVER $VER_TAG
        fi

        # Package
        cd ..
        echo "[ADV] creating "$ROOT_DIR"_"$SOURCE_DIR".tgz ..."
        tar czf "$ROOT_DIR"_"$SOURCE_DIR".tgz $SOURCE_DIR --exclude-vcs
        generate_md5 "$ROOT_DIR"_"$SOURCE_DIR".tgz
        rm -rf $SOURCE_DIR
        mv -f "$ROOT_DIR"_"$SOURCE_DIR".tgz $STORAGE_PATH
        mv -f "$ROOT_DIR"_"$SOURCE_DIR".tgz.md5 $STORAGE_PATH

        cd $CURR_PATH
}

function create_xml_and_commit()
{
        if [ -d "$ROOT_DIR/.repo/manifests" ];then
                echo "[ADV] Create XML file"
                cd $ROOT_DIR
                # add revision into xml
                repo manifest -o $VER_TAG.xml -r

                # revise for new branch
                BRANCH_SUFFIX=`echo $META_ADVANTECH_BRANCH | cut -d '_' -f 2`
                BRANCH_ORI="${META_ADVANTECH_BRANCH/_$BRANCH_SUFFIX}"
                sed -i "s/$BRANCH_ORI/$META_ADVANTECH_BRANCH/g" $VER_TAG.xml

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

        if [ "$1" == "sdk" ]; then
	        # Use default device for sdk
                EULA=1 DISTRO=$BACKEND_TYPE MACHINE=$DEFAULT_DEVICE source imx-setup-release.sh -b $BUILDALL_DIR
        else
                if [ -e $BUILDALL_DIR/conf/local.conf ] ; then
                        # Change MACHINE setting
                        sed -i "s/MACHINE ??=.*/MACHINE ??= '${KERNEL_CPU_TYPE}${PRODUCT}'/g" $BUILDALL_DIR/conf/local.conf
                        EULA=1 source setup-environment $BUILDALL_DIR
                else
                        # First build
                        EULA=1 DISTRO=$BACKEND_TYPE MACHINE=${KERNEL_CPU_TYPE}${PRODUCT} source imx-setup-release.sh -b $BUILDALL_DIR
                fi
        fi
}

function build_yocto_sdk()
{
        set_environment sdk

        # Build default full image first
        ## building $DEPLOY_IMAGE_NAME

        # Generate sdk image
        building populate_sdk
}

function prepare_images()
{
        cd $CURR_PATH

        IMAGE_TYPE=$1
        OUTPUT_DIR=$2
	echo "[ADV] prepare $IMAGE_TYPE image"
        if [ "x$OUTPUT_DIR" == "x" ]; then
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
		"sdk")
			mv -f ${SDK_DIR}.tgz $STORAGE_PATH
			;;
		*)
			echo "[ADV] copy_image_to_storage: invalid parameter #1!"
			exit 1;
			;;
	esac

	mv -f *.md5 $STORAGE_PATH
}

function get_bsp_tarball()
{
	if [ -e $STORAGE_PATH/${ROOT_DIR}.tgz ] ; then
		tar zxf $STORAGE_PATH/${ROOT_DIR}.tgz
	else
		echo "[ADV] Cannot find BSP tarball"
		exit 1;
	fi
}

function get_csv_info()
{
	IMAGE_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_"$1"_"$DATE"
	CSV_FILE="$STORAGE_PATH/${IMAGE_DIR}.img.csv"

	echo "[ADV] Show HASH in ${CSV_FILE}"
	if [ -e ${CSV_FILE} ] ; then
		HASH_ADVANTECH=`cat ${CSV_FILE} | grep "meta-advantech" | cut -d ',' -f 2`
		HASH_KERNEL=`cat ${CSV_FILE} | grep "linux-imx" | cut -d ',' -f 2`
		HASH_UBOOT=`cat ${CSV_FILE} | grep "u-boot-imx" | cut -d ',' -f 2`

		echo "[ADV] HASH_ADVANTECH : ${HASH_ADVANTECH}"
		echo "[ADV] HASH_KERNEL : ${HASH_KERNEL}"
		echo "[ADV] HASH_UBOOT : ${HASH_UBOOT}"
	else
		echo "[ADV] Cannot find ${CSV_FILE}"
		exit 1;
	fi
}

# ================
#  Main procedure
# ================
define_cpu_type $PRODUCT

if [ "$PRODUCT" == "$VER_PREFIX" ]; then
	echo "[ADV] get bsp tarball"
	get_bsp_tarball

	# Build Yocto SDK
	echo "[ADV] build yocto sdk"
	build_yocto_sdk

	echo "[ADV] generate sdk image"
	SDK_DIR="$ROOT_DIR"_sdk
	prepare_images sdk $SDK_DIR
	copy_image_to_storage sdk

	rm -rf $ROOT_DIR

else # "$PRODUCT" != "$VER_PREFIX"
	mkdir $ROOT_DIR
	get_source_code

        if [ -z "$EXISTED_VERSION" ] ; then
		# Get info from CSV
		for MEMORY in $MEMORY_LIST;do
			get_csv_info $MEMORY
		done
		# Check meta-advantech tag exist or not, and checkout to tag version
		check_tag_and_checkout $META_ADVANTECH_PATH $META_ADVANTECH_BRANCH $HASH_ADVANTECH

		# Check tag exist or not, and replace bbappend file SRCREV
		check_tag_and_replace $U_BOOT_PATH $U_BOOT_URL $HASH_UBOOT
		check_tag_and_replace $KERNEL_PATH $KERNEL_URL $HASH_KERNEL

                commit_tag_and_rollback $META_ADVANTECH_PATH

                # Add git tag and Package kernel & u-boot
                echo "[ADV] Add tag"
                commit_tag_and_package $U_BOOT_URL $U_BOOT_BRANCH $HASH_UBOOT
                commit_tag_and_package $KERNEL_URL $KERNEL_BRANCH $HASH_KERNEL

                # Create manifests xml and commit
                create_xml_and_commit
        fi

fi

#cd $CURR_PATH
#rm -rf $ROOT_DIR

echo "[ADV] build script done!"

