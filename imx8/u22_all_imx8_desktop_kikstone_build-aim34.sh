#!/bin/bash

function build_project()
{
	echo "[ADV] $1 start"
	if [ $1 == "OfficialBuild" ]; then
		# Official release
		[[ ! $VERSION =~ ^V[0-9A-Z][0-9]{4}$ ]] && { echo "invalid VERSION ($VERSION)"; exit 1; }
		BUILD_SH="./u22_imx8_desktop_kikstone_officialbuild-aim34.sh"
		VERSION_NUM=${VERSION#V}
	else
		# Dailybuild
		BUILD_SH="./u22_imx8_desktop_kikstone_dailybuild-aim34.sh"
		VERSION_NUM=${RELEASE_VERSION}
	fi

	echo BUILD_SH=$BUILD_SH
	echo VERSION_NUM=$VERSION_NUM

	#imx8_BSP
	$BUILD_SH imx8 imx8UBV"$VERSION_NUM" 1G
	[ "$?" -ne 0 ] && exit 1

	#imx8_projects
	if [[ $EPCR5710A1 == true ]]; then
		$BUILD_SH epcr5710a1-8MP 5710A1"$AIM_VERSION"UIV"$VERSION_NUM" "4G" "FSPI"
		[ "$?" -ne 0 ] && exit 1
	fi
}

build_project DailyBuild

if [[ "${ALSO_BUILD_OFFICIAL_IMAGE}" =~  1|true ]]; then
	build_project OfficialBuild
fi

echo "[ADV] All done!"