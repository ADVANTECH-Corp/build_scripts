#!/bin/bash
MACHINE_LIST=""

# Check build machine name
if [ $RSB_4410_A1 == true ]; then
        MACHINE_LIST="$MACHINE_LIST rsb_4410_a1"
fi
if [ $RSB_4410_A2 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rsb_4410_a2"
fi
if [ $RSB_4411_A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rsb_4411_a1"
fi
if [ $ROM_3420_A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rom_3420_a1"
fi
if [ $ROM_7421_A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rom_7421_a1"
fi
if [ $RSB_6410_A1 == true ]; then
        MACHINE_LIST="$MACHINE_LIST rsb_6410_a1"
fi
if [ $RSB_6410_A2 == true ]; then
        MACHINE_LIST="$MACHINE_LIST rsb_6410_a2"
fi
if [ $ROM_5420_B1 == true ]; then
        MACHINE_LIST="$MACHINE_LIST rom_5420_b1"
fi
if [ $RSB_3430_A1 == true ]; then
        MACHINE_LIST="$MACHINE_LIST rsb_3430_a1"
fi
if [ $EPCRS_200_A1 == true ]; then
        MACHINE_LIST="$MACHINE_LIST epcrs_200_a1"
fi
if [ $UBC_220_A1 == true ]; then
        MACHINE_LIST="$MACHINE_LIST ubc_220_a1"
fi

export MACHINE_LIST
./imx6_android_dailybuild.sh
