#!/bin/bash
MACHINE_LIST=""

# Check build machine name
#if [ $RSB_4410_A1 == true ]; then
#        MACHINE_LIST="$MACHINE_LIST rsb_4410_a1"
#fi
if [ $RSB_4411_A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rsb_4411_a1"
fi
if [ $UBC_220_A1 == true ]; then

export UBC_220_A1
	MACHINE_LIST="$MACHINE_LIST ubc_220_a1"
fi
#if [ $ROM_3420_A1 == true ]; then
#	MACHINE_LIST="$MACHINE_LIST rom_3420_a1"
#fi
#if [ $ROM_7421_A1 == true ]; then
#	MACHINE_LIST="$MACHINE_LIST rom_7421_a1"
#fi

export MACHINE_LIST
#./imx6_android_N7_dailybuild.sh
