#!/bin/bash -xe

echo "[ADV] FTP_DIR = ${FTP_DIR}"
echo "[ADV] DATE = ${DATE}"
echo "[ADV] VERSION = ${VERSION}"
echo "[ADV] BL_LINARO_RELEASE = ${BL_LINARO_RELEASE}"
echo "[ADV] BL_BUILD_NUMBER = ${BL_BUILD_NUMBER}"
echo "[ADV] INSTALLER_LINARO_RELEASE = ${INSTALLER_LINARO_RELEASE}"
echo "[ADV] INSTALLER_BUILD_VERSION = ${INSTALLER_BUILD_VERSION}"
echo "[ADV] TARGET_OS = ${TARGET_OS}"

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
         https://github.com/ADVANTECH-Corp/db-boot-tools/raw/${BL_LINARO_RELEASE}/dragonboard410c_bootloader_sd_linux-${BL_BUILD_NUMBER}.zip
    wget --progress=dot -e dotbytes=2M \
         https://github.com/ADVANTECH-Corp/db-boot-tools/raw/${BL_LINARO_RELEASE}-adv/advantech_bootloader_emmc_linux-${BL_BUILD_NUMBER}.zip

    unzip -d out dragonboard410c_bootloader_sd_linux-${BL_BUILD_NUMBER}.zip

    # Get installer boot & rootfs
    wget --progress=dot -e dotbytes=2M \
         http://advgitlab.eastasia.cloudapp.azure.com/db410c/sd-installer/raw/${INSTALLER_LINARO_RELEASE}/boot-installer-linaro-stretch-qcom-snapdragon-arm64-${INSTALLER_BUILD_VERSION}.img.gz
    wget --progress=dot -e dotbytes=2M \
         http://advgitlab.eastasia.cloudapp.azure.com/db410c/sd-installer/raw/${INSTALLER_LINARO_RELEASE}/linaro-stretch-installer-qcom-snapdragon-arm64-${INSTALLER_BUILD_VERSION}.img.gz

    cp boot-installer-linaro-stretch-qcom-snapdragon-arm64-${INSTALLER_BUILD_VERSION}.img.gz out/boot.img.gz
    cp linaro-stretch-installer-qcom-snapdragon-arm64-${INSTALLER_BUILD_VERSION}.img.gz out/rootfs.img.gz
    gunzip out/{boot,rootfs}.img.gz
}

# === 2. Prepare Target OS images ===================================================================
function prepare_target_os()
{
# --- [Advantech] ---
    if [ -e os ] ; then
        sudo rm -rf os
    fi
    mkdir -p os/${TARGET_OS}

    # Get target OS images from FTP

    OS_FILE_NAME="${RELEASE_VERSION}_${DATE}"

    pftp -v -n 172.22.12.82 <<-EOF
user "ftpuser" "P@ssw0rd"
cd "officialbuild/${FTP_DIR}/${DATE}"
prompt
binary
ls
mget ${OS_FILE_NAME}.tgz
close
quit
EOF
    tar zxf ${OS_FILE_NAME}.tgz
    rm ${OS_FILE_NAME}.tgz

    case ${TARGET_OS} in
    "Yocto")
        cp ${OS_FILE_NAME}/boot-Image*.img os/${TARGET_OS}/boot.img
        cp ${OS_FILE_NAME}/*rootfs.img.gz os/${TARGET_OS}/rootfs.img.gz
        gunzip os/${TARGET_OS}/rootfs.img.gz
        ;;
    "Debian")
        # To-Do
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

    cp mksdcard flash os/

    if [ ${TARGET_OS} == "Android" ]; then
        # To-Do
    else
        cp dragonboard410c/linux/partitions.txt os/${TARGET_OS}
        unzip -d os/${TARGET_OS} advantech_bootloader_emmc_linux-${BL_BUILD_NUMBER}.zip
    fi
}

# === 3. Generate os.img & execute mksdcard script ==================================================
function make_os_img()
{
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
    sudo ./mksdcard -p dragonboard410c/linux/installer.txt -s $size_img -i out -o ${RELEASE_VERSION}_sd_install.img

    # create archive for publishing
    tar czf ${RELEASE_VERSION}_sd_install.tgz ${RELEASE_VERSION}_sd_install.img
    mv ${RELEASE_VERSION}_sd_install.tgz ../
}

# === [Main] List Official Build Version ============================================================
if [ $RSB_4760 == true ]; then
    MACHINE_LIST="$MACHINE_LIST 4760"
fi
if [ $EPC_R4761 == true ]; then
    MACHINE_LIST="$MACHINE_LIST 4761"
fi

NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9]*\)'`
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
    if [ $NEW_MACHINE == "4760" ]; then
        PRODUCT="RSB-4760"
    elif [ $NEW_MACHINE == "4761" ]; then
        PRODUCT="EPC-R4761"
    fi

    prepare_target_os
    make_os_img
done
