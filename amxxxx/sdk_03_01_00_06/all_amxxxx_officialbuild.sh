#!/bin/bash
NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
VERSION_NUM=$NUM1$NUM2
PRODUCT=""

#amxxxx_BSP
./amxxxx_officialbuild.sh am57xx am57xxLBV"$VERSION_NUM" 2>&1 |tee am57xxLBV"$VERSION_NUM"_$DATE.log
[ "$?" -ne 0 ] && exit 1

#amxxxx_projects
if [ $ROM7510A2 == true ]; then
	PRODUCT="rom7510a2"
	./amxxxx_officialbuild.sh rom7510a2 ROM7510A2LIV"$VERSION_NUM" 2>&1 |tee ROM7510A2LIV"$VERSION_NUM"_$DATE.log
	[ "$?" -ne 0 ] && exit 1
fi
# Push commit
if [ -n $PRODUCT ]; then
	./amxxxx_officialbuild.sh push_commit $PRODUCT
	[ "$?" -ne 0 ] && exit 1
fi

mv *.log $STORED/$DATE/

echo "[ADV] All done!"
