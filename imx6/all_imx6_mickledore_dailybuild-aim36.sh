#!/bin/bash
	# Dailybuild
	echo "[ADV] Dailybuild start"
	BUILD_SH="./imx6_mickledore_dailybuild-aim36.sh"
	VERSION_NUM=${RELEASE_VERSION}

#imx8_BSP
$BUILD_SH imx8 imx8LBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

#imx8_projects
if [ $RSB4411A1 == true ]; then
	$BUILD_SH rsb4411a1-6q 4411A1"$AIM_VERSION"LIV"$VERSION_NUM" "1G" ""
	[ "$?" -ne 0 ] && exit 1
fi
echo "[ADV] All done!"
