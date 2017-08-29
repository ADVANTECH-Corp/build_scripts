#!/bin/bash  -xe

#echo "[ADV] FTP_SITE = ${FTP_SITE}"
#echo "[ADV] FTP_DIR = ${FTP_DIR}"
#echo "[ADV] DATE = ${DATE}"
#echo "[ADV] VERSION = ${VERSION}"

#echo "[ADV] KERNEL_VERSION = ${KERNEL_VERSION}"
#echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
#echo "[ADV] STORED = ${STORED}"

FTP_SITE="172.22.12.82"
FTP_DIR="imx6_yocto_bsp_2.1_2.0.0"
DATE="2017-08-27"
VERSION="8001"

CURR_PATH="$PWD"
STORAGE_PATH="$CURR_PATH/$STORED"
UBUNTU_ROOTFS="u1404-rootfs-armhf"

# === 1. Put the debian images into out/ folder. =================================================
function get_ubuntu_images()
{
    echo "[ADV] get_modules linux ftp"
    pftp -v -n 172.22.12.82<<-EOF
user "ftpuser" "P@ssw0rd"
cd "Image/imx6/ubuntu/"
prompt
binary
ls
mget ${UBUNTU_ROOTFS}.img.gz
close
quit
EOF

	mv ${UBUNTU_ROOTFS}.tgz ./out/
    tar zxvf out/${UBUNTU_ROOTFS}.tgz
}

function get_modules()
{
    
    MODULE_FILE_NAME="${PRODUCT}${VERSION}_DualQuad_firmware.tgz"
    FIRMWARE_FILE_NAME="${PRODUCT}${VERSION}_DualQuad_module.tgz"
    echo "[ADV] get_modules ftp"

    pftp -v -n ${FTP_SITE} <<-EOF
user "ftpuser" "P@ssw0rd"
cd "officialbuild/${FTP_DIR}/${DATE}"
prompt
binary
ls
mget ${MISC_FILE_NAME}.tgz
close
quit
EOF

    tar zxf ${MODULE_FILE_NAME}.tgz
    #rm ${MODULE_FILE_NAME}.tgz
    tar zxf ${FIRMWARE_FILE_NAME}.tgz
    #rm ${FIRMWARE_FILE_NAME}.tgz
}



# === [Main] List Official Build Version ============================================================
if [ $RSB4410A1 == true ]; then
    MACHINE_LIST="$MACHINE_LIST rsb4410a1"
fi
if [ $RSB4411A1  == true ]; then
    MACHINE_LIST="$MACHINE_LIST rsb4411a1"
fi

NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9]*\)'`
VERSION_NUM=$NUM1$NUM2

# UBUNTU
 OS_PREFIX="U"

echo "[ADV] get_ubuntu_images"
get_ubuntu_images


for NEW_MACHINE in $MACHINE_LIST
do
    #MISC_VERSION="${NEW_MACHINE}LIV${VERSION_NUM}"
    #RELEASE_VERSION="${NEW_MACHINE}${OS_PREFIX}IV${VERSION_NUM}"

    if [ $NEW_MACHINE == "rsb4411a1" ]; then
        PRODUCT="4411LIV"
    elif [ $NEW_MACHINE == "rsb4410a1" ]; then
        PRODUCT="4410LIV"
    fi	
    echo "[ADV] get_modules"
	get_modules

done
