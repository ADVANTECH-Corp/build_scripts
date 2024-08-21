#!/bin/bash
	# Dailybuild
	echo "[ADV] Dailybuild start"
	BUILD_SH="./imx9_nanbield_dailybuild-aim37.sh"
	VERSION_NUM=${RELEASE_VERSION}

#imx9_BSP
$BUILD_SH imx9 imx9LBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

#imx9_projects
if [ $AOM3511A1 == true ]; then
	$BUILD_SH aom3511a1-95 3511A1"$AIM_VERSION"LIV"$VERSION_NUM" "8G 16G" ""
	[ "$?" -ne 0 ] && exit 1
fi
echo "[ADV] All done!"
