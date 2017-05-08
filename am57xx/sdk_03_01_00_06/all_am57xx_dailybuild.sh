#!/bin/bash
MACHINE_LIST=""
#am57xx_projects
if [ $AM57XX_EVM == true ]; then
	MACHINE_LIST="$MACHINE_LIST am57xx-evm"
fi
if [ $ROM7510A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST am57xxrom7510a1"
fi

export MACHINE_LIST
./am57xx_dailybuild.sh
