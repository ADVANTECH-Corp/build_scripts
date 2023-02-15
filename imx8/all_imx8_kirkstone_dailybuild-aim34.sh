#!/bin/bash
	# Dailybuild
	echo "[ADV] Dailybuild start"
	BUILD_SH="./imx8_kirkstone_dailybuild-aim34.sh"
	VERSION_NUM=${RELEASE_VERSION}

#imx8_BSP
$BUILD_SH imx8 imx8LBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

#imx8_projects
if [ $ROM5721A1 == true ]; then
	$BUILD_SH rom5721a1-8MM 5721A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G 1G" ""
	[ "$?" -ne 0 ] && exit 1
fi
if [ $LPDDR4EVK8U == true ]; then
        $BUILD_SH -lpddr4-evk-8U EVK"$AIM_VERSION"LIV"$VERSION_NUM" "2G" ""
        [ "$?" -ne 0 ] && exit 1
fi

echo "[ADV] All done!"