#!/bin/bash
if [ "x${ALSO_BUILD_OFFICIAL_IMAGE}" != "x" ]; then
	# Dailybuild
	BUILD_SH="./imx8_zeus_dailybuild-aim30.sh"
	VERSION_NUM=${RELEASE_VERSION}
else
	NUM1=`expr $VERSION : 'V\([0-9A-Z]*\)'`
	NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
	# Official release
	BUILD_SH="./imx8_zeus_officialbuild-aim30.sh"
	VERSION_NUM=$NUM1$NUM2
fi

#imx8_BSP
$BUILD_SH imx8 imx8LBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

#imx8_projects
if [ $ROM7720A1 == true ]; then
	export BUILD_NN_IMX_CLEANSTATE=true
	$BUILD_SH rom7720a1-8QM 7720A1"$AIM_VERSION"LIV"$VERSION_NUM" "4G" "FSPI"
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5720A1 == true ]; then
	export BUILD_NN_IMX_CLEANSTATE=false
	$BUILD_SH rom5720a1-8M 5720A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G" ""
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5721A1 == true ]; then
	export BUILD_NN_IMX_CLEANSTATE=false
	$BUILD_SH rom5721a1-8MM 5721A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G 1G" "FSPI"
	[ "$?" -ne 0 ] && exit 1
fi
if [ $RSB3730A1 == true ]; then
	export BUILD_NN_IMX_CLEANSTATE=false
	$BUILD_SH rsb3730a1-8MM 3730A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G" "FSPI"
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5620A1 == true ]; then
	export BUILD_NN_IMX_CLEANSTATE=true
	$BUILD_SH rom5620a1-8X 5620A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G" "FSPI"
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM3620A1 == true ]; then
	export BUILD_NN_IMX_CLEANSTATE=true
	$BUILD_SH rom3620a1-8X 3620A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G" "FSPI"
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5722A1 == true ]; then
	export BUILD_NN_IMX_CLEANSTATE=true
	$BUILD_SH rom5722a1-8MP 5722A1"$AIM_VERSION"LIV"$VERSION_NUM" "6G 2G" "FSPI"
	[ "$?" -ne 0 ] && exit 1
fi
if [ $RSB3720A1 == true ]; then
	export BUILD_NN_IMX_CLEANSTATE=true
	$BUILD_SH rsb3720a1-8MP 3720A1"$AIM_VERSION"LIV"$VERSION_NUM" "6G 4G" "FSPI"
	[ "$?" -ne 0 ] && exit 1
fi

if [ $EPCR5710A1 == true ]; then
	export BUILD_NN_IMX_CLEANSTATE=true
	$BUILD_SH epcr5710a1-8MP 5710A1"$AIM_VERSION"LIV"$VERSION_NUM" "4G" "FSPI"
	[ "$?" -ne 0 ] && exit 1
fi

echo "[ADV] All done!"
