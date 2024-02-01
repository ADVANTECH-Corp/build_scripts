#!/bin/bash

function build_project()
{
	echo "[ADV] $1 start"
	if [ $1 == "OfficialBuild" ]; then
		BUILD_SH="./imx8_zeus_officialbuild-aim30.sh"
	else
		BUILD_SH="./imx8_zeus_dailybuild-aim30.sh"
	fi
	VERSION_NUM=${RELEASE_VERSION}
	echo "[ADV] BUILD_SH = $BUILD_SH"
	echo "[ADV] VERSION_NUM = $VERSION_NUM"

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
		$BUILD_SH rom5721a1-8MM 5721A1"$AIM_VERSION"LIV"$VERSION_NUM" "4G 2G 1G" "FSPI"
		[ "$?" -ne 0 ] && exit 1
	fi

	if [ $RSB3730A2 == true ]; then
			export BUILD_NN_IMX_CLEANSTATE=false
		    $BUILD_SH rsb3730a2-8MM 3730A2"$AIM_VERSION"LIV"$VERSION_NUM" "4G 2G" ""
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
		    $BUILD_SH rom5722a1-8MP 5722A1"$AIM_VERSION"LIV"$VERSION_NUM" "8G 6G 4G 2G" "FSPI"
		    [ "$?" -ne 0 ] && exit 1
	fi

	if [ $RSB3720A1 == true ]; then
		export BUILD_NN_IMX_CLEANSTATE=true
		$BUILD_SH rsb3720a1-8MP 3720A1"$AIM_VERSION"LIV"$VERSION_NUM" "8G 6G 4G 2G" "FSPI"
		[ "$?" -ne 0 ] && exit 1
	fi

	if [ $EPCR5710A1 == true ]; then
		export BUILD_NN_IMX_CLEANSTATE=true
		$BUILD_SH epcr5710a1-8MP 5710A1"$AIM_VERSION"LIV"$VERSION_NUM" "6G 4G 2G" "FSPI"
		[ "$?" -ne 0 ] && exit 1
	fi

	if [ $RM02A1 == true ]; then
		export BUILD_NN_IMX_CLEANSTATE=true
		$BUILD_SH rm02a1-8MP RM02A1"$AIM_VERSION"LIV"$VERSION_NUM" "4G" "FSPI"
		[ "$?" -ne 0 ] && exit 1
	fi
}


build_project DailyBuild

if [ "${ALSO_BUILD_OFFICIAL_IMAGE}" == true ]; then
	export VERSION=VA.`echo $VERSION_NUM | cut -b 2-`
	build_project OfficialBuild
fi

echo "[ADV] All done!"
