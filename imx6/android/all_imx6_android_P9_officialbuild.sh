#!/bin/bash
MACHINE_LIST=""

# Check build machine name
#if [ $RSB4410A1 == true ]; then
#        MACHINE_LIST="$MACHINE_LIST rsb_4410_a1"
#fi
if [ $RSB4411A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rsb_4411_a1"
fi

export MACHINE_LIST
./imx6_android_P9_officialbuild.sh
