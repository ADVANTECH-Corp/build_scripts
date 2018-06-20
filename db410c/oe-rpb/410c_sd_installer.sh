#!/bin/bash -xe

echo "[ADV] FTP_SITE = ${FTP_SITE}"
echo "[ADV] FTP_DIR = ${FTP_DIR}"
echo "[ADV] DATE = ${DATE}"
echo "[ADV] VERSION = ${VERSION}"
echo "[ADV] BL_LINARO_RELEASE = ${BL_LINARO_RELEASE}"
echo "[ADV] BL_BUILD_NUMBER = ${BL_BUILD_NUMBER}"
echo "[ADV] INSTALLER_LINARO_RELEASE = ${INSTALLER_LINARO_RELEASE}"
echo "[ADV] INSTALLER_BUILD_VERSION = ${INSTALLER_BUILD_VERSION}"
echo "[ADV] TARGET_OS = ${TARGET_OS}"
echo "[ADV] DEBIAN_VER = ${DEBIAN_VER}"
echo "[ADV] STORED = ${STORED}"
CURR_PATH="$PWD"
STORAGE_PATH="$CURR_PATH/$STORED"

function get_ftp_files()
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

function generate_md5()
{
    FILENAME=$1

    if [ -e $FILENAME ]; then
        MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
        echo $MD5_SUM > $FILENAME.md5
    fi
}

# === 1. Put the installer images into out/ folder. =================================================
function get_installer_images()
{
    # Get Linaro boot tools
    git clone --depth 1 -b master https://github.com/ADVANTECH-Corp/db-boot-tools.git
    # record commit info in build log
    cd db-boot-tools
    git log -1

    # Get SD and EMMC bootloader package
    wget --progress=dot -e dotbytes=2M \
         https://github.com/ADVANTECH-Corp/db-boot-tools/raw/${BL_LINARO_RELEASE}-adv/advantech_bootloader_sd_linux-${BL_BUILD_NUMBER}.zip
    wget --progress=dot -e dotbytes=2M \
         https://github.com/ADVANTECH-Corp/db-boot-tools/raw/${BL_LINARO_RELEASE}-adv/advantech_bootloader_emmc_linux-${BL_BUILD_NUMBER}.zip

    unzip -d out advantech_bootloader_sd_linux-${BL_BUILD_NUMBER}.zip

    # Get installer rootfs
    pftp -v -n ${FTP_SITE} <<-EOF
user "ftpuser" "P@ssw0rd"
cd "Image/db410c/96boards/${INSTALLER_LINARO_RELEASE}"
prompt
binary
ls
mget linaro-${INSTALLER_OS_FLAVOUR}-installer-qcom-snapdragon-arm64-${INSTALLER_BUILD_VERSION}.img.gz
close
quit
EOF

    cp linaro-${INSTALLER_OS_FLAVOUR}-installer-qcom-snapdragon-arm64-${INSTALLER_BUILD_VERSION}.img.gz out/rootfs.img.gz
    gunzip out/rootfs.img.gz
}

function get_boot_installer_images()
{
    # Get installer boot
    OS_FILE_NAME="${SDBOOT_VERSION}_${DATE}_sdboot.tgz"
    get_ftp_files $OS_FILE_NAME

    cp boot-installer-*.img out/boot.img
}

