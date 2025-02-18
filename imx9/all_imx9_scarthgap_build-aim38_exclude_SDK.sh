#!/bin/bash

echo "[ADV] Officialbuild start"
NUM1=`expr $VERSION : 'V\([0-9A-Z]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
# Official release	
BUILD_SH="./imx9_scarthgap_officialbuild-aim38.sh"
VERSION_NUM=$NUM1$NUM2

#imx9_projects
if [ $AOM5521A1 == true ]; then
	$BUILD_SH aom5521a1-95 5521A1"$AIM_VERSION"LIV"$VERSION_NUM" "8G 16G" ""
	[ "$?" -ne 0 ] && exit 1
fi
echo "[ADV] All done!"
