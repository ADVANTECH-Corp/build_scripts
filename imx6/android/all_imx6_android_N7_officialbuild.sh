#!/bin/bash
MACHINE_LIST=""

# Check build machine name
#if [ $RSB4410A1 == true ]; then
#        MACHINE_LIST="$MACHINE_LIST rsb_4410_a1"
#fi
if [ $RSB4411A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rsb_4411_a1"
fi
if [ $UBC220A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST ubc_220_a1"
fi
#if [ $ROM3420A1 == true ]; then
#	MACHINE_LIST="$MACHINE_LIST rom_3420_a1"
#fi
#if [ $ROM7421A1 == true ]; then
#	MACHINE_LIST="$MACHINE_LIST rom_7421_a1"
#fi
export MACHINE_LIST
./imx6_android_N7_officialbuild.sh
