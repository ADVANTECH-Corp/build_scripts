#!/bin/bash
MACHINE_LIST=""
SOC_NAME=""
if  [ $ROM5720A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rom5720_a1"
	SOC_NAME="imx8mq"
fi

if  [ $ROM5721A1 == true ]; then
        MACHINE_LIST="$MACHINE_LIST rom5721_a1"
        SOC_NAME="imx8mm"
fi

if  [ $ROM7720A1 == true ]; then
        MACHINE_LIST="$MACHINE_LIST rom7720_a1"
        SOC_NAME="imx8qm"
fi

export MACHINE_LIST
export SOC_NAME
./imx8_android_P9_officialbuild.sh