# === 2. Prepare Target OS images ===================================================================
function prepare_target_os()
{
# --- [Advantech] ---
    mkdir -p os/${TARGET_OS}

    # Get target OS images from FTP

    OS_FILE_NAME="${RELEASE_VERSION}_${DATE}"

    case ${TARGET_OS} in
    "Yocto")
        get_ftp_files ${OS_FILE_NAME}.tgz
        cp ${OS_FILE_NAME}/boot-*.img os/${TARGET_OS}/boot.img
        cp ${OS_FILE_NAME}/*rootfs.img.gz os/${TARGET_OS}/rootfs.img.gz
        gunzip os/${TARGET_OS}/rootfs.img.gz
        cp ${OS_FILE_NAME}/recovery*.img os/${TARGET_OS}/recovery.img
        ;;
    "Debian8"|"Debian9")
        OS_FILE_NAME="${OS_FILE_NAME}_${DEBIAN_OS_FLAVOUR}"
        get_ftp_files ${OS_FILE_NAME}.tgz ${OS_FILE_NAME}
        cp ${OS_FILE_NAME}/boot-*.img os/${TARGET_OS}/boot.img
        cp ${OS_FILE_NAME}/*.img.gz os/${TARGET_OS}/rootfs.img.gz
        gunzip os/${TARGET_OS}/rootfs.img.gz
        echo "This is a fake recovery image!" > os/${TARGET_OS}/recovery.img
        ;;
    "Android")
        # To-Do
        ;;
    esac
# ------

    cat << EOF >> os/${TARGET_OS}/os.json
{
"name": "Advantech ${TARGET_OS} OS image",
"url": "",
"version": "${RELEASE_VERSION}",
"release_date": "${DATE}",
"description": "Official Release (${VERSION}) for ${PRODUCT}"
}
EOF

    if [ ${TARGET_OS} == "Android" ]; then
        //To-Do
    else
        cp dragonboard410c/linux/partitions.txt os/${TARGET_OS}
        unzip -d os/${TARGET_OS} advantech_bootloader_emmc_linux-${BL_BUILD_NUMBER}.zip
    fi
}

# === 3. Generate os.img & execute mksdcard script ==================================================
function make_os_img()
{
    SD_INSTALLER_IMG_NAME="${RELEASE_VERSION}_${DATE}_sd_installer.img"

    cp mksdcard flash os/

    # get size of OS partition
    size_os=$(du -sk os | cut -f1)
    size_os=$(((($size_os + 1024 - 1) / 1024) * 1024))
    size_os=$(($size_os + 200*1024))
    # pad for SD image size (including rootfs and bootloaders)
    size_img=$(($size_os + 1024*1024 + 300*1024))

    # create OS image
    sudo rm -f out/os.img
    sudo mkfs.fat -a -F32 -n "OS" -C out/os.img $size_os

    if [ -e mnt ] ; then
        sudo rm -rf mnt
    fi

    mkdir -p mnt
    sudo mount -o loop out/os.img mnt
    sudo cp -r os/* mnt/
    sudo umount mnt
    sudo ./mksdcard -p dragonboard410c/linux/installer.txt -s $size_img -i out -o ${SD_INSTALLER_IMG_NAME}

    # create archive for publishing
    gzip -c9 ${SD_INSTALLER_IMG_NAME} > ${SD_INSTALLER_IMG_NAME}.gz
    generate_md5 ${SD_INSTALLER_IMG_NAME}.gz
    mv ${SD_INSTALLER_IMG_NAME}.gz $STORAGE_PATH
    mv *.md5 $STORAGE_PATH
}

# === [Main] List Official Build Version ============================================================
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

get_installer_images

for NEW_MACHINE in $MACHINE_LIST
do
    RELEASE_VERSION="${NEW_MACHINE}${OS_PREFIX}IV${VERSION_NUM}"
    SDBOOT_VERSION="${NEW_MACHINE}LIV${VERSION_NUM}"
    if [ $NEW_MACHINE == "4760" ]; then
        PRODUCT="RSB-4760"
    elif [ $NEW_MACHINE == "4761" ]; then
        PRODUCT="EPC-R4761"
    fi

    get_boot_installer_images

    if [ -e os ] ; then
        sudo rm -rf os
    fi

    if [ $OS_PREFIX == "D" ]; then
        for TARGET_OS in $DEBIAN_VER    #redefined TARGET_OS
        do
            echo "NOW ${TARGET_OS}"
            if [ $TARGET_OS == "Debian8" ]; then
                DEBIAN_OS_FLAVOUR="jessie"
            elif [ $TARGET_OS == "Debian9" ]; then
                DEBIAN_OS_FLAVOUR="stretch"
            fi
            prepare_target_os
        done
    else
        prepare_target_os
    fi
    make_os_img
done
