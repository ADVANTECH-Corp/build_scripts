#!/bin/bash
function build_project()
{
	echo "[ADV] $1 start"
	if [ $1 == "OfficialBuild" ]; then
#		NUM1=`expr $VERSION : 'V\([0-9A-Z]*\)'`
#		NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
		# Official release
		BUILD_SH="./rs16_imx8_scarthgap_officialbuild-aim38.sh"
		VERSION_NUM=${RELEASE_VERSION}

	else
		# Dailybuild
		BUILD_SH="./rs16_imx8_scarthgap_dailybuild-aim38.sh"
		VERSION_NUM=${RELEASE_VERSION}
		[[ ! -f $BUILD_SH ]] && { echo "$BUILD_SH not exist"; exit 1; }
		[[ ! $VERSION_NUM =~ ^[0-9A-Z][0-9]{4}$ ]] && { echo "invalid version ($VERSION_NUM)"; exit 1; }
	fi

	#imx8_BSP
	if [ $1 == "DailyBuild" ]; then
		$BUILD_SH imx8 imx8LBV"$VERSION_NUM" 1G
		[ "$?" -ne 0 ] && exit 1
	fi

	if [ $EBCRS16A1 == true ]; then
		$BUILD_SH ebcrs16a1-8MM rs16A1"$AIM_VERSION"LIV"$VERSION_NUM" "2G" ""
		[ "$?" -ne 0 ] && exit 1
	fi
}

build_project DailyBuild

if [ "${ALSO_BUILD_OFFICIAL_IMAGE}" == true ]; then
#	export VERSION=VA.`echo $VERSION_NUM | cut -b 2-`
	build_project OfficialBuild
fi

echo "[ADV] All done!"
