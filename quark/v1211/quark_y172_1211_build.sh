#!/bin/bash
# vim: set ts=4 sw=4 ai noet:

SCRIPT=${0##*/}
SCRIPT_DIR=${0%/*} 
SCRIPT_ID=${SCRIPT%_*build*}
CPU_TYPE=${SCRIPT_ID%%_*}
BSP_ID=${SCRIPT_ID#${CPU_TYPE}_*}
YOCTO_VER=`sed 's/^y//; s/./&./g; s/.$//' <<< ${BSP_ID%_*}`
VENDOR_VER=`sed 's/./&./g; s/.$//' <<< ${BSP_ID#*_}`

#===== backup ================================================================
while [ -d ~/bin_old ]; do
	if diff ${SCRIPT} `ls -1 ~/bin_old/${SCRIPT}* | tail -1` ; then break ; fi
	cp -a $0 ~/bin_old/${SCRIPT}.`date +%Y%m%d_%H%M%S`
	break;
done &> /dev/null 
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#===== debug used ============================================================
[[ $DEBUG > 0 ]] && echo "===== ${SCRIPT}: debug mode enabled, level $DEBUG ====="

W_HEADER="\\\n===== $(date +'%F %R:%S') =====\\\n"
W_PFX="[ADV] "
# display value of variable (also works on array's element)
# e.g. W PATH CPU_ID[0] CPU_ID[1] 
function W()  { [[ $DEBUG < 2 ]] && return; eval echo -en $W_HEADER; for P in $@; do eval echo -e $W_PFX$P=\$\{$P\}$W_SFX; done; eval echo -en $W_FOOTER; }
# display array's all element
# e.g. WA CPU_ID
function WA() { [[ $DEBUG < 2 ]] && return; eval echo -en $W_HEADER; for P in $@; do for I in $(eval echo $(echo \$\{!$P[@]\})); do echo $P[$I]=`eval echo \$\{$P[$I]\}`; done; done; eval echo -en $W_FOOTER; }
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

function ERROR()
{
	if [ "$1" != "" ]; then echo -e "\nERROR:\t$1\n\n"; fi
	if [ "$2" != "" ]; then exit $2; else exit 255; fi
}

function USAGE()
{
	if [ "$1" != "" ]; then echo -e "\n$1"; fi
cat << END_OF_HELP

Syntax:

  ${0##*/} {product} {version} {memory} {stored} {date} {SRV_REV} {HASH_ADV}

    product : "bsp" for creating BSP only, "ubc221" or "ubc222"
    version : {"LIV"|"LBV"}{MAJOR}{MINOR}
              MAJOR : 1 digit (0 for daily build)
              MINOR : 3 digits 
    memory  : memory size on board
    stored  : stored directory of building
    date    : YYYY-MM-DD (\`date +%F\`)
    SRC_REV : linux kernel source revision
    HASH_ADV: meta-advantech commit hash (full or short)

END_OF_HELP
	if [ "$2" != "" ]; then exit $2; fi
}

# ==========================================================================
# parameter check & variable init
# ==========================================================================
if [ $# != 7 ]; then USAGE "!!! missing some parameter(s) !!!" 1; fi
if [ ! -d $4 ]; then ERROR "$4: No such directory" 1; fi

INTEL_VERSION="v${VENDOR_VER}"
GIT_BASE="git://github.com/ADVANTECH-Corp"
LINUX_VERSION="3.14"
PRODUCT=${1,,}
VERSION=${2^^}
MEMORY=${3^^}
STORED_DIR=`realpath $4`
DATE=$5
SRC_REV=$6
HASH_ADV=$7

############# checking {product}
case $PRODUCT in
bsp) VER_ID="quark" ;;
ubc221) VER_ID="U221" ;;
ubc222) VER_ID="U222" ;;
*) USAGE "!!! Invalid product !!!" 1 ;;
esac

############# checking version
if [ ${#VERSION} != 7 ]; then 
	USAGE "!!! Invalid version !!!" 1
fi

############# checking MAJOR & MINOR in {version}
VER=${VERSION##*L[IB]V}
MAJOR=${VER:0:1}
MINOR=${VER:1}
if ! [[ ${MAJOR} =~ ^[0-9]{1}$ ]] ; then
	USAGE "!!! Invalid MAJOR !!!" 1
fi
if ! [[ ${MINOR} =~ ^[0-9]{2}[0-9A-Z]$ ]] ; then
	USAGE "!!! Invalid MINOR !!!" 1
fi

############# checking {memory}
case ${MEMORY} in
512M);;
*) USAGE "!!! Invalid memory !!!" 1 ;;
esac

############# checking {stored}
if ! mkdir -p ${STORED_DIR}; then
	USAGE "!!! cannot make specified stored directory !!!" 1;
fi
if tempfile=`mktemp ${STORED_DIR}/XXXXXXXX 2> /dev/null`; then
	rm $tempfile
else
	USAGE "!!! Access denied in specified stored directory !!!" 1
fi

############# checking {date}
if ! [[ ${DATE} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || ! date -d "${DATE}" >/dev/null ; then
	USAGE "!!! Invalid date format !!!" 1
fi

############# checking {SRC_REV}
if [ ${#SRC_REV} != 40 ]; then
	USAGE "!!! Invalid linux kernel source revision !!!" 1
fi

############# checking {ADV_REV}
if [[ ${#HASH_ADV} != 7 && ${#HASH_ADV} != 40 ]]; then
	USAGE "!!! Invalid meta-advantech commit hash !!!" 1
fi

############# init required environment
CWD=`realpath ${0%/*}`
LBV_NODE="LBV${MAJOR}${MINOR}"
META_CLANTON="meta-clanton_${INTEL_VERSION}"
YOCTO_BUILD="yocto_build"
META_ADV=${CWD}/${LBV_NODE}/${META_CLANTON}/meta-advantech
KERNEL_BBAPPEND=${META_ADV}/meta-intel-quark/recipes-kernel/linux/linux-yocto-quark_${LINUX_VERSION}.bbappend

MOUNT_POINT="${CWD}/mnt"
BSP_PACK_NAME="quark${LBV_NODE}_${DATE}"
DEV_PKG_DIR="${CWD}/${LBV_NODE}/${META_CLANTON}/${YOCTO_BUILD}/tmp/deploy/ipk/i586"
PKG_LIST=(susi libdustdiag1 diagnostic st)
IMAGE_NODE="${VER_ID}${VERSION}_${CPU_TYPE}_${DATE}"
PACK_DIR="${CWD}/${IMAGE_NODE}"

HASH_BSP=`git ls-remote ${GIT_BASE}/adv-quark-bsp -b ${INTEL_VERSION} | cut -c1-40`

if [ "${MAJOR}" == "0" ]; then
	VER_EXT="advantech_quark_${MEMORY}_dailybuild_${SRC_REV:0:7}"
else
	VER_EXT="advantech_quark_${MEMORY}_${MAJOR}.${MINOR}_${SRC_REV:0:7}"
fi

############# redirect stdout stderr to log file
exec &> >(tee -i ${CWD}/${VER_ID}${VERSION}_${DATE}.log)

############# list all used environment
W SCRIPT SCRIPT_DIR SCRIPT_ID CPU_TYPE BSP_ID YOCTO_VER VENDOR_VER
W PRODUCT VERSION MEMORY STORED_DIR DATE
W CWD LBV_NODE GIT_BASE INTEL_VERSION META_CLANTON YOCTO_BUILD MOUNT_POINT KERNEL_BBAPPEND VER_EXT
W MAJOR MINOR BSP_PACK_NAME
W DEV_PKG_DIR PKG_LIST IMAGE_NODE
W HASH_BSP HASH_ADV SRC_REV

function init_build_environment()
{
	echo "[ADV] init build environment..."

	if [ ! -d ${CWD}/${LBV_NODE}/${META_CLANTON} ]; then
		ERROR "meta layer not found, missing first step ?" $?
	fi

	cd ${CWD}/${LBV_NODE}/${META_CLANTON}
	if ! BOARD=$PRODUCT source ./oe-init-build-env ${YOCTO_BUILD}; then
		ERROR "init build environment" $?
	fi
# BUILDDIR is set after oe-init-build-env
    if [[ ! -e downloads && -d /build3/dailybuild/quark_1211_downloads ]]; then
		echo "[ADV] link downloads"
		ln -sf /build3/dailybuild/quark_1211_downloads ./downloads
	fi
}

function generate_md5()
{
    FILENAME=$1

    if [ -e $FILENAME ]; then
        md5sum -b $FILENAME > $FILENAME.md5
    fi
}

function generate_csv()
{
	FILENAME=$1
	MD5_SUM=
	FILE_SIZE_BYTE=
	FILE_SIZE=
	FILE_PATH="${STORED_DIR}/${DATE}/$FILENAME"
	FILE_PATH="${FILE_PATH//\//\\}"
	FILE_PATH="${FILE_PATH/media/172.22.15.111}"

	if [ -e $FILENAME ]; then
		MD5_SUM=`cat ${FILENAME}.md5`
		set - `ls -l ${FILENAME}`; FILE_SIZE_BYTE=$5
		set - `ls -lh ${FILENAME}`; FILE_SIZE=$5
	fi

cat > ${FILENAME%.*}.csv << END_OF_CSV
ESSD Software/OS Update News
OS,Linux 3.14.28
Part Number,N/A
Author,
Date,${DATE}
Build Number,${VERSION}
TAG,
Tested Platform,${PRODUCT}
MD5 Checksum,TGZ: ${MD5_SUM}
Image Size,${FILE_SIZE}B (${FILE_SIZE_BYTE} bytes)
Issue description, N/A
Function Addition,
Updated Note,File in ${FILE_PATH}
adv-quark-bsp, ${HASH_BSP}
meta-advantech, ${HASH_ADV}
linux-quark, ${SRC_REV}
END_OF_CSV
}

function check_specified_revision_already_built()
{
	echo "[ADV] checking specified revision built or not..."
	if ! echo ${VER_EXT} | grep dailybuild &>/dev/null ; then return 1; fi

	for ONEDAY in $(seq 1 29)
	do
		PASTDAY=$(date -d "${DATE} - ${ONEDAY} days" +%F)
		if [ ! -e "${STORED_DIR}/${PASTDAY}" ]; then continue; fi
		if grep "${VER_EXT}" ${STORED_DIR}/${PASTDAY}/*.log &>/dev/null; then
			ERROR "the specified revision was built at ${PASTDAY}." 1
		fi
	done
}

function fetch_souce_code_and_repack_bsp()
{
	echo "[ADV] fetch source code and repack BSP"

	cd ${CWD}
	if [ -e ${BSP_PACK_NAME}.zip -o -e ${STORED_DIR}/${DATE}/${BSP_PACK_NAME}.zip ]; then
		echo "${BSP_PACK_NAME}.zip already exist, skip"
		return 0;
	fi
#	if ! svn export -r ${SVN_REV} ${SVN_URL}/${SVN_BSP_PATH}/${META_CLANTON} ${LBV_NODE}/${META_CLANTON}; then
#		ERROR "svn export ${META_CLANTON} failed" 1
#	fi

	mkdir -p ${CWD}/${LBV_NODE}
	pushd ${CWD}/${LBV_NODE}
	if ! repo init -u ${GIT_BASE}/adv-quark-bsp; then
		ERROR "repo init failed" 1
	fi
	repo sync
	pushd ${META_ADV}
	if ! git checkout ${HASH_ADV}; then
		ERROR "cannot checkout specified hash for meta-advantech commit" 1
	fi
	popd
	echo "SRCREV=\"${SRC_REV}\"" >> ${KERNEL_BBAPPEND}
	find ./ -name .git -exec rm -rf {} + -or -name .repo -exec rm -rf {} + 
	cd ${CWD}
	zip -r ${BSP_PACK_NAME}.zip ${LBV_NODE} -x \*meta-advantech/\*/recipes-devtools\*
	generate_md5 ${BSP_PACK_NAME}.zip

	cd ${CWD}/${LBV_NODE}
	[ -e spi-flash-tools ] && rm spi-flash-tools
	[ -e Quark_EDKII ] && rm Quark_EDKII
	[ -e sysimage ] && rm sysimage
	./sysimage_${INTEL_VERSION}/create_symlinks.sh
	popd
}

function build_image_full()
{
	echo "[ADV] build image full (for SDcard)"

	if [ "$BUILDDIR" == "" ]; then ERROR "No build environment" 1; fi

	sed -i "s/^LINUX_VERSION_EXTENSION.*/LINUX_VERSION_EXTENSION = \"-${VER_EXT}\"/" ${KERNEL_BBAPPEND}

	cd $BUILDDIR
	sed -i 's/^DISTRO ?= "iot-devkit-.*"/DISTRO ?= "iot-devkit-multilibc"/' conf/local.conf
	if ! bitbake linux-yocto-quark -c cleanall; then ERROR "linux-yocto-quark cleanall" $?; fi
	if ! bitbake image-full; then ERROR "image-full" $?; fi

	mkdir -p ${CWD}/${IMAGE_NODE}/sdcard

	pushd $BUILDDIR/tmp/deploy/images/quark/
	tar hcf - boot bzImage core-image-minimal-initramfs-quark.cpio.gz grub.efi image-full-quark.ext3 |\
		tar xf - -C ${CWD}/${IMAGE_NODE}/sdcard
	popd
}

function build_devtools()
{
	echo "[ADV] build devtools"

	if [ "$BUILDDIR" == "" ]; then ERROR "No build environment" 1; fi
	if [ ! -d $BUILDDIR/tmp/deploy/images/quark ]; then ERROR "image full not found" 1; fi

	cd $BUILDDIR
	sed -i 's/^DISTRO ?= "iot-devkit-.*"/DISTRO ?= "iot-devkit-multilibc"/' conf/local.conf

	RECIPES_LIST=`ls ${CWD}/${LBV_NODE}/${META_CLANTON}/meta-advantech/meta-intel-quark/recipes-devtools`

	for ITEM in ${RECIPES_LIST[@]}; do
		if ! bitbake ${ITEM} -c cleansstate; then ERROR "${ITEM} cleansstate" 1; fi
		if ! bitbake ${ITEM} ; then ERROR "${ITEM}" 1; fi
	done

	ALL_PKG=
	for PKG in ${PKG_LIST[@]}; do
		if PKGLIST=`ls $BUILDDIR/tmp/deploy/ipk/i586/${PKG}* 2> /dev/null`; then
			ALL_PKG="${ALL_PKG} $PKGLIST"
		else
			ERROR "missing ${PKG}*"
		fi
	done
	mkdir -p ${CWD}/${IMAGE_NODE}/devtools
	cp -a ${ALL_PKG} ${CWD}/${IMAGE_NODE}/devtools/
}

function build_image_eng()
{
	echo "[ADV] build image engineer used"

	[ "$BUILDDIR" == "" ] && ERROR "No build environment" 1
	[ ! -d ${CWD}/${IMAGE_NODE}/sdcard ] && ERROR "./${IMAGE_NODE}/sdcard not exist" 1
	[ ! -d ${CWD}/${IMAGE_NODE}/devtools ] && ERROR "./${IMAGE_NODE}/devtools not exist" 1

	[ -d ${CWD}/${IMAGE_NODE}/sdcard_eng ] && rm -rf ${CWD}/${IMAGE_NODE}/sdcard_eng
	cp -a ${CWD}/${IMAGE_NODE}/sdcard ${CWD}/${IMAGE_NODE}/sdcard_eng

	RECIPES_LIST=$(echo `ls ${CWD}/${LBV_NODE}/${META_CLANTON}/meta-advantech/meta-intel-quark/recipes-devtools`)

	echo "[ADV] install ${RECIPES_LIST}"
	for P in $RECIPES_LIST; do
		[ ! -d $BUILDDIR/tmp/work/i586-poky-linux/$P/*/packages-split/$P ] && ERROR "missing packages-split for $P" 1
	done
	rm $BUILDDIR/tmp/work/i586-poky-linux/diagnostic/*/packages-split/diagnostic/tools/*.{mp4,avi,wav} 2>/dev/null

	mkdir -p ${MOUNT_POINT}
	sudo mount ${CWD}/${IMAGE_NODE}/sdcard_eng/image-full-quark.ext3 ${MOUNT_POINT}
	for P in $RECIPES_LIST; do
		sudo cp -a $BUILDDIR/tmp/work/i586-poky-linux/$P/*/packages-split/$P/* ${MOUNT_POINT}/
	done
	sudo mv ${MOUNT_POINT}/usr/bin/st-fsl ${MOUNT_POINT}/tools/st-quark
	sudo umount ${MOUNT_POINT}
	rmdir ${MOUNT_POINT}
}

function build_toolchain()
{
	echo "[ADV] build toolchain"

	if [ "$BUILDDIR" == "" ]; then ERROR "No build environment" 1; fi
	if [ ! -d $BUILDDIR/tmp/deploy/images/quark ]; then ERROR "image full not found" 1; fi

	cd $BUILDDIR
	sed -i 's/^DISTRO ?= "iot-devkit-.*"/DISTRO ?= "iot-devkit-multilibc"/' conf/local.conf
	if ! bitbake image-full -c populate_sdk; then ERROR "image-full toolchain" $?; fi
	if [ ! -e $BUILDDIR/tmp/deploy/sdk/*toolchain*.sh ]; then
		ERROR "toolchain not found" 1
	fi
	mkdir -p ${CWD}/${LBV_NODE}_sdk
	pushd ${CWD}
	cp ${LBV_NODE}/${META_CLANTON}/${YOCTO_BUILD}/tmp/deploy/sdk/*toolchain*.sh ${LBV_NODE}_sdk/
	zip -r ${BSP_PACK_NAME}_sdk.zip ${LBV_NODE}_sdk
	generate_md5 ${BSP_PACK_NAME}_sdk.zip
	popd
}

function build_spi_flash_image()
{
	echo "[ADV] build spi flash image"

	if [ "$BUILDDIR" == "" ]; then ERROR "No build environment" 1; fi

	sed -i "s/^LINUX_VERSION_EXTENSION.*/LINUX_VERSION_EXTENSION = \"\"/" ${KERNEL_BBAPPEND}

	cd $BUILDDIR
	sed -i 's/^DISTRO ?= "iot-devkit-.*"/DISTRO ?= "iot-devkit-spi"/g' conf/local.conf
#	if ! bitbake linux-yocto-quark -c cleanall; then ERROR "linux-yocto-quark cleanall" $?; fi
	if ! bitbake image-spi; then ERROR "image-spi" $?; fi

	cd ${CWD}/${LBV_NODE}/Quark_EDKII
	if [ -e ./Build ]; then
		echo "[ADV] Quark_EDKII already built, skip"
#	elif ! ./buildallconfigs.sh GCC46 /usr/bin/ QuarkPlatform; then
#		ERROR "building Quark_EDKII" 1
	elif ! ./quarkbuild.sh -r32 GCC46 /usr/bin/ QuarkPlatform; then
		ERROR "building Quark_EDKII" 1
	else
		cd Build/QuarkPlatform
		mkdir PLAIN
		ln -s RELEASE_GCC46 RELEASE_GCC
		mv RELEASE_GCC* PLAIN/
	fi

	cd ${CWD}/${LBV_NODE}/sysimage/sysimage.CP-8M-release
	if ! ../../spi-flash-tools/Makefile; then 
		ERROR "building Flash-missingPDAT.bin" 1
	fi

	cd ${CWD}/${LBV_NODE}/spi-flash-tools/platform-data/
	if ! ./platform-data-patch.py -p $PRODUCT-platform-data.ini -i ../../sysimage/sysimage.CP-8M-release/Flash-missingPDAT.bin; then
		ERROR "building Flash+PlatformData.bin" 1
	fi

	mkdir -p ${CWD}/${IMAGE_NODE}/flash
	cd ${CWD}/${IMAGE_NODE}/flash
	cp -a ${CWD}/${LBV_NODE}/Quark_EDKII/Build/QuarkPlatform/PLAIN/RELEASE_GCC/FV/Applications/CapsuleApp.efi .
	cp -a ${CWD}/${LBV_NODE}/sysimage/sysimage.CP-8M-release/Flash-missingPDAT.bin .
	cp -a ${CWD}/${LBV_NODE}/spi-flash-tools/platform-data/Flash+PlatformData.bin .
}

function pack_image()
{
	cd ${CWD}

	zip -r ${IMAGE_NODE}.zip ${IMAGE_NODE}
	generate_md5 ${IMAGE_NODE}.zip
	generate_csv ${IMAGE_NODE}.zip
#	rm -rf $IMAGE_DIR
}

function move_to_stored_directory()
{
	cd ${CWD}

	mkdir -p ${STORED_DIR}/${DATE}
	mv *.{csv,md5,zip,log} ${STORED_DIR}/${DATE}
	return 0
}

###---------------------------------------------------###
###---------------------------------------------------###
###    Intel Quark BSP 1.2 VERSION                    ###
###---------------------------------------------------###
###    Auto build START                               ###
###---------------------------------------------------###

REVISION_BUILT_CHECK=${REVISION_BUILT_CHECK:-1}
REPACK_BSP=${REPACK_BSP:-1}
PACK_IMAGE=${PACK_IMAGE:-1}
#BUILD_ITEMS=${BUILD_ITEMS-"full sdk spi dev eng"}
BUILD_ITEMS=${BUILD_ITEMS-"full sdk spi"}

echo "REVISION_BUILT_CHECK=${REVISION_BUILT_CHECK}"
echo "REPACK_BSP=${REPACK_BSP}"
echo "PACK_IMAGE=${PACK_IMAGE}"
echo "BUILD_ITEMS=${BUILD_ITEMS}"

echo ""
[ -z "${NO_WAITING_KEY_C+x}" ] && if read -t5 -n1 -p "Waiting 5 seconds...('c'ontinue or others to stop)"; then
	if [ "$REPLY" != "c" ]; then echo -e "\ninterrupted"; exit 1; fi
fi
echo ""

[ "${REVISION_BUILT_CHECK}" == "1" ] && check_specified_revision_already_built

if [ "$PRODUCT" == "bsp" ]; then
	echo -e "\n\nBSP repacking ...\n\n"
	[ ${REPACK_BSP} == "1" ] && fetch_souce_code_and_repack_bsp
else
	echo -e "\n\nStart building ...\n\n"
	init_build_environment
	for ITEM in ${BUILD_ITEMS}; do
		case ${ITEM,,} in
		"full") build_image_full ;;
		"sdk")  build_toolchain ;;
		"spi")  build_spi_flash_image ;;
		"dev")  build_devtools ;;
		"eng")  build_image_eng ;;
		*) echo "[ADV] Unknown build item, $ITEM, skip";;
		esac
	done
	[ ${PACK_IMAGE} == "1" ] && pack_image
fi
( [ ${REPACK_BSP} == "1" ] || [ ${PACK_IMAGE} == "1" ] ) && move_to_stored_directory

exit 0
