#!/bin/bash
PARAM=$#
[ $PARAM -lt 6 ] && echo "ex. ./imx6_dailybuild_yocto_2.0.0.sh rom7420a1 7420A1LIV8010 1G date storage backend-type 8010" && exit 1
ROOT_DIR=$1_$2
PRODUCT=$1
OFFICIAL_VER=$2
MEMORY_TYPE=$3
DATE_PATH=$4
STORAGE_PATH=$5
BACKEND_TYPE=$6
VER_TAG="imx6LBV"$7

MEMORY_COUT=1
MEMORY=`echo $MEMORY_TYPE | cut -d '-' -f $MEMORY_COUT`
PRE_MEMORY=""

echo "$Release_Note" > Release_Note
REALEASE_NOTE="Release_Note"

LOOP_DEV="/dev/loop4"

#---------[ Functions ]---------#

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

function get_source_code()
{
        echo "[ADV] get yocto source code"
        cd $ROOT_DIR
        repo init -u $BSP_URL -b $BSP_BRANCH
        repo sync
        cd $CURR_PATH
}
function check_tag_and_checkout()
{
        FILE_PATH=$1
        REMOTE_URL=$2
        if [ -d "$ROOT_DIR/$FILE_PATH" ];then
                cd $ROOT_DIR/$FILE_PATH
                META_TAG=`git tag | grep $VER_TAG`
                if [ "$META_TAG" != "" ]; then
                        echo "[ADV] meta-advantech has been tagged ,and check to this $VER_TAG version"
                        git checkout $VER_TAG
                        git tag --delete $VER_TAG
                        git push --delete $REMOTE_URL refs/tags/$VER_TAG
                else
                        echo "[ADV] meta-advantech isn't tagged ,nothing to do"
                fi
                cd $CURR_PATH
        else
                echo "[ADV] Directory $ROOT_DIR/$FILE_PATH doesn't exist"
                exit 0
        fi
}

function check_tag_and_replace()
{
        REMOTE_URL=$1
        FILE_PATH=$2
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
        REMOTE_URL=$2
        HASH_ID=`git ls-remote $REMOTE_URL $VER_TAG | awk '{print $1}'`
        DIR=`ls $FILE_PATH`
        if [ "$HASH_ID" != "" ]; then
                echo "[ADV] $REMOTE_URL has been tagged ,there is no need to add tag"
	else
		if [ -d "$FILE_PATH/$DIR/git" ];then
			echo "[ADV] Add tag $VER_TAG on $REMOTE_URL"
			cd $FILE_PATH/$DIR/git
			git tag -a $VER_TAG -m "official build $VER_TAG"
			git push $REMOTE_URL $VER_TAG
			cd $CURR_PATH
		else
			echo "[ADV] Directory $FILE_PATH/$DIR/git doesn't exist"
			exit 0
		fi
	fi
}

function create_branch_and_commit()
{
        FILE_PATH=$1
        REMOTE_URL=$2
        if [ -d "$ROOT_DIR/$FILE_PATH" ];then
                cd $ROOT_DIR/$FILE_PATH
                git checkout -b $VER_TAG
                git add .
                git commit -m "official build $VER_TAG"
                git push $REMOTE_URL $VER_TAG
                cd $CURR_PATH
        else
                echo "[ADV] Directory $ROOT_DIR/$FILE_PATH doesn't exist"
                exit 0
        fi
}

