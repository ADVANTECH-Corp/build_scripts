#!/bin/bash
NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
VERSION_NUM=$NUM1$NUM2
PRODUCT=""

#[x11]
#imx7_BSP
./imx7_officialbuild.sh imx7 imx7LBV"$VERSION_NUM" 2G_IM x11
[ "$?" -ne 0 ] && exit 1

#imx7_projects
if [ $EBCRM01A1 == true ]; then
	PRODUCT="ebcrm01a1"
	./imx7_officialbuild.sh ebcrm01a1 RM01A1LIV"$VERSION_NUM" 2G_IM x11
	[ "$?" -ne 0 ] && exit 1
fi

# Push commit
if [ -n $PRODUCT ]; then
	./imx7_officialbuild.sh push_commit $PRODUCT
	[ "$?" -ne 0 ] && exit 1
fi

echo "[ADV] All done!"
