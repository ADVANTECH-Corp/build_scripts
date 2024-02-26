#!/bin/bash
function build_project()
{
	echo "[ADV] $1 start"
	if [ $1 == "OfficialBuild" ]; then
#		NUM1=`expr $VERSION : 'V\([0-9A-Z]*\)'`
#		NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
		# Official release
		BUILD_SH="./RS08_imx8_kirkstone_officialbuild-aim34.sh"
		VERSION_NUM=${RELEASE_VERSION}

	else
		# Dailybuild
		BUILD_SH="./RS08_imx8_kirkstone_dailybuild-aim34.sh"
		VERSION_NUM=${RELEASE_VERSION}
	fi

	#imx8_BSP
	if [ $1 == "DailyBuild" ]; then
		$BUILD_SH imx8 imx8LBV"$VERSION_NUM" 1G
		[ "$?" -ne 0 ] && exit 1
	fi

	#imx8_projects
	if [ $EBCRS08A2 == true ]; then
		$BUILD_SH ebcrs08a2-8MM RS08A2"$AIM_VERSION"LIV"$VERSION_NUM" "2G" ""
		[ "$?" -ne 0 ] && exit 1
	fi
}

build_project DailyBuild

if [ "${ALSO_BUILD_OFFICIAL_IMAGE}" == true ]; then
#	export VERSION=VA.`echo $VERSION_NUM | cut -b 2-`
	build_project OfficialBuild
fi

echo "[ADV] All done!"
