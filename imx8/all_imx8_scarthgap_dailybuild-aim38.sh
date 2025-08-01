#!/bin/bash
# Dailybuild
echo "[ADV] Dailybuild start"
BUILD_SH=${0%/*}/imx8_scarthgap_dailybuild-aim38.sh # keep original path
VERSION_NUM=${RELEASE_VERSION}

[[ ! -f $BUILD_SH ]] && { echo "$BUILD_SH not exist"; exit 1; }
[[ ! $VERSION_NUM =~ ^[0-9A-Z][0-9]{4}$ ]] && { echo "invalid version ($VERSION_NUM)"; exit 1; }

(( $DEBUG )) && {
  echo BUILD_SH=$BUILD_SH
  echo VERSION_NUM=$VERSION_NUM
  exit 0
}

#imx8_BSP
$BUILD_SH imx8 imx8LBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

#imx8_projects
if [ $RSB3720A2 == true ]; then
        $BUILD_SH rsb3720a2-8MP 3720A2"$AIM_VERSION"LIV"$VERSION_NUM" "6G 2G" "FSPI"
        [ "$?" -ne 0 ] && exit 1
fi

if [ $ROM2620A1 == true ]; then
	$BUILD_SH rom2620a1-8U 2620A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G 1G" ""
	[ "$?" -ne 0 ] && exit 1
fi

if [ $ROM5721A1 == true ]; then
        $BUILD_SH rom5721a1-8MM 5721A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G" ""
        [ "$?" -ne 0 ] && exit 1
fi

if [ $ROM5722A2 == true ]; then
        $BUILD_SH rom5722a2-8MP 5722A2"$AIM_VERSION"LIV"$VERSION_NUM" "6G" "FSPI"
        [ "$?" -ne 0 ] && exit 1
fi

if [ $RSB3730A2 == true ]; then
        $BUILD_SH rsb3730a2-8MM 3730A2"$AIM_VERSION"LIV"$VERSION_NUM" "2G 4G" ""
        [ "$?" -ne 0 ] && exit 1
fi
echo "[ADV] All done!"