function create_xml_and_commit()
{
        if [ -d "$ROOT_DIR/.repo/manifests" ];then
                echo "[ADV] Create XML file"
                cd $ROOT_DIR/.repo/manifests
                git checkout $BSP_BRANCH
                cp default.xml $VER_TAG.xml
                sed -i "s/\"meta-advantech\" revision=\"$META_ADVANTECH_BRANCH\"/\"meta-advantech\" revision=\"$VER_TAG\"/g" $VER_TAG.xml
                git add $VER_TAG.xml
                git commit -F $CURR_PATH/$REALEASE_NOTE
                git push
		git tag -a $VER_TAG -F $CURR_PATH/$REALEASE_NOTE
		git push origin $VER_TAG
                cd $CURR_PATH
        else
                echo "[ADV] Directory $ROOT_DIR/.repo/manifests doesn't exist"
                exit 0
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

function generate_table()
{
        FILENAME=$1
        MD5_SUM="NULL"
        FILE_SIZE_BYTE="0"
        FILE_SIZE="0"

        if [ -e $FILENAME ]; then
                MD5_SUM=`cat ${FILENAME}.md5`
                FILE_SIZE_BYTE=`ls -l ${FILENAME} | awk '{print $5}'`
                FILE_SIZE=$((${FILE_SIZE_BYTE}/1024/1024))
        fi

        echo "ESSD Software/OS Update News" > $FILENAME.csv
        echo "OS,Linux ${KERNEL_VERSION}" >> $FILENAME.csv
        echo "Part Number,N/A" >> $FILENAME.csv
        echo "Author," >> $FILENAME.csv
        echo "Date,${DATE_PATH}" >> $FILENAME.csv
        echo "U-Boot,U-Boot ${U_BOOT_VERSION}-${OFFICIAL_VER}" >> $FILENAME.csv
        echo "Build Number,${OFFICIAL_VER}" >> $FILENAME.csv
        echo "TAG," >> $FILENAME.csv
        echo "Tested Platform,${PRODUCT}" >> $FILENAME.csv
        echo "MD5 Checksum,TGZ: ${MD5_SUM}" >> $FILENAME.csv
        echo "Image Size,${FILE_SIZE}MB (${FILE_SIZE_BYTE} bytes)" >> $FILENAME.csv
        echo "Issue description,N/A" >> $FILENAME.csv
        echo "Function Addition," >> $FILENAME.csv
        FILE_PATH=`echo "$STORAGE_PATH/$DATE_PATH/$FILENAME"|sed 's/\//\\\\/g'|sed 's/media/172.22.15.111/g'`
        echo "Updated Note,File in \\${FILE_PATH}" >> $FILENAME.csv
}

function add_version()
{
        # Set U-boot version
        sed -i "/UBOOT_LOCALVERSION/d" $ROOT_DIR/sources/meta-advantech/meta-fsl-imx6/recipes-bsp/u-boot/u-boot-imx_${U_BOOT_VERSION}.bbappend
        echo "UBOOT_LOCALVERSION = \"-$OFFICIAL_VER\"" >> $ROOT_DIR/sources/meta-advantech/meta-fsl-imx6/recipes-bsp/u-boot/u-boot-imx_${U_BOOT_VERSION}.bbappend

        # Set Linux version
        sed -i "/LOCALVERSION/d" $ROOT_DIR/sources/meta-advantech/meta-fsl-imx6/recipes-kernel/linux/linux-imx_${KERNEL_VERSION}.bbappend
        echo "LOCALVERSION = \"-$OFFICIAL_VER\"" >> $ROOT_DIR/sources/meta-advantech/meta-fsl-imx6/recipes-kernel/linux/linux-imx_${KERNEL_VERSION}.bbappend
}

function set_environment()
{
        cd $CURR_PATH/$ROOT_DIR

        if [ "$1" == "sdk" ]; then
                # Link downloads directory from backup
                if [ -e $CURR_PATH/downloads ] ; then
                       echo "[ADV] link downloads directory"
                       ln -s $CURR_PATH/downloads downloads
                fi
                # Use RSB-4410 as default device for sdk
                EULA=1 MACHINE=$DEFAULT_DEVICE source fsl-setup-release.sh -b $BUILDALL_DIR -e $BACKEND_TYPE
        else
                # Change MACHINE setting
                sed -i "s/MACHINE ??=.*/MACHINE ??= '${KERNEL_CPU_TYPE}${PRODUCT}'/g" $BUILDALL_DIR/conf/local.conf
                NEW_MACHINE=`cat $BUILDALL_DIR/conf/local.conf | grep MACHINE`
                echo "[ADV] change $NEW_MACHINE"

                EULA=1 source setup-environment $BUILDALL_DIR
        fi
}

function save_temp_log()
{
        cd $CURR_PATH

        LOG_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR"
        cd $LOG_PATH
        echo "[ADV] mkdir $LOG_DIR"
        mkdir $LOG_DIR

        # Backup conf, run script & log file
        cp -a conf $LOG_DIR
        find . -name "log.*" ! -path "$LOG_DIR" -o -name "run.*" ! -path "$LOG_DIR" | xargs -i cp -a --parents {} $LOG_DIR

        echo "[ADV] creating ${LOG_DIR}.tgz ..."
        tar czf $LOG_DIR.tgz $LOG_DIR
        generate_md5 $LOG_DIR.tgz

        mv -f $LOG_DIR.tgz $STORAGE_PATH/$DATE_PATH/
        mv -f $LOG_DIR.tgz.md5 $STORAGE_PATH/$DATE_PATH/

        # Remove all temp logs
        rm -rf $LOG_DIR
        find . -name "temp" | xargs rm -rf
}
function building()
{
        echo "[ADV] building $1 $2..."
        LOG_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_"$DATE_PATH"_log

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

        [ "$?" -ne 0 ] && echo "[ADV] Build failure! Check details in ${LOG_DIR}.tgz" && save_temp_log && exit 1
}

function build_yocto_sdk()
{
        set_environment sdk

        # Build imx6qrsb4410a1 full image first
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
        sed -i "s/${PRODUCT}_.*_config/${PRODUCT}_${MEMORY}_config/g" $ROOT_DIR/sources/meta-advantech/meta-fsl-imx6/conf/machine/${KERNEL_CPU_TYPE}${PRODUCT}.conf
        cd  $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR
        building u-boot-imx cleansstate
        building u-boot-imx
        bitbake $DEPLOY_IMAGE_NAME -c rootfs -f
        cd  $CURR_PATH
}

function generate_mksd_linux()
{
	sudo mkdir $MOUNT_POINT/mk_inand
	chmod 755 $CURR_PATH/mksd-linux.sh
	sudo mv $CURR_PATH/mksd-linux.sh $MOUNT_POINT/mk_inand/
	sudo chown 0.0 $MOUNT_POINT/mk_inand/mksd-linux.sh
}

function generate_mkspi_advboot()
{
        sudo mkdir $MOUNT_POINT/recovery
        chmod 755 $CURR_PATH/mkspi-advboot.sh
        sudo mv $CURR_PATH/mkspi-advboot.sh $MOUNT_POINT/recovery/
        sudo chown 0.0 $MOUNT_POINT/recovery/mkspi-advboot.sh
}
function insert_image_file()
{
    IMAGE_TYPE=$1
    OUTPUT_DIR=$2
    FILE_NAME=$3
    DO_RESIZE="no"

    if [ "$IMAGE_TYPE" == "normal" ]; then
        DO_RESIZE="yes"
    fi

    # Maybe the loop device is occuppied, unmount it first
    sudo umount $MOUNT_POINT
    sudo losetup -d $LOOP_DEV

    cd $OUTPUT_DIR

    if [ "$DO_RESIZE" == "yes" ]; then
        ORIGINAL_FILE_NAME="$FILE_NAME".original
        mv $FILE_NAME $ORIGINAL_FILE_NAME
        dd if=/dev/zero of=$FILE_NAME bs=1M count=4200
    fi

    # Set up loop device
    sudo losetup $LOOP_DEV $FILE_NAME

    if [ "$DO_RESIZE" == "yes" ]; then
        echo "[ADV] resize $FILE_NAME"
        sudo dd if=$ORIGINAL_FILE_NAME of=$LOOP_DEV
        sudo sync
        rootfs_start=`sudo fdisk -u -l ${LOOP_DEV} | grep ${LOOP_DEV}p2 | cut -d ' ' -f 12`
sudo fdisk -u $LOOP_DEV << EOF &>/dev/null
d
2
n
p
2
$rootfs_start
$PARTITION_SIZE_LIMIT
w
EOF
      sudo sync
        sudo e2fsck -f -y ${LOOP_DEV}p2
        sudo resize2fs ${LOOP_DEV}p2
    fi

    sudo mount ${LOOP_DEV}p2 $MOUNT_POINT
    sudo mkdir $MOUNT_POINT/image

    # Insert specific image file
    case $IMAGE_TYPE in
    "normal")
        sudo cp -a $ORIGINAL_FILE_NAME $MOUNT_POINT/image/$FILE_NAME
        sudo cp $DEPLOY_IMAGE_PATH/u-boot_crc.bin* $MOUNT_POINT/image/
        generate_mksd_linux
        sudo rm $ORIGINAL_FILE_NAME
        ;;
    "eng")
        sudo cp $DEPLOY_IMAGE_PATH/SPL-${KERNEL_CPU_TYPE}${PRODUCT}-${MEMORY} $MOUNT_POINT/image/SPL
        generate_mkspi_advboot
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
        if [ "$OUTPUT_DIR" == "" ]; then
                echo "[ADV] prepare_images: invalid parameter #2!"
                exit 1;
        else
                echo "[ADV] mkdir $OUTPUT_DIR"
                mkdir $OUTPUT_DIR
        fi

        # Prepare image files in output directory
        case $IMAGE_TYPE in
                "sdk")
                        cp $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/tmp/deploy/sdk/* $OUTPUT_DIR/
                        ;;
                "normal")
                        FILE_NAME=${DEPLOY_IMAGE_NAME}"-"${KERNEL_CPU_TYPE}${PRODUCT}"*.rootfs.sdcard"
                        cp $DEPLOY_IMAGE_PATH/$FILE_NAME $OUTPUT_DIR
                        if [ -e $OUTPUT_DIR/$FILE_NAME ]; then
                                FILE_NAME=`ls $OUTPUT_DIR | grep rootfs.sdcard`

                                # Insert mksd-linux.sh for both normal
                                insert_image_file "normal" $OUTPUT_DIR $FILE_NAME
                        fi
                        ;;
                "eng")
                        FILE_NAME=`readlink $DEPLOY_IMAGE_PATH/"${DEPLOY_IMAGE_NAME}-${KERNEL_CPU_TYPE}${PRODUCT}.sdcard" | cut -d '.' -f 1`".rootfs.eng.sdcard"
                        cp $DEPLOY_IMAGE_PATH/$FILE_NAME $OUTPUT_DIR
                        if [ -e $OUTPUT_DIR/$FILE_NAME ]; then
                                FILE_NAME=`ls $OUTPUT_DIR | grep rootfs.eng.sdcard`
                                insert_image_file "eng" $OUTPUT_DIR $FILE_NAME
                        fi
                        ;;
               "mfgtools")
			git clone $MFGTOOLS_URL -b $MFGTOOLS_BRANCH
                        cp -rf Mfgtools/* $OUTPUT_DIR/
                        rm -rf Mfgtools
                        cp $DEPLOY_IMAGE_PATH/u-boot.imx $OUTPUT_DIR/Profiles/Linux/OS\ Firmware/firmware/
                        cp $DEPLOY_IMAGE_PATH/zImage-${KERNEL_CPU_TYPE}*.dtb $OUTPUT_DIR/Profiles/Linux/OS\ Firmware/firmware/
                        sed -i "s/dtb =.*/dtb = `ls $DEPLOY_IMAGE_PATH/zImage-${KERNEL_CPU_TYPE}*.dtb | xargs -n1 basename| cut -d '.' -f 1 | sed s/zImage\-//g`/g" $OUTPUT_DIR/cfg.ini
                        ;;
                *)
                        echo "[ADV] prepare_images: invalid parameter #1!"
                        exit 1;
                        ;;
        esac

        # Package image file
        case $IMAGE_TYPE in
                "sdk" | "mfgtools")
                        echo "[ADV] creating ${OUTPUT_DIR}.tgz ..."
                        tar czf $OUTPUT_DIR.tgz $OUTPUT_DIR
                        generate_md5 $OUTPUT_DIR.tgz
                        ;;
                *) # Normal, Eng images
                        echo "[ADV] creating ${OUTPUT_DIR}.img.gz ..."
                        gzip -c9 $OUTPUT_DIR/$FILE_NAME > $OUTPUT_DIR.img.gz
                        generate_md5 $OUTPUT_DIR.img.gz
                        ;;
        esac
        rm -rf $OUTPUT_DIR
}

