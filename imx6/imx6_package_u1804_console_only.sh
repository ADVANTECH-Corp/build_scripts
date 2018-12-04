#!/bin/bash  -xe
# 2018/12/04: copy from imx6_package_ubuntu.sh

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
UBUNTU_ROOTFS="u1804_armhf_console_v20181113_1405"

# === 1. Put the debian images into out/ folder. =================================================
function get_ubuntu_images()
{
    mkdir out
    echo "[ADV] get_modules linux ftp"
    pftp -v -n 172.22.31.128<<-EOF
user "ftpuser" "P@ssw0rd"
cd "Image/imx6/ubuntu/"
prompt
binary
ls
mget ${UBUNTU_ROOTFS}.tgz
close
quit
EOF

 
    mv ${UBUNTU_ROOTFS}.tgz out/
    cd out/
    sudo tar zxf ${UBUNTU_ROOTFS}.tgz
    #sudo chown adv:adv -R *
    sudo rm -rf ${UBUNTU_ROOTFS}.tgz
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
#------------------------------------------------------------------#
exit
EOF
		echo "[ADV] finish chroot"
		sudo rm $UBUNTU_ROOTFS_PATH/usr/bin/qemu-arm-static
		sudo rm -rf $UBUNTU_ROOTFS_PATH/firmware_all
		sudo rm -rf $UBUNTU_ROOTFS_PATH/firmware_file
		sudo rm -rf $UBUNTU_ROOTFS_PATH/firmware_product
: <<'EOT' #comment out the following section till EOT
		cd $UBUNTU_ROOTFS_PATH
        echo "[ADV] Tar rootfs"
		cd $CURR_PATH
        #sudo tar zcf ${PRODUCT}${VERSION_TAG}_${CPU_TYPE}_rootfs.tgz . --warning=no-file-changed
        sudo tar zcvf ${PRODUCT}${VERSION_TAG}_${CPU_TYPE}_rootfs.tgz -C $CURR_PATH/out/ .
        echo "[ADV] Tar rootfs pass"
        #sudo mv ${PRODUCT}${VERSION}_${CPU_TYPE}_rootfs.tgz $STORAGE_PATH
EOT
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
    sudo cp -a $CURR_PATH/out/* $MOUNT_POINT/

	#sudo chown -R 0.0 $MOUNT_POINT/image
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
    IMAGE_FILE_NAME="fsl-image-qt5-${CPU_TYPE_Module}${NEW_MACHINE}*.sdcard"
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
    insert_image_file $OUT_POINT $IMAGE_NEW_FILE_NAME

	echo "[ADV] gzip"
	gzip -c9 $OUT_POINT/$IMAGE_NEW_FILE_NAME > ${IMAGE_NEW_FILE_NAME}.gz
	generate_md5 $IMAGE_NEW_FILE_NAME.img.gz

	sudo mv ${IMAGE_NEW_FILE_NAME}.gz $STORAGE_PATH
}

# === [Main] List Official Build Version ============================================================
TOTAL_LIST=" \
    RSB4410A1 \
    RSB4411A1 \
    UBC220A1_SOLO \
    UBC220A1 \
    UBCDS31A1 \
    ROM5420A1 \
    ROM5420B1 \
    ROM7420A1 \
    ROM3420A1 \
    ROM7421A1_PLUS \
    ROM7421A1_SOLO \
    RSB6410A2 \
"
MACHINE_LIST=""

for M in $TOTAL_LIST; do
  VAR_NAME=$M
  M=${M,,}
  eval [[ \$${VAR_NAME} == true ]] && MACHINE_LIST="$MACHINE_LIST${M//_/-} "
done

# echo MACHINE_LIST=\"$MACHINE_LIST\"

# UBUNTU
 OS_PREFIX="N"

echo "[ADV] get_ubuntu_images"
get_ubuntu_images

for NEW_MACHINE in $MACHINE_LIST
do
    #MISC_VERSION="${NEW_MACHINE}LIV${VERSION_NUM}"
    #RELEASE_VERSION="${NEW_MACHINE}${OS_PREFIX}IV${VERSION_NUM}"

    
    case ${NEW_MACHINE/*-} in
    solo) CPU_TYPE="DualLiteSolo"; CPU_TYPE_Module="imx6dl" ;;
    plus) CPU_TYPE="DualQuadPlus"; CPU_TYPE_Module="imx6qp" ;;
    *)    CPU_TYPE="DualQuad";     CPU_TYPE_Module="imx6q"  ;;
    esac

    NEW_MACHINE=${NEW_MACHINE/-*}
    case $NEW_MACHINE in
    rsb4411a1) PROD="4411A1" ;;
    rsb4410a1) PROD="4410A1" ;;
    ubc220a1)  PROD="U220A1" ;;
    ubcds31a1) PROD="DS31A1" ;;
    rom5420a1) PROD="5420A1" ;;
    rom5420b1) PROD="5420B1" ;;
    rom7420a1) PROD="7420A1" ;;
    rom3420a1) PROD="3420A1" ;;
    rom7421a1) PROD="7421A1" ;;
    rsb6410a2) PROD="6410A2" ;;
    *) echo "cannot handle \"$NEW_MACHINE\""; exit 1 ;;
    esac

    PRODUCT="${PROD}LI"
    UBUNTU_PRODUCT="${PROD}NI"

    echo "[ADV] get_modules"
	get_modules

	package_ubuntu_rootfs
    get_yocto_image
done
