#!/bin/bash
	# Dailybuild
	echo "[ADV] Dailybuild start"
	BUILD_SH="./imx9_mickledore_dailybuild-aim36.sh"
	VERSION_NUM=${RELEASE_VERSION}

#imx9_BSP
$BUILD_SH imx9 imx9LBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

#imx9_projects
if [ $ROM2820A1 == true ]; then
	$BUILD_SH rom2820a1-93 2820A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G 1G" ""
	[ "$?" -ne 0 ] && exit 1
fi
if [ $AFEE320A1 == true ]; then
	$BUILD_SH afee320a1-93 E320A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G" ""
	[ "$?" -ne 0 ] && exit 1
fi
echo "[ADV] All done!"