function copy_image_to_storage()
{
    echo "[ADV] copy $1 image to $STORAGE_PATH/$DATE_PATH"
    case $1 in
    "imx6")
        echo "[ADV] PWD Path:$PWD"

        if [ ! -e $ROOT_DIR.tgz ] ; then
            echo "[ADV] $ROOT_DIR.tgz file doesn't exit"
        else
            echo "[ADV] $ROOT_DIR.tgz file exits"
        fi

        if [ ! -e $SDK_DIR.tgz ] ; then
            echo "[ADV] $SDK_DIR.tgz file doesn't exit"
        else
            echo "[ADV] $SDK_DIR.tgz file exits"
        fi

        mv -f $ROOT_DIR.tgz $STORAGE_PATH/$DATE_PATH/
        mv -f $SDK_DIR.tgz $STORAGE_PATH/$DATE_PATH/
        ;;
    "eng")
        mv -f $ENG_IMAGE_DIR.img.gz $STORAGE_PATH/$DATE_PATH/
        ;;
    "normal")
        generate_table $IMAGE_DIR.img.gz
        mv $IMAGE_DIR.img.gz.csv $STORAGE_PATH/$DATE_PATH/
        mv -f $IMAGE_DIR.img.gz $STORAGE_PATH/$DATE_PATH/
        ;;
    "mfgtools")
        mv -f $MFG_IMAGE_DIR.tgz $STORAGE_PATH/$DATE_PATH/
        ;;
    *)
        echo "[ADV] copy_image_to_storage: invalid parameter #1!"
        exit 1;
        ;;
    esac
}

