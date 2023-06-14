#!/bin/bash
if [ "${ALSO_BUILD_OFFICIAL_IMAGE}" != "1" ]; then
	# Dailybuild
	echo "[ADV] Dailybuild start"
	BUILD_SH="./imx8_kirkstone_dailybuild-aim34.sh"
	VERSION_NUM=${RELEASE_VERSION}
else
	echo "[ADV] Officialbuild start"
	NUM1=`expr $VERSION : 'V\([0-9A-Z]*\)'`
	NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
	# Official release
	BUILD_SH="./imx8_kirkstone_officialbuild-aim34.sh"
	VERSION_NUM=$NUM1$NUM2
fi

#imx8_BSP
$BUILD_SH imx8 imx8LBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

#imx8_projects
if [ $ROM5721A1 == true ]; then
	$BUILD_SH rom5721a1-8MM 5721A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G 1G" ""
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5722A1 == true ]; then
        $BUILD_SH rom5722a1-8MP 5722A1"$AIM_VERSION"LIV"$VERSION_NUM" "6G" ""
        [ "$?" -ne 0 ] && exit 1
fi
if [ $RSB3720A1 == true ]; then
        $BUILD_SH rsb3720a1-8MP 3720A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G 6G" ""
        [ "$?" -ne 0 ] && exit 1
fi
if [ $ROM2620A1 == true ]; then
	$BUILD_SH rom2620a1-8U 2620A1"$AIM_VERSION"LIV"$VERSION_NUM" "1G 2G" ""
	[ "$?" -ne 0 ] && exit 1
fi
if [ $LPDDR4EVK8U == true ]; then
        $BUILD_SH -lpddr4-evk-8U EVK"$AIM_VERSION"LIV"$VERSION_NUM" "2G" ""
        [ "$?" -ne 0 ] && exit 1
fi

echo "[ADV] All done!"
