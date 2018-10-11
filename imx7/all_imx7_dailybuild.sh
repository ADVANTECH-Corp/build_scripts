#!/bin/bash
MACHINE_LIST=""
#imx7_projects
if [ $EBCRM01A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx7debcrm01a1"
fi
export MACHINE_LIST
./imx7_dailybuild.sh