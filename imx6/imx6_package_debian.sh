#!/bin/bash  -xe

#echo "[ADV] FTP_SITE = ${FTP_SITE}"
echo "[ADV] FTP_DIR = ${FTP_DIR}"
echo "[ADV] DATE = ${DATE}"
echo "[ADV] VERSION = ${VERSION}"
echo "[ADV] STORED = ${STORED}"

FTP_SITE="172.22.31.128"
#FTP_DIR="imx6_yocto_bsp_2.1_2.0.0"
VERSION_TAG=$(echo $VERSION | sed 's/[.]//')

CURR_PATH="$PWD"
STORAGE_PATH="$CURR_PATH/$STORED"
UBUNTU_ROOTFS="rootfs.tar.bz2"

# === 1. Put the debian images into out/ folder. =================================================
function get_ubuntu_images()
{
    mkdir out
    echo "[ADV] get_modules linux ftp"
    pftp -v -n 172.22.31.128<<-EOF
user "ftpuser" "P@ssw0rd"
cd "Image/imx6/debian/"
prompt
binary
ls
mget ${UBUNTU_ROOTFS}
close
quit
EOF

 
    mv ${UBUNTU_ROOTFS} out/
    cd out/
    sudo tar jxf ${UBUNTU_ROOTFS}
    #sudo chown adv:adv -R *
    sudo rm -rf ${UBUNTU_ROOTFS}
    cd ..
}

