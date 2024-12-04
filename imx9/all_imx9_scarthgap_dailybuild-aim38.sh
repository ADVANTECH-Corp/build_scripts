#!/bin/bash
# Dailybuild
echo "[ADV] Dailybuild start"
BUILD_SH=${0%/*}/imx9_scarthgap_dailybuild-aim38.sh # keep original path
VERSION_NUM=${RELEASE_VERSION}

[[ ! -f $BUILD_SH ]] && { echo "$BUILD_SH not exist"; exit 1; }
[[ ! $VERSION_NUM =~ ^[0-9A-Z][0-9]{4}$ ]] && { echo "invalid version ($VERSION_NUM)"; exit 1; }

(( $DEBUG )) && {
  echo BUILD_SH=$BUILD_SH
  echo VERSION_NUM=$VERSION_NUM
  exit 0
}

#imx9_BSP
$BUILD_SH imx9 imx9LBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

if [ $IMX93EVK == true ]; then
    $BUILD_SH evk-93 EVK"$AIM_VERSION"LIV"$VERSION_NUM" "2G" ""
    [ "$?" -ne 0 ] && exit 1
fi
if [ $AOM3511A1 == true ]; then
    $BUILD_SH aom3511a1-95 3511A1"$AIM_VERSION"LIV"$VERSION_NUM" "8G 16G" ""
    [ "$?" -ne 0 ] && exit 1
fi
echo "[ADV] All done!"
