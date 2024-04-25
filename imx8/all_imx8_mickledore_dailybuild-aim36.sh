#!/bin/bash
	# Dailybuild
	echo "[ADV] Dailybuild start"
	BUILD_SH="./imx8_mickledore_dailybuild-aim36.sh"
	VERSION_NUM=${RELEASE_VERSION}

#imx8_BSP
$BUILD_SH imx8 imx8LBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

#imx8_projects
if [ $ROM2620A1 == true ]; then
	$BUILD_SH rom2620a1-8U 2620A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G 1G" ""
	[ "$?" -ne 0 ] && exit 1
fi
if [ $LPDDR4EVK8U == true ]; then
        $BUILD_SH -lpddr4-evk-8U EVK"$AIM_VERSION"LIV"$VERSION_NUM" "2G" ""
        [ "$?" -ne 0 ] && exit 1
fi
if [ $RSB3720A2 == true ]; then
        $BUILD_SH rsb3720a2-8MP 3720A2"$AIM_VERSION"LIV"$VERSION_NUM" "6G" "FSPI"
        [ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5722A1 == true ]; then
        $BUILD_SH rom5722a1-8MP 5722A1"$AIM_VERSION"LIV"$VERSION_NUM" "6G" "FSPI"
        [ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5721A1 == true ]; then
	$BUILD_SH rom5721a1-8MM 5721A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G 1G" ""
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5720A1 == true ]; then
        $BUILD_SH rom5720a1-8M 5720A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G" ""
        [ "$?" -ne 0 ] && exit 1
fi
if [ $RSB3730A2 == true ]; then
        $BUILD_SH rsb3730a2-8MM 3730A2"$AIM_VERSION"LIV"$VERSION_NUM" "2G 4G" ""
        [ "$?" -ne 0 ] && exit 1
fi
echo "[ADV] All done!"
