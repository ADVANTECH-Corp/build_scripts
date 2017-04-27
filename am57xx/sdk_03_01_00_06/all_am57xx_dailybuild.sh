#!/bin/bash
MACHINE_LIST=""
#am57xx_projects
if [ $AM57XX_EVM == true ]; then
	MACHINE_LIST="$MACHINE_LIST am57xx-evm"
fi

export MACHINE_LIST
./am57xx_dailybuild.sh