#---------[ Main procedure ]---------#

define_cpu_type $PRODUCT

CURR_PATH="$PWD"
echo "$PWD"

MOUNT_POINT="$CURR_PATH/mnt"
if [ ! -e $MOUNT_POINT ]; then
       mkdir $MOUNT_POINT
fi

echo "MEMORY=$MEMORY"

ROOT_DIR="$VER_TAG"_"$DATE_PATH"
mkdir $ROOT_DIR
echo "ROOT_DIR=$ROOT_DIR"

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

echo "DEPLOY_IMAGE_NAME=$DEPLOY_IMAGE_NAME"
echo "BACKEND_TYPE=$BACKEND_TYPE"


# Make storage folder
if [ -e $STORAGE_PATH/$DATE_PATH ] ; then
        echo "[ADV] $STORAGE_PATH/$DATE_PATH had already been created"
else
        echo "[ADV] mkdir $STORAGE_PATH/$DATE_PATH"
        mkdir -p $STORAGE_PATH/$DATE_PATH
fi
if [ "$PRODUCT" == "imx6" ]; then
        # Get source code from Git HUB
        get_source_code

        # Check meta-advantech tag exist or not, and checkout to tag version
        check_tag_and_checkout $META_ADVANTECH_PATH $META_ADVANTECH_URL

        # Check tag exist or not, and replace bbappend file SRCREV
        check_tag_and_replace $U_BOOT_URL $U_BOOT_PATH $U_BOOT_BRANCH
        check_tag_and_replace $KERNEL_URL $KERNEL_PATH $KERNEL_BRANCH

        # Commit and create meta-advantech branch
        create_branch_and_commit $META_ADVANTECH_PATH $META_ADVANTECH_URL

        # BSP source code
        echo "[ADV] tar $ROOT_DIR.tgz file"
        tar czf $ROOT_DIR.tgz $ROOT_DIR
        generate_md5 $ROOT_DIR.tgz

        # Build Yocto SDK
        echo "[ADV] build yocto sdk"
        build_yocto_sdk
        SDK_DIR="$ROOT_DIR"_sdk
        prepare_images sdk $SDK_DIR

        # Add git tag
        echo "[ADV] Add tag"
        auto_add_tag $ROOT_DIR/$BUILDALL_DIR/tmp/work/$DEFAULT_DEVICE-poky-linux-gnueabi/u-boot-imx $U_BOOT_URL
        auto_add_tag $ROOT_DIR/$BUILDALL_DIR/tmp/work/$DEFAULT_DEVICE-poky-linux-gnueabi/linux-imx $KERNEL_URL

        # Create manifests xml and commit
        create_xml_and_commit

        # Remove pre-built image & backup generic rpm packages
        rm $CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/tmp/deploy/images/imx6qrsb4410a1/*

        echo "[ADV] Copy $PRODUCT image to storage"
        copy_image_to_storage $PRODUCT

else #"$PRODUCT" != "imx6"
        if [ ! -e $ROOT_DIR ]; then
                echo -e "No BSP is found!\nStop building." && exit 1
        fi

        echo "[ADV] add version"
        add_version

        # Build images
        build_yocto_images

        DEPLOY_IMAGE_PATH="$CURR_PATH/$ROOT_DIR/$BUILDALL_DIR/tmp/deploy/images/${KERNEL_CPU_TYPE}${PRODUCT}"

        # Normal image
        echo "[ADV] generate normal image"
        IMAGE_DIR="$OFFICIAL_VER"_"$CPU_TYPE"_"$DATE_PATH"
        prepare_images normal $IMAGE_DIR
        copy_image_to_storage normal


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

                #MfgTools
                echo "[ADV] generate Mfgtools $MEMORY image"
                MFG_IMAGE_DIR="$IMAGE_DIR"_"$MEMORY"_mfgtools
                prepare_images mfgtools $MFG_IMAGE_DIR
                copy_image_to_storage mfgtools

                PRE_MEMORY=$MEMORY
                MEMORY_COUT=$(($MEMORY_COUT+1))
                MEMORY=`echo $MEMORY_TYPE | cut -d '-' -f $MEMORY_COUT`
                if [ "$MEMORY" == "" ]; then
                        break
                fi
        done
fi

mv -f *.md5 $STORAGE_PATH/$DATE_PATH/
sudo rm -rf $MOUNT_POINT

# Backup log files
save_temp_log

# Copy downloads to backup
if [ ! -e $CURR_PATH/downloads ] ; then
    echo "[ADV] backup 'downloads' directory"
    cp -a $CURR_PATH/$ROOT_DIR/downloads $CURR_PATH
fi

echo "[ADV] build script done!"
                                               
