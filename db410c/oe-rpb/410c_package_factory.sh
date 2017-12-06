#!/bin/bash

echo "[ADV] FTP_SITE = ${FTP_SITE}"
echo "[ADV] FTP_DIR = ${FTP_DIR}"
echo "[ADV] DATE = ${DATE}"
echo "[ADV] VERSION = ${VERSION}"
echo "[ADV] BL_LINARO_RELEASE = ${BL_LINARO_RELEASE}"
echo "[ADV] BL_BUILD_NUMBER = ${BL_BUILD_NUMBER}"
echo "[ADV] STORED = ${STORED}"
CURR_PATH="$PWD"
STORAGE_PATH="$CURR_PATH/$STORED"

# === 1. Put the debian images into out/ folder. =================================================
function get_images()
{

# --- [Advantech] ---
    if [ -e os ] ; then
        sudo rm -rf os
    fi
    mkdir -p os/${TARGET_OS}

    # Get target OS images from FTP

    OS_FILE_NAME="${RELEASE_VERSION}_${DATE}"
    SDBOOT_NAME="${OS_FILE_NAME}_sdboot"
    SDK_NAME="410c${OS_PREFIX}BV${VERSION_NUM}_${DATE}_sdk"

    pftp -v -n ${FTP_SITE} <<-EOF
user "ftpuser" "P@ssw0rd"
cd "officialbuild/${FTP_DIR}/${DATE}"
prompt
binary
ls
mget ${OS_FILE_NAME}.tgz
mget ${SDBOOT_NAME}.tgz
mget ${SDK_NAME}.tgz
close
quit
EOF

    tar zxf ${OS_FILE_NAME}.tgz
    rm ${OS_FILE_NAME}.tgz

    mkdir -p ${SDBOOT_NAME}
    tar -C ${SDBOOT_NAME} -zxf ${SDBOOT_NAME}.tgz 
    rm ${SDBOOT_NAME}.tgz

    tar zxf ${SDK_NAME}.tgz
    rm ${SDK_NAME}.tgz

    mv ${OS_FILE_NAME}/*rootfs.img.gz os/${TARGET_OS}/rootfs.img.gz
    mv ${OS_FILE_NAME}/recovery*.img os/${TARGET_OS}/recovery.img
    mv ${SDBOOT_NAME}/boot-sdboot*.img os/${TARGET_OS}/boot.img
    mv ${SDK_NAME}/*.sh os/${TARGET_OS}/sdk.sh

    gunzip os/${TARGET_OS}/rootfs.img.gz
}
function install_sdk()
{
	./os/${TARGET_OS}/sdk.sh <<-EOF
/opt/poky/oecore-x86_64
y
EOF
	
	source /opt/poky/oecore-x86_64/environment-setup-aarch64-oe-linux
}

function build_susi_3.0()
{
	git clone http://advgitlab.eastasia.cloudapp.azure.com/db410c/susi_3.0.git
	cd susi_3.0
	./configure --host aarch64-oe-linux --prefix /usr
	make
	make install DESTDIR=${CURR_PATH}/os/${TARGET_OS}/
	cd ..
}

function build_susi_4.0()
{
	git clone http://advgitlab.eastasia.cloudapp.azure.com/db410c/SUSI4.0_BIN_FILE.git
	cd SUSI4.0_BIN_FILE
	tar zxvf SUSI4.0.bin.tgz

	cp -ar ./Driver/libSUSI-4.00.so* ${CURR_PATH}/os/${TARGET_OS}/usr/lib/
	cp -ar ./Susi4Demo/*.h ${CURR_PATH}/os/${TARGET_OS}/usr/include/
	cd ..
}

function build_diagnostic()
{
	git clone http://advgitlab.eastasia.cloudapp.azure.com/db410c/diagnostic.git
	cd diagnostic
	./configure --host aarch64-oe-linux --prefix / CPPFLAGS=-I${CURR_PATH}/os/${TARGET_OS}/usr/include LDFLAGS=-L${CURR_PATH}/os/${TARGET_OS}/usr/lib
	make install DESTDIR=${CURR_PATH}/os/${TARGET_OS}/
	cd ..
}

function package_rootfs()
{
	sudo umount /mnt
	sudo losetup -d /dev/loop1

	simg2img ./os/${TARGET_OS}/rootfs.img rootfs_tmp.raw

    sudo losetup /dev/loop1 rootfs_tmp.raw
    sudo mount /dev/loop1 /mnt

    sudo cp -ar ./os/${TARGET_OS}/usr /mnt/
    sudo cp -ar ./os/${TARGET_OS}/tools /mnt/

	# Set up chroot
	sudo cp /usr/bin/qemu-aarch64-static /mnt/usr/bin/

	# Depmod in chroot mode
	sudo chroot /mnt << EOF
systemctl mask serial-getty@ttyMSM0.service
exit
EOF

	sudo rm /mnt/usr/bin/qemu-aarch64-static

	sudo umount /mnt
	sudo losetup -d /dev/loop1
	
	ext2simg -v rootfs_tmp.raw rootfs.img

	mv rootfs.img ./os/${TARGET_OS}/rootfs.img

	rm rootfs_tmp.raw
}

function generate_md5()
{
    FILENAME=$1

    if [ -e $FILENAME ]; then
        MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
        echo $MD5_SUM > $FILENAME.md5
    fi
}

function do_mksdcard()
{
	FACTORY_IMG_NAME="${RELEASE_VERSION}_${DATE}_sd_factory.img"

	git clone https://github.com/ADVANTECH-Corp/db-boot-tools.git
	cd db-boot-tools
	wget --progress=dot -e dotbytes=2M \
            https://github.com/ADVANTECH-Corp/db-boot-tools/raw/${BL_LINARO_RELEASE}-adv/advantech_bootloader_sd_linux-${BL_BUILD_NUMBER}.zip -P advantech_bootloader_sd_linux
	
	cd advantech_bootloader_sd_linux
	unzip advantech_bootloader_sd_linux-${BL_BUILD_NUMBER}.zip
	cp -ar ${CURR_PATH}/os/${TARGET_OS}/boot.img ./
	cp -ar ${CURR_PATH}/os/${TARGET_OS}/rootfs.img ./
	cp -ar ${CURR_PATH}/os/${TARGET_OS}/recovery.img ./
	cd ..
	sudo ./mksdcard -p dragonboard410c/linux/sdcard.txt -s 3G -i advantech_bootloader_sd_linux -o ${FACTORY_IMG_NAME}

	gzip -c9 ${FACTORY_IMG_NAME} > ${FACTORY_IMG_NAME}.gz
	generate_md5 ${FACTORY_IMG_NAME}.gz
	mv ${FACTORY_IMG_NAME}.gz ${STORAGE_PATH}
	mv *.md5 ${STORAGE_PATH}

	rm ${FACTORY_IMG_NAME}
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


for NEW_MACHINE in $MACHINE_LIST
do
    RELEASE_VERSION="${NEW_MACHINE}${OS_PREFIX}IV${VERSION_NUM}"


    if [ $NEW_MACHINE == "4760" ]; then
        PRODUCT="RSB-4760"
    elif [ $NEW_MACHINE == "4761" ]; then
        PRODUCT="EPC-R4761"
    fi
	
	get_images
	install_sdk
	build_susi_3.0
	build_susi_4.0
	build_diagnostic
	package_rootfs

	do_mksdcard
done
