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
if [ $ROM2820A1 == true ]; then
	$BUILD_SH rom2820a1-93 2820A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G 1G" ""
	[ "$?" -ne 0 ] && exit 1
fi
if [ $LPDDR4EVK8U == true ]; then
        $BUILD_SH -lpddr4-evk-8U EVK"$AIM_VERSION"LIV"$VERSION_NUM" "2G" ""
        [ "$?" -ne 0 ] && exit 1
fi
echo "[ADV] All done!"
