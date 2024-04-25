#!/bin/bash

echo "[ADV] Officialbuild start"
NUM1=`expr $VERSION : 'V\([0-9A-Z]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
# Official release
BUILD_SH="./imx8_mickledore_officialbuild-aim36.sh"
VERSION_NUM=$NUM1$NUM2

#imx8_projects
if [ $ROM2620A1 == true ]; then
	$BUILD_SH rom2620a1-8U 2620A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G 1G" ""
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
