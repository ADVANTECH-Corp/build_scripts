#!/bin/bash
MACHINE_LIST=""
SOC_NAME=""
# Check build machine name
#if [ $RSB4410A1 == true ]; then
#        MACHINE_LIST="$MACHINE_LIST rsb_4410_a1"
#fi
if [ $RSB4411A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rsb_4411_a1"
	SOC_NAME="imx6q"
fi
if  [ $ROM5720A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rom5720_a1"
	SOC_NAME="imx8mq"
fi
if  [ $ROM7720A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rom7720_a1"
	SOC_NAME="imx8qm"
fi
if  [ $ROM5721A1 == true ]; then
        MACHINE_LIST="$MACHINE_LIST rom5721_a1"
        SOC_NAME="imx8mm"
fi

export MACHINE_LIST
export SOC_NAME
./imx6_android_P9_officialbuild.sh
