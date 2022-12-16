#!/bin/bash

if [[ ! ${ALSO_BUILD_OFFICIAL_IMAGE} =~ 1|true ]]; then
    # Dailybuild
    BUILD_SH=./imx8_desktop_hardknott_dailybuild-aim33.sh
    VERSION_NUM=${RELEASE_VERSION}
else
    # Official release
    [[ ! $VERSION =~ ^V[0-9A-Z][0-9]{4}$ ]] && { echo "invalid VERSION ($VERSION)"; exit 1; }
    BUILD_SH=./imx8_desktop_hardknott_officialbuild-aim33.sh
    VERSION_NUM=${VERSION#V}
fi
echo BUILD_SH=$BUILD_SH
echo VERSION_NUM=$VERSION_NUM

#imx8_BSP
$BUILD_SH imx8 imx8UBV"$VERSION_NUM" 1G
[ "$?" -ne 0 ] && exit 1

#imx8_projects
if [ $RSB3720A1 == true ]; then
    $BUILD_SH rsb3720a1-8MP 3720A1"$AIM_VERSION"UIV"$VERSION_NUM" "6G" "FSPI"
    [ "$?" -ne 0 ] && exit 1
fi

echo "[ADV] All done!"
