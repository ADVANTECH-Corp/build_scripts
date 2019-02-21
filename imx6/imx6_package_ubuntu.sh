#!/bin/bash  -xe

echo "[ADV] FTP_SITE = ${FTP_SITE}"
echo "[ADV] FTP_DIR = ${FTP_DIR}"
echo "[ADV] DATE = ${DATE}"
echo "[ADV] VERSION = ${VERSION}"
echo "[ADV] STORED = ${STORED}"

echo "[ADV] UBUNTU_VERSION = ${UBUNTU_VERSION}"
echo "[ADV] UBUNTU_ROOTFS = ${UBUNTU_ROOTFS}"

VERSION_TAG=$(echo $VERSION | sed 's/[.]//')

CURR_PATH="$PWD"
STORAGE_PATH="$CURR_PATH/$STORED"

MOUNT_POINT="$CURR_PATH/mnt"
if [ -e $MOUNT_POINT ]; then
	echo "[ADV] $MOUNT_POINT had already been created"
else
	echo "[ADV] mkdir $MOUNT_POINT"
	mkdir -p $MOUNT_POINT
fi

function get_ubuntu_rootfs()
{
    echo "[ADV] get_ubuntu_rootfs"
    mkdir out
    pftp -v -n ${FTP_SITE} << EOF
user "ftpuser" "P@ssw0rd"
cd "Image/imx6/ubuntu/${UBUNTU_VERSION}"
prompt
binary
ls
mget ${UBUNTU_ROOTFS}.tgz
close
quit
EOF
}

function generate_md5()
{
    FILENAME=$1

    if [ -e $FILENAME ]; then
        MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
        echo $MD5_SUM > $FILENAME.md5
    fi
}

function generate_mksd_linux()
{
    sudo mkdir $MOUNT_POINT/mk_inand
    chmod 755 $CURR_PATH/mksd-linux.sh
    sudo cp $CURR_PATH/mksd-linux.sh $MOUNT_POINT/mk_inand/
    sudo chown 0.0 $MOUNT_POINT/mk_inand/mksd-linux.sh
}

function create_ubuntu_image()
{
    SDCARD_SIZE=7200

    YOCTO_IMAGE="fsl-image-qt5-${CPU_TYPE_Module}${NEW_MACHINE}*.sdcard"
    UBUNTU_IMAGE="${UBUNTU_PRODUCT}${VERSION_TAG}_${CPU_TYPE}_${DATE}.img"
    pftp -v -n ${FTP_SITE} << EOF
user "ftpuser" "P@ssw0rd"
cd "officialbuild/${FTP_DIR}/${DATE}/"
prompt
binary
ls
mget ${YOCTO_IMAGE}
close
quit
EOF

    echo "[ADV] rename yocto image file to ubuntu image file"
    sudo mv ${YOCTO_IMAGE} ${UBUNTU_IMAGE}
    sudo losetup ${LOOP_DEV} ${UBUNTU_IMAGE}
    sudo mount ${LOOP_DEV}p2 $MOUNT_POINT/
    sudo mkdir -p $MOUNT_POINT/.modules
    sudo mv $MOUNT_POINT/lib/modules/* $MOUNT_POINT/.modules/
    sudo rm -rf $MOUNT_POINT/*
    sudo tar xvf ${UBUNTU_ROOTFS}.tgz -C $MOUNT_POINT/
    sudo mkdir -p $MOUNT_POINT/lib/modules
    sudo mv $MOUNT_POINT/.modules/* $MOUNT_POINT/lib/modules/
    sudo rmdir $MOUNT_POINT/.modules
    sudo umount $MOUNT_POINT
    sudo losetup -d ${LOOP_DEV}

    # resize
    sudo mv ${UBUNTU_IMAGE} ${UBUNTU_IMAGE/.img}.sdcard
    sudo dd if=/dev/zero of=${UBUNTU_IMAGE} bs=1M count=$SDCARD_SIZE
    sudo losetup ${LOOP_DEV} ${UBUNTU_IMAGE}
    echo "[ADV] resize ${UBUNTU_IMAGE} to ${SDCARD_SIZE}MB"
    sudo dd if=${UBUNTU_IMAGE/.img}.sdcard of=$LOOP_DEV
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

    # insert mksd-linux.sh & sdcard image
    sudo mount ${LOOP_DEV}p2 $MOUNT_POINT
    sudo mkdir -p $MOUNT_POINT/image
    sudo mv ${UBUNTU_IMAGE/.img}.sdcard $MOUNT_POINT/image/
    sudo chown -R 0.0 $MOUNT_POINT/image
    generate_mksd_linux
    sudo umount $MOUNT_POINT
    sudo losetup -d $LOOP_DEV

    # output file
    gzip -c9 ${UBUNTU_IMAGE} > ${UBUNTU_IMAGE}.gz
    md5sum ${UBUNTU_IMAGE}.gz > ${UBUNTU_IMAGE/.img}.md5
    sudo mv ${UBUNTU_IMAGE}.gz $STORAGE_PATH
    sudo mv ${UBUNTU_IMAGE/.img}.md5 $STORAGE_PATH
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
case $UBUNTU_VERSION in
14.04) OS_PREFIX="T" ;; # Trusty Tahr
16.04) OS_PREFIX="X" ;; # Xenial Xerus
18.04) OS_PREFIX="B" ;; # Bionic Beaver
*) echo "cannot generate Ubuntu \"$UBUNTU_VERSION\""; exit 1 ;;
esac

get_ubuntu_rootfs

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
    UBUNTU_PRODUCT="${PROD}${OS_PREFIX}I"

    create_ubuntu_image
done
