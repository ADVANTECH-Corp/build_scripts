#!/bin/bash
set -e

usage()
{
    cat << EOF
Usage: `basename $0` [OPTIONS]

Generate package file to be used for OTA update on Yocto Linux

 -b <file>  Bootloader image file
 -k <file>  Kernel or Boot image file
 -d <file>  DTB (device tree) file
 -r <file>  Rootfs image file
 -o <file>  Output file
 -h         Show help
EOF
    exit 1;
}

OUTPUT="update"

while getopts "b:k:d:r:o:h" o; do
    case "${o}" in
    b)
        BOOTLOADER=${OPTARG}
        ;;
    k)
        KERNEL=${OPTARG}
        ;;
    d)
        DTB=${OPTARG}
        ;;
    r)
        ROOTFS=${OPTARG}
        ;;
    o)
        OUTPUT=${OPTARG}
        ;;
    *)
        usage
        ;;
    esac
done

if [ -z ${BOOTLOADER} ] && [ -z ${KERNEL} ] && [ -z ${DTB} ] && [ -z ${ROOTFS} ] ; then
    echo "Please specify at least one image file"
    echo ""
    usage
    exit 1
fi

CMD_BOOTLOADER="update-bootloader"
CMD_KERNEL="update-kernel"
CMD_DTB="update-dtb"
CMD_ROOTFS="update-rootfs"

UPDATE_DIR="ota-update"
UPDATE_SCRIPT="updater-script"

# Main
mkdir ${UPDATE_DIR}

if [ ! -z ${BOOTLOADER} ] ; then
    cp ${BOOTLOADER} ${UPDATE_DIR}
    MD5_SUM=`md5sum -b ${BOOTLOADER} | cut -d ' ' -f 1`
    echo "${CMD_BOOTLOADER},${BOOTLOADER},${MD5_SUM}" >> ${UPDATE_DIR}/${UPDATE_SCRIPT}
fi
if [ ! -z ${KERNEL} ] ; then
    cp ${KERNEL} ${UPDATE_DIR}
    MD5_SUM=`md5sum -b ${KERNEL} | cut -d ' ' -f 1`
    echo "${CMD_KERNEL},${KERNEL},${MD5_SUM}" >> ${UPDATE_DIR}/${UPDATE_SCRIPT}
fi
if [ ! -z ${DTB} ] ; then
    cp ${DTB} ${UPDATE_DIR}
    MD5_SUM=`md5sum -b ${DTB} | cut -d ' ' -f 1`
    echo "${CMD_DTB},${DTB},${MD5_SUM}" >> ${UPDATE_DIR}/${UPDATE_SCRIPT}
fi
if [ ! -z ${ROOTFS} ] ; then
    cp ${ROOTFS} ${UPDATE_DIR}
    MD5_SUM=`md5sum -b ${ROOTFS} | cut -d ' ' -f 1`
    echo "${CMD_ROOTFS},${ROOTFS},${MD5_SUM}" >> ${UPDATE_DIR}/${UPDATE_SCRIPT}
fi

zip -r ${OUTPUT} ${UPDATE_DIR}/*

rm -rf ${UPDATE_DIR}

echo "${OUTPUT}.zip is generated!"
