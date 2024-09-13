#!/bin/bash
	# Dailybuild
	echo "[ADV] Dailybuild start"
	BUILD_SH="./imx6_mickledore_dailybuild-aim36.sh"
	VERSION_NUM=${RELEASE_VERSION}

#imx6_BSP
$BUILD_SH imx6 imx6LBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

#imx6_projects
if [ $RSB4411A1 == true ]; then
	$BUILD_SH rsb4411a1-6q 4411A1"$AIM_VERSION"LIV"$VERSION_NUM" "1G" ""
	[ "$?" -ne 0 ] && exit 1
fi

if [ $RSB4411A2_SOLO == true ]; then
        $BUILD_SH rsb4411a2-6dl 4411A2"$AIM_VERSION"LIV"$VERSION_NUM" "2G" ""
        [ "$?" -ne 0 ] && exit 1
fi

if [ $RSB3430A1 == true ]; then
        $BUILD_SH rsb3430a1-6q 3430A1"$AIM_VERSION"LIV"$VERSION_NUM" "1G" ""
        [ "$?" -ne 0 ] && exit 1
fi
echo "[ADV] All done!"
