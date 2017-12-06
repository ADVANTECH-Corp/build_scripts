#!/bin/bash -xe

echo "[ADV] FTP_SITE = ${FTP_SITE}"
echo "[ADV] FTP_DIR = ${FTP_DIR}"
echo "[ADV] DATE = ${DATE}"
echo "[ADV] VERSION = ${VERSION}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] TARGET_OS = ${TARGET_OS}"
echo "[ADV] STORED = ${STORED}"
CURR_PATH="$PWD"
STORAGE_PATH="$CURR_PATH/$STORED"

get_ftp_files()
{
    FILE_NAME="$1"
    OUTPUT_FOLDER="$2"

    pftp -v -n ${FTP_SITE} <<-EOF
user "ftpuser" "P@ssw0rd"
cd "officialbuild/${FTP_DIR}/${DATE}"
prompt
binary
ls
mget ${FILE_NAME}
close
quit
EOF
    if [ "${OUTPUT_FOLDER}" == "" ]; then
        tar zxf ${FILE_NAME}
    else
        mkdir ${OUTPUT_FOLDER}
        tar zxf ${FILE_NAME} -C ${OUTPUT_FOLDER}
    fi
    rm ${FILE_NAME}
}

# === [Main] List Official Build Version ===
if [ $RSB_4760 == true ]; then
    MACHINE_LIST="$MACHINE_LIST 4760"
fi
if [ $EPC_R4761 == true ]; then
    MACHINE_LIST="$MACHINE_LIST 4761"
fi

NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
VERSION_NUM=$NUM1$NUM2

if [ $TARGET_OS == "Yocto" ]; then
    OS_PREFIX="L"
elif [ $TARGET_OS == "Debian" ]; then
    OS_PREFIX="D"
fi

# Get OTA script
sudo apt-get install zip
EDGE_BRANCH=`echo ${BSP_BRANCH} | cut -d '-' -f 1`
EDGE_PATTEN=`echo ${BSP_BRANCH} | cut -d '-' -f 2`
if [ "${EDGE_PATTEN}" == "EdgeSense" ]; then
    BSP_BRANCH="${EDGE_BRANCH}"
fi
wget https://github.com/ADVANTECH-Corp/meta-advantech/raw/${BSP_BRANCH}/meta-WISE-PaaS/recipes-ota/ota-script/files/ota-package.sh
chmod +x ota-package.sh

for NEW_MACHINE in $MACHINE_LIST
do
    RELEASE_VERSION="${NEW_MACHINE}${OS_PREFIX}IV${VERSION_NUM}"
    OS_FILE_NAME="${RELEASE_VERSION}_${DATE}"

    get_ftp_files ${OS_FILE_NAME}.tgz

    # Change rootfs to raw data
    cd ${OS_FILE_NAME}
    gunzip *rootfs.img.gz
    ROOTFS_NAME=`ls *rootfs.img`
    simg2img ${ROOTFS_NAME} ${ROOTFS_NAME%.img}.ext4
    
    ../ota-package.sh -k boot-*.img -o update_${OS_FILE_NAME}_kernel
    ../ota-package.sh -r *rootfs.ext4 -o update_${OS_FILE_NAME}_rootfs
    ../ota-package.sh -k boot-*.img -r *rootfs.ext4 -o update_${OS_FILE_NAME}_kernel_rootfs
    
    mv update*.zip $STORAGE_PATH
    cd ..
done
