#!/bin/bash

echo "[ADV] Officialbuild start"
NUM1=`expr $VERSION : 'V\([0-9A-Z]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
# Official release
BUILD_SH="./imx8_mickledore_officialbuild-aim36.sh"
VERSION_NUM=$NUM1$NUM2

#imx8_BSP
$BUILD_SH imx8 imx8LBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

#imx8_projects
if [ $RSB3720A2 == true ]; then
        $BUILD_SH rsb3720a2-8MP 3720A2"$AIM_VERSION"LIV"$VERSION_NUM" "6G" "FSPI"
        [ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5722A1 == true ]; then
        $BUILD_SH rom5722a1-8MP 5722A1"$AIM_VERSION"LIV"$VERSION_NUM" "6G" "FSPI"
        [ "$?" -ne 0 ] && exit 1
fi

echo "[ADV] All done!"
