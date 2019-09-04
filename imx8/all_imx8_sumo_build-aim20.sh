#!/bin/bash
if [ "x${ALSO_BUILD_OFFICIAL_IMAGE}" != "x" ]; then
	# Dailybuild
	BUILD_SH="./imx8_sumo_dailybuild-aim20.sh"
	VERSION_NUM=${RELEASE_VERSION}
else
	NUM1=`expr $VERSION : 'V\([0-9]*\)'`
	NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
	# Official release
	BUILD_SH="./imx8_sumo_officialbuild-aim20.sh"
	VERSION_NUM=$NUM1$NUM2
fi

#imx6_BSP
$BUILD_SH imx8 imx8LBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

#imx6_projects
if [ $ROM7720A1 == true ]; then
	$BUILD_SH rom7720a1-8QM 7720A1"$AIM_VERSION"LIV"$VERSION_NUM" 4G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5720A1 == true ]; then
	$BUILD_SH rom5720a1-8M 5720A1"$AIM_VERSION"LIV"$VERSION_NUM" 2G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5620A1 == true ]; then
	$BUILD_SH rom5620a1-8X 5620A1"$AIM_VERSION"LIV"$VERSION_NUM" 2G
	[ "$?" -ne 0 ] && exit 1
fi

echo "[ADV] All done!"
