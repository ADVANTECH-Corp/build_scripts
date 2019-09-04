#!/bin/bash
PRODUCT=""
if [ "x${ALSO_BUILD_OFFICIAL_IMAGE}" != "x" ]; then
	# Dailybuild
	BUILD_SH="./imx6_sumo_dailybuild-aim20.sh"
	VERSION_NUM=${RELEASE_VERSION}
else
	NUM1=`expr $VERSION : 'V\([0-9]*\)'`
	NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
	# Official release
	BUILD_SH="./imx6_sumo_officialbuild-aim20.sh"
	VERSION_NUM=$NUM1$NUM2
fi

#imx6_BSP
$BUILD_SH imx6 imx6LBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

#imx6_projects
if [ $UBC220A1_SOLO == true ]; then
	PRODUCT="ubc220a1-solo"
	$BUILD_SH ubc220a1-solo U220A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $UBC220A1 == true ]; then
	PRODUCT="ubc220a1"
	$BUILD_SH ubc220a1 U220A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $UBCDS31A1 == true ]; then
	PRODUCT="ubcds31a1"
	$BUILD_SH ubcds31a1 DS31A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5420A1 == true ]; then
	PRODUCT="rom5420a1"
	$BUILD_SH rom5420a1 5420A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G-2G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5420B1_SOLO == true ]; then
	PRODUCT="rom5420b1-solo"
	$BUILD_SH rom5420b1-solo 5420B1"$AIM_VERSION"LIV"$VERSION_NUM" 512M-1G-2G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM5420B1 == true ]; then
	PRODUCT="rom5420b1"
	$BUILD_SH rom5420b1 5420B1"$AIM_VERSION"LIV"$VERSION_NUM" 1G-2G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $RSB4410A1 == true ]; then
	PRODUCT="rsb4410a1"
	$BUILD_SH rsb4410a1 4410A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $RSB4410A2 == true ]; then
	PRODUCT="rsb4410a2"
	$BUILD_SH rsb4410a2 4410A2"$AIM_VERSION"LIV"$VERSION_NUM" 1G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $RSB4411A1 == true ]; then
	PRODUCT="rsb4411a1"
	$BUILD_SH rsb4411a1 4411A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G-2G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $RSB4411A1_SOLO == true ]; then
        PRODUCT="rsb4411a1-solo"
        $BUILD_SH rsb4411a1-solo 4411A1"$AIM_VERSION"LIV"$VERSION_NUM" 2G
        [ "$?" -ne 0 ] && exit 1
fi
if [ $EBCJF02A1 == true ]; then
	PRODUCT="ebcjf02a1"
	$BUILD_SH ebcjf02a1 JF02A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $EPCRS200A1 == true ]; then
	PRODUCT="epcrs200a1"
	$BUILD_SH epcrs200a1 RS200A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM7420A1 == true ]; then
	PRODUCT="rom7420a1"
	$BUILD_SH rom7420a1 7420A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G-2G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM3420A1 == true ]; then
	PRODUCT="rom3420a1"
	$BUILD_SH rom3420a1 3420A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G-2G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM7421A1_PLUS == true ]; then
	PRODUCT="rom7421a1-plus"
	$BUILD_SH rom7421a1-plus 7421A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G-2G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM7421A1 == true ]; then
	PRODUCT="rom7421a1"
	$BUILD_SH rom7421a1 7421A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G-2G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $ROM7421A1_SOLO == true ]; then
	PRODUCT="rom7421a1-solo"
	$BUILD_SH rom7421a1-solo 7421A1"$AIM_VERSION"LIV"$VERSION_NUM" 512M-1G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $EBCRB01A1 == true ]; then
	PRODUCT="ebcrb01a1"
	$BUILD_SH ebcrb01a1 RB01A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $EBCRS03A1 == true ]; then
	PRODUCT="ebcrs03a1"
	$BUILD_SH ebcrs03a1 RS03A1"$AIM_VERSION"LIV"$VERSION_NUM" 2G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $EBCRS03A1_SOLO == true ]; then
	PRODUCT="ebcrs03a1-solo"
	$BUILD_SH ebcrs03a1-solo RS03A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $RSB6410A2 == true ]; then
	PRODUCT="rsb6410a2"
	$BUILD_SH rsb6410a2 6410A2"$AIM_VERSION"LIV"$VERSION_NUM" 1G-2G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $RSB3430A1 == true ]; then
	PRODUCT="rsb3430a1"
	$BUILD_SH rsb3430a1 3430A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G
	[ "$?" -ne 0 ] && exit 1
fi
if [ $RSB3430A1_SOLO == true ]; then
	PRODUCT="rsb3430a1-solo"
	$BUILD_SH rsb3430a1-solo 3430A1"$AIM_VERSION"LIV"$VERSION_NUM" 1G
	[ "$?" -ne 0 ] && exit 1
fi

echo "[ADV] All done!"
