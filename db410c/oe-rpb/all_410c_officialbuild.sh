#!/bin/bash

NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
VERSION_NUM=$NUM1$NUM2

#410c_BSP
./410c_oe_officialbuild.sh 410c 410cLBV"$VERSION_NUM" 2>&1
[ "$?" -ne 0 ] && exit 1

#410c_projects
if [ $RSB_4760 == true ]; then
	./410c_oe_officialbuild.sh rsb-4760 4760LIV"$VERSION_NUM" 2>&1
	[ "$?" -ne 0 ] && exit 1
fi
if [ $EPC_R4761 == true ]; then
	./410c_oe_officialbuild.sh epc-r4761 4761LIV"$VERSION_NUM" 2>&1
	[ "$?" -ne 0 ] && exit 1
fi