function get_modules()
{
    
    MODULE_FILE_NAME="${PRODUCT}${VERSION_TAG}_${CPU_TYPE}_modules"
    FIRMWARE_FILE_NAME="${PRODUCT}${VERSION_TAG}_${CPU_TYPE}_firmware"
    echo "[ADV] get_modules ftp"

    pftp -v -n ${FTP_SITE}<<-EOF
user "ftpuser" "P@ssw0rd"
cd "officialbuild/${FTP_DIR}/${DATE}/"
prompt
binary
ls
mget ${MODULE_FILE_NAME}.tgz
mget ${FIRMWARE_FILE_NAME}.tgz
close
quit
EOF

    sudo mkdir out/firmware_file
    sudo tar zxf ${MODULE_FILE_NAME}.tgz
    sudo mv ${MODULE_FILE_NAME}/modules-${CPU_TYPE_Module}*.tgz out/
    sudo rm -rf ${MODULE_FILE_NAME}*
    cd $CURR_PATH/out/
    sudo tar zxf modules-${CPU_TYPE_Module}*.tgz 
    sudo rm -rf modules-${CPU_TYPE_Module}*.tgz
    cd $CURR_PATH
    sudo tar zxf ${FIRMWARE_FILE_NAME}.tgz
    sudo mv ${FIRMWARE_FILE_NAME}/* out/
    sudo rm -rf ${FIRMWARE_FILE_NAME}*
}

function package_ubuntu_rootfs()
{
        MODULE_VERSION=`echo $(ls $CURR_PATH/out/lib/modules/)`
        UBUNTU_ROOTFS_PATH="$CURR_PATH/out"

        echo "[ADV] ${MODULE_VERSION}"
	# Set up chroot
	sudo cp /usr/bin/qemu-arm-static $UBUNTU_ROOTFS_PATH/usr/bin/

	# Depmod in chroot mode
	sudo chroot $UBUNTU_ROOTFS_PATH << EOF
chown -R root:root /lib/modules
depmod -a ${MODULE_VERSION}
#apt-get install -y alien
#chown -R root:root *
#alien -i /firmware_product/${CPU_TYPE_Module}${NEW_MACHINE}/*.rpm
#alien -i /firmware_all/linux-firmware*.rpm
#------------------------------------------------------------------
exit
EOF
		echo "[ADV] finish chroot"
		sudo rm $UBUNTU_ROOTFS_PATH/usr/bin/qemu-arm-static
		sudo rm -rf $UBUNTU_ROOTFS_PATH/firmware_all
		sudo rm -rf $UBUNTU_ROOTFS_PATH/firmware_file
		sudo rm -rf $UBUNTU_ROOTFS_PATH/firmware_product

		cd $UBUNTU_ROOTFS_PATH
        echo "[ADV] Tar rootfs"
		cd $CURR_PATH
        #sudo tar zcf ${PRODUCT}${VERSION_TAG}_${CPU_TYPE}_rootfs.tgz . --warning=no-file-changed
        sudo tar zcvf ${PRODUCT}${VERSION_TAG}_${CPU_TYPE}_rootfs.tgz -C $CURR_PATH/out/ .
        echo "[ADV] Tar rootfs pass"
        #sudo mv ${PRODUCT}${VERSION}_${CPU_TYPE}_rootfs.tgz $STORAGE_PATH
}



function insert_image_file()
{
    IMAGE_TYPE=$1
	OUTPUT_DIR=$2
	FILE_NAME=$3



	# Maybe the loop device is occuppied, unmount it first
	#sudo umount $MOUNT_POINT
	#sudo losetup -d $LOOP_DEV


	cd $OUTPUT_DIR


	# Set up loop device
	sudo losetup $LOOP_DEV $FILE_NAME

	sudo mount ${LOOP_DEV}p2 $MOUNT_POINT/

    sudo rm -rf $MOUNT_POINT/*
	#sudo mkdir $MOUNT_POINT/image
	# Insert ubuntu file
	case $IMAGE_TYPE in
		"u1404")
			sudo cp -a $CURR_PATH/out/* $MOUNT_POINT/
			#generate_mksd_linux
			#sudo rm $ORIGINAL_FILE_NAME
			;;
		"debian8")
			sudo cp -a $ORIGINAL_FILE_NAME $MOUNT_POINT/image/$FILE_NAME
			generate_mksd_linux
			sudo rm $ORIGINAL_FILE_NAME
			;;
	esac

	sudo chmod o+x $MOUNT_POINT/usr/lib/dbus-1.0/dbus-daemon-launch-helper
    echo "[ADV] umount $MOUNT_POINT"
	sudo umount $MOUNT_POINT/
    echo "[ADV] losetup -d $LOOP_DEV"
	sudo losetup -d $LOOP_DEV

	cd ..
}

# Make mnt folder
MOUNT_POINT="$CURR_PATH/mnt"
if [ -e $MOUNT_POINT ]; then
	echo "[ADV] $MOUNT_POINT had already been created"
else
	echo "[ADV] mkdir $MOUNT_POINT"
	mkdir $MOUNT_POINT
fi

function generate_md5()
{
        FILENAME=$1

        if [ -e $FILENAME ]; then
                MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
                echo $MD5_SUM > $FILENAME.md5
        fi
}

function get_yocto_image()
{
   if [ $NEW_MACHINE == "ubc220a1-solo" ]; then
   IMAGE_FILE_NAME="fsl-image-qt5-${CPU_TYPE_Module}ubc220a1*.sdcard"
   elif [ $NEW_MACHINE == "rom7421a1-plus" ]; then
   IMAGE_FILE_NAME="fsl-image-qt5-${CPU_TYPE_Module}rom7421a1*.sdcard"
   else
   IMAGE_FILE_NAME="fsl-image-qt5-${CPU_TYPE_Module}${NEW_MACHINE}*.sdcard"
   fi
    IMAGE_NEW_FILE_NAME="${UBUNTU_PRODUCT}${VERSION_TAG}_${CPU_TYPE}_${DATE}.img"

    OUT_POINT="$CURR_PATH/yocto"
    mkdir $OUT_POINT
    echo "[ADV] get_modules linux ftp"
    pftp -v -n 172.22.31.128<<-EOF
user "ftpuser" "P@ssw0rd"
cd "officialbuild/${FTP_DIR}/${DATE}/"
prompt
binary
ls
mget ${IMAGE_FILE_NAME}
close
quit
EOF
    #echo "[ADV] gunzip"
    #sudo gunzip ${IMAGE_FILE_NAME}.gz
	echo "[ADV] Rename"
	sudo mv ${IMAGE_FILE_NAME} ${IMAGE_NEW_FILE_NAME}
    sudo mv ${IMAGE_NEW_FILE_NAME} ${OUT_POINT}/
    echo "[ADV]Insert Ubuntu image"
    insert_image_file "u1404" $OUT_POINT $IMAGE_NEW_FILE_NAME

	echo "[ADV] gzip"
	gzip -c9 $OUT_POINT/$IMAGE_NEW_FILE_NAME > ${IMAGE_NEW_FILE_NAME}.gz
	generate_md5 $IMAGE_NEW_FILE_NAME.img.gz

	sudo mv ${IMAGE_NEW_FILE_NAME}.gz $STORAGE_PATH
}

# === [Main] List Official Build Version ============================================================
if [ $RSB4410A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rsb4410a1"
fi
if [ $RSB4411A1  == true ]; then
	MACHINE_LIST="$MACHINE_LIST rsb4411a1"
fi
if [ $UBC220A1_SOLO == true ]; then
	MACHINE_LIST="$MACHINE_LIST ubc220a1-solo"
fi
if [ $UBC220A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST ubc220a1"
fi
if [ $UBCDS31A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST ubcds31a1"
fi
if [ $ROM5420A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rom5420a1"
fi

if [ $ROM5420B1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rom5420b1"
fi

if [ $ROM7420A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rom7420a1"
fi

if [ $ROM3420A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rom3420a1"
fi

if [ $ROM7421A1_PLUS == true ]; then
	MACHINE_LIST="$MACHINE_LIST rom7421a1-plus"
fi

if [ $ROM7421A1_SOLO == true ]; then
	MACHINE_LIST="$MACHINE_LIST rom7421-solo"
fi

if [ $RSB6410A2 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rsb6410a2"
fi

# UBUNTU
 OS_PREFIX="U"

echo "[ADV] get_ubuntu_images"
get_ubuntu_images


for NEW_MACHINE in $MACHINE_LIST
do
    #MISC_VERSION="${NEW_MACHINE}LIV${VERSION_NUM}"
    #RELEASE_VERSION="${NEW_MACHINE}${OS_PREFIX}IV${VERSION_NUM}"

    if [ $NEW_MACHINE == "rsb4411a1" ]; then
        PRODUCT="4411A1LI"
        UBUNTU_PRODUCT="4411A1DI"
		CPU_TYPE="DualQuad"
		CPU_TYPE_Module="imx6q"
    elif [ $NEW_MACHINE == "rsb4410a1" ]; then
        PRODUCT="4410A1LI"
		UBUNTU_PRODUCT="4410A1DI"
		CPU_TYPE="DualQuad"
		CPU_TYPE_Module="imx6q"
    elif [ $NEW_MACHINE == "ubc220a1-solo" ]; then
        PRODUCT="U220A1LI"
		UBUNTU_PRODUCT="U220A1DI"
		CPU_TYPE="DualLiteSolo"
		CPU_TYPE_Module="imx6dl"
    elif [ $NEW_MACHINE == "ubc220a1" ]; then
        PRODUCT="U220A1LI"
		UBUNTU_PRODUCT="U220A1DI"
		CPU_TYPE="DualQuad"
		CPU_TYPE_Module="imx6q"
    elif [ $NEW_MACHINE == "ubcds31a1" ]; then
        PRODUCT="DS31A1LI"
		UBUNTU_PRODUCT="DS31A1DI"
		CPU_TYPE="DualQuad"
		CPU_TYPE_Module="imx6q"
    elif [ $NEW_MACHINE == "rom5420a1" ]; then
        PRODUCT="5420A1LI"
		UBUNTU_PRODUCT="5420A1DI"
		CPU_TYPE="DualQuad"
		CPU_TYPE_Module="imx6q"
    elif [ $NEW_MACHINE == "rom5420b1" ]; then
        PRODUCT="5420B1LI"
		UBUNTU_PRODUCT="5420B1DI"
		CPU_TYPE="DualQuad"
		CPU_TYPE_Module="imx6q"
    elif [ $NEW_MACHINE == "rom7420a1" ]; then
        PRODUCT="7420A1LI"
		UBUNTU_PRODUCT="7420A1DI"
		CPU_TYPE="DualQuad"
		CPU_TYPE_Module="imx6q"
    elif [ $NEW_MACHINE == "rom3420a1" ]; then
        PRODUCT="3420A1LI"
		UBUNTU_PRODUCT="3420A1DI"
		CPU_TYPE="DualQuad"
		CPU_TYPE_Module="imx6q"
    elif [ $NEW_MACHINE == "rom7421a1-plus" ]; then
        PRODUCT="7421A1LI"
		UBUNTU_PRODUCT="7421A1DI"
		CPU_TYPE="DualQuadPlus"
		CPU_TYPE_Module="imx6qp"
    elif [ $NEW_MACHINE == "rsb6410a2" ]; then
        PRODUCT="6410A2LI"
        	UBUNTU_PRODUCT="6410A2DI"
		CPU_TYPE="DualQuad"
		CPU_TYPE_Module="imx6q"
    fi

    echo "[ADV] get_modules"
	get_modules

	package_ubuntu_rootfs
    get_yocto_image
done
